import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { chooseLanguage } from '../test/helpers';
import { LanguageProvider } from '../i18n/LanguageContext';
import { readPreferences } from '../local/examExtras';
import { emptyCodeQuestion, validateCodeQuestion, type CodeQuestion } from '../types/code';
import { CodeAnswerPanel } from './CodeAnswerPanel';
import { CodeQuestionForm } from './CodeQuestionForm';

// CodeMirror measures text with browser APIs jsdom does not implement.
if (!Range.prototype.getClientRects) {
  Range.prototype.getClientRects = () => ({ length: 0, item: () => null, [Symbol.iterator]: function* () {} }) as unknown as DOMRectList;
  Range.prototype.getBoundingClientRect = () => new DOMRect();
}

const question = (patch: Partial<CodeQuestion> = {}): CodeQuestion => ({
  ...emptyCodeQuestion('cq1'),
  text: 'Reverse a string.',
  marks: 5,
  languages: ['java', 'python'],
  defaultLanguage: 'python',
  editorModes: ['normal', 'vim'],
  defaultMode: 'normal',
  tabSizes: [2, 4],
  defaultTabSize: 4,
  autocomplete: false,
  ...patch,
});

function Panel({ q }: { q: CodeQuestion }) {
  const [value, setValue] = useState('print(1)');
  return (
    <LanguageProvider>
      <CodeAnswerPanel examId="e1" question={q} value={value} onChange={setValue} idPrefix="t" />
    </LanguageProvider>
  );
}

beforeEach(() => chooseLanguage('en'));

describe('validateCodeQuestion', () => {
  it('accepts a complete question and flags each gap', () => {
    expect(validateCodeQuestion(question())).toEqual([]);
    expect(validateCodeQuestion(question({ text: ' ' }))).toContain('text');
    expect(validateCodeQuestion(question({ marks: 0 }))).toContain('marks');
    expect(validateCodeQuestion(question({ languages: [] }))).toContain('languages');
    expect(validateCodeQuestion(question({ editorModes: [] }))).toContain('modes');
    expect(validateCodeQuestion(question({ tabSizes: [] }))).toContain('tabSizes');
    expect(validateCodeQuestion(question({ defaultLanguage: 'c' }))).toContain('defaults');
  });
});

describe('CodeAnswerPanel (what the student sees)', () => {
  it('offers only the languages, modes and tab sizes the teacher allowed', async () => {
    render(<Panel q={question()} />);
    const language = await screen.findByLabelText('Language');
    expect(within(language).getAllByRole('option').map((option) => option.textContent)).toEqual(['Java', 'Python']);
    expect(language).toHaveValue('python');

    const mode = screen.getByLabelText('Editor mode', { selector: 'select' });
    expect(within(mode).getAllByRole('option').map((option) => option.textContent)).toEqual(['Normal', 'Vim']);
    const tabs = screen.getByLabelText('Tab spaces');
    expect(within(tabs).getAllByRole('option').map((option) => option.textContent)).toEqual(['2 spaces', '4 spaces']);
    expect(tabs).toHaveValue('4');
  });

  it('shows clearly whether autocomplete is on or off', async () => {
    const { unmount } = render(<Panel q={question({ autocomplete: false })} />);
    expect(await screen.findByTestId('autocomplete-state')).toHaveTextContent('Autocomplete: off');
    unmount();
    render(<Panel q={question({ autocomplete: true })} />);
    expect(await screen.findByTestId('autocomplete-state')).toHaveTextContent('Autocomplete: on');
  });

  it('renders a real editor holding the answer', async () => {
    render(<Panel q={question()} />);
    expect(await screen.findByRole('textbox', { name: 'Code editor' })).toHaveTextContent('print(1)');
  });

  it('keeps the student’s choices for the session', async () => {
    const user = userEvent.setup();
    render(<Panel q={question()} />);
    await user.selectOptions(await screen.findByLabelText('Language'), 'java');
    await user.selectOptions(screen.getByLabelText('Editor mode', { selector: 'select' }), 'vim');
    await user.selectOptions(screen.getByLabelText('Tab spaces'), '2');
    await waitFor(() => expect(readPreferences('e1', 'cq1')).toEqual({ language: 'java', mode: 'vim', tabSize: 2 }));
  });

  it('restores saved choices only when the teacher still allows them', async () => {
    window.sessionStorage.setItem('editorPrefs.e1.cq1', JSON.stringify({ language: 'c', mode: 'vim', tabSize: 8 }));
    render(<Panel q={question()} />);
    expect(await screen.findByLabelText('Language')).toHaveValue('python'); // C is not allowed
    expect(screen.getByLabelText('Editor mode', { selector: 'select' })).toHaveValue('vim'); // allowed
    expect(screen.getByLabelText('Tab spaces')).toHaveValue('4'); // 8 is not allowed
  });
});

describe('CodeQuestionForm (what the teacher configures)', () => {
  function setup(onSubmit = vi.fn()) {
    render(
      <LanguageProvider>
        <CodeQuestionForm question={emptyCodeQuestion('cq9')} onSubmit={onSubmit} onCancel={() => {}} />
      </LanguageProvider>,
    );
    return onSubmit;
  }

  it('says it is saved in this browser only and that nothing is run', () => {
    setup();
    expect(screen.getByText(/kept in this browser only/i)).toBeInTheDocument();
  });

  it('refuses an empty question and a language list with nothing in it', async () => {
    const user = userEvent.setup();
    const onSubmit = setup();
    for (const name of ['Java', 'C++', 'Python']) await user.click(screen.getByRole('checkbox', { name }));
    await user.click(screen.getByRole('button', { name: 'Save code question' }));
    expect(screen.getByText('Enter the question text.')).toBeInTheDocument();
    expect(screen.getByText('Choose at least one programming language.')).toBeInTheDocument();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('saves the chosen languages, modes, tab sizes, autocomplete and evaluation method', async () => {
    const user = userEvent.setup();
    const onSubmit = setup();
    await user.type(screen.getByLabelText('Question text'), 'Sort a list.');
    await user.clear(screen.getByLabelText('Marks'));
    await user.type(screen.getByLabelText('Marks'), '7.5');
    await user.click(screen.getByRole('checkbox', { name: 'Python' })); // untick the default language
    await user.click(screen.getByRole('checkbox', { name: 'Emacs' }));
    await user.click(screen.getByRole('checkbox', { name: '8 spaces' }));
    await user.click(screen.getByRole('checkbox', { name: 'Allow autocomplete for this question' }));
    await user.selectOptions(screen.getByLabelText('Evaluation'), 'ai');
    expect(screen.getByText(/not connected to the server yet/i)).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Save code question' }));

    expect(onSubmit).toHaveBeenCalledOnce();
    const saved = onSubmit.mock.calls[0][0] as CodeQuestion;
    expect(saved).toMatchObject({
      text: 'Sort a list.',
      marks: 7.5,
      languages: ['java', 'cpp'],
      defaultLanguage: 'java', // the default moved off the language that was unticked
      editorModes: ['normal', 'vim'],
      tabSizes: [2, 4],
      autocomplete: false,
      evaluation: 'ai',
    });
  });
});
