import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useState } from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { chooseLanguage } from '../test/helpers';
import { LanguageProvider } from '../i18n/LanguageContext';
import { readPreferences } from '../local/examExtras';
import { emptyCodeQuestion, INDENT_SIZES, normalizeCodeQuestion, validateCodeQuestion, type CodeQuestion } from '../types/code';
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
  languages: ['java', 'python', 'javascript', 'c'],
  defaultLanguage: 'python',
  autoCompletionEnabled: false,
  ...patch,
});

function Panel({ q, initial = 'print(1)' }: { q: CodeQuestion; initial?: string }) {
  const [value, setValue] = useState(initial);
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
    expect(validateCodeQuestion(question({ defaultLanguage: 'cpp' }))).toContain('defaults');
  });
});

describe('questions saved by an earlier version', () => {
  it('are read into the current shape: the old autocomplete flag is kept, starter code, tab sizes and evaluation are dropped', () => {
    const legacy = {
      id: 'old',
      text: 'Old question',
      marks: 2,
      starterCode: 'print(1)',
      languages: ['python'],
      defaultLanguage: 'python',
      editorModes: ['normal', 'vim'],
      defaultMode: 'vim',
      tabSizes: [2, 4],
      defaultTabSize: 4,
      autocomplete: false,
      evaluation: 'ai',
    } as unknown as Parameters<typeof normalizeCodeQuestion>[0];
    const migrated = normalizeCodeQuestion(legacy);
    expect(migrated.autoCompletionEnabled).toBe(false);
    expect(Object.keys(migrated).sort()).toEqual(
      ['autoCompletionEnabled', 'defaultLanguage', 'id', 'languages', 'marks', 'text'].sort(),
    );
  });
});

describe('indentation follows the language', () => {
  it('has a default for every supported language', () => {
    expect(INDENT_SIZES).toEqual({ c: 4, cpp: 4, java: 4, python: 4, javascript: 2 });
  });
});

describe('CodeAnswerPanel (what the student sees)', () => {
  it('offers only the languages the teacher allowed, and no editor mode, editor settings or tab size', async () => {
    render(<Panel q={question()} />);
    const language = await screen.findByLabelText('Language');
    expect(within(language).getAllByRole('option').map((option) => option.textContent)).toEqual(['Java', 'C', 'Python', 'JavaScript']);
    expect(language).toHaveValue('python');

    expect(screen.getAllByRole('combobox')).toHaveLength(1); // the language list is the only selector
    expect(screen.queryByText(/editor mode|vim|emacs|tab spaces|tab size|editor settings/i)).not.toBeInTheDocument();
  });

  it('shows clearly whether auto-completion is on or off', async () => {
    const { unmount } = render(<Panel q={question({ autoCompletionEnabled: false })} />);
    expect(await screen.findByTestId('autocomplete-state')).toHaveTextContent('Auto-completion: off');
    unmount();
    render(<Panel q={question({ autoCompletionEnabled: true })} />);
    expect(await screen.findByTestId('autocomplete-state')).toHaveTextContent('Auto-completion: on');
  });

  it('renders a real editor holding the answer', async () => {
    render(<Panel q={question()} />);
    expect(await screen.findByRole('textbox', { name: 'Code editor' })).toHaveTextContent('print(1)');
  });

  it('keeps the student’s choices for the session', async () => {
    const user = userEvent.setup();
    render(<Panel q={question()} />);
    await user.selectOptions(await screen.findByLabelText('Language'), 'java');
    await waitFor(() => expect(readPreferences('e1', 'cq1')).toEqual({ language: 'java' }));
  });

  it('restores a saved language only when the teacher still allows it, and ignores a saved editor mode', async () => {
    window.sessionStorage.setItem('editorPrefs.e1.cq1', JSON.stringify({ language: 'cpp', mode: 'vim' }));
    render(<Panel q={question()} />);
    expect(await screen.findByLabelText('Language')).toHaveValue('python'); // C++ is not allowed
  });

  it('empties the editor on every language change and never brings the old code back (Python, Java, JavaScript, C, Python)', async () => {
    const user = userEvent.setup();
    render(<Panel q={question()} initial="print('hello')" />);
    expect(await screen.findByRole('textbox', { name: 'Code editor' })).toHaveTextContent("print('hello')");

    for (const next of ['java', 'javascript', 'c', 'python']) {
      const before = screen.getByTestId('code-editor');
      await user.selectOptions(screen.getByLabelText('Language'), next);
      await waitFor(() => expect(screen.getByLabelText('Language')).toHaveValue(next));
      const editor = await screen.findByRole('textbox', { name: 'Code editor' });
      expect(editor).toHaveTextContent('');
      expect(screen.queryByText(/hello/)).not.toBeInTheDocument();
      expect(screen.getByTestId('code-editor')).not.toBe(before); // a fresh editor, so no undo history either
    }
  });

  it('keeps what the student typed when the same language is chosen again', async () => {
    const user = userEvent.setup();
    render(<Panel q={question()} />);
    await screen.findByRole('textbox', { name: 'Code editor' });
    await user.selectOptions(screen.getByLabelText('Language'), 'python'); // already selected: not a change
    expect(screen.getByRole('textbox', { name: 'Code editor' })).toHaveTextContent('print(1)');
  });
});

describe('CodeQuestionForm (what the teacher configures)', () => {
  function setup(onSubmit = vi.fn(), initial: CodeQuestion = emptyCodeQuestion('cq9')) {
    render(
      <LanguageProvider>
        <CodeQuestionForm question={initial} onSubmit={onSubmit} onCancel={() => {}} />
      </LanguageProvider>,
    );
    return onSubmit;
  }

  it('says it is saved in this browser only and that nothing is run', () => {
    setup();
    expect(screen.getByText(/kept in this browser only/i)).toBeInTheDocument();
  });

  it('has no evaluation, starter code input, editor mode, editor settings or tab size controls', () => {
    setup();
    expect(screen.queryByLabelText('Evaluation')).not.toBeInTheDocument();
    expect(screen.queryByLabelText(/starter code/i)).not.toBeInTheDocument(); // no input; only the neutral note
    expect(screen.queryByText(/evaluation|editor mode|vim|emacs|editor settings|tab size|allow autocomplete for this question/i)).not.toBeInTheDocument();
    expect(screen.getByText(/generated automatically/i)).toBeInTheDocument();
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

  it('saves the chosen languages and auto-completion, and needs no starter code', async () => {
    const user = userEvent.setup();
    const onSubmit = setup();
    await user.type(screen.getByLabelText('Question text'), 'Sort a list.');
    await user.clear(screen.getByLabelText('Marks'));
    await user.type(screen.getByLabelText('Marks'), '7.5');
    await user.click(screen.getByRole('checkbox', { name: 'Python' })); // untick the default language
    const toggle = screen.getByRole('switch', { name: 'Auto-Completion' });
    expect(toggle).toHaveAttribute('aria-checked', 'true');
    expect(toggle).toHaveTextContent('On');
    await user.click(toggle);
    expect(toggle).toHaveAttribute('aria-checked', 'false');
    expect(toggle).toHaveTextContent('Off');
    await user.click(screen.getByRole('button', { name: 'Save code question' }));

    expect(onSubmit).toHaveBeenCalledOnce();
    const saved = onSubmit.mock.calls[0][0] as CodeQuestion;
    expect(saved).toMatchObject({
      text: 'Sort a list.',
      marks: 7.5,
      languages: ['java', 'cpp'],
      defaultLanguage: 'java', // the default moved off the language that was unticked
      autoCompletionEnabled: false,
    });
    expect(saved).not.toHaveProperty('editorModes');
    expect(saved).not.toHaveProperty('defaultMode');
    expect(saved).not.toHaveProperty('starterCode');
    expect(saved).not.toHaveProperty('evaluation');
    expect(saved).not.toHaveProperty('tabSizes');
  });

  it('shows the saved auto-completion choice when an existing question is edited, and the toggle works from the keyboard', async () => {
    const user = userEvent.setup();
    setup(vi.fn(), question({ autoCompletionEnabled: false }));
    const toggle = screen.getByRole('switch', { name: 'Auto-Completion' });
    expect(toggle).toHaveAttribute('aria-checked', 'false');
    toggle.focus();
    await user.keyboard('{Enter}');
    expect(toggle).toHaveAttribute('aria-checked', 'true');
    await user.keyboard(' ');
    expect(toggle).toHaveAttribute('aria-checked', 'false');
  });
});
