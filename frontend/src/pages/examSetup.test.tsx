import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { getExtras, saveExtras } from '../local/examExtras';
import { callsTo, chooseLanguage, mockApi, renderApp } from '../test/helpers';
import { exam, jsonResponse, tokenResponse } from '../test/fixtures';
import { emptyCodeQuestion } from '../types/code';
import type { Question } from '../types/api';

// These render the real routes. Questions on the backend are MCQ and Essay; code questions and the exam extras
// (subject, total marks, method) live in this browser (local/examExtras.ts).

const EXAM = '/api/exams/e1';
const QUESTIONS = '/api/exams/e1/questions';

const mcq = (id: string, position: number, marks: number): Question => ({
  id,
  examId: 'e1',
  type: 'Mcq',
  text: `Question ${position}`,
  marks,
  modelAnswer: null,
  position,
  options: [
    { id: `${id}a`, text: 'Right', isCorrect: true, position: 1 },
    { id: `${id}b`, text: 'Wrong', isCorrect: false, position: 2 },
  ],
});
const essay = (id: string, position: number, marks: number): Question => ({
  id,
  examId: 'e1',
  type: 'Essay',
  text: `Explain ${position}`,
  marks,
  modelAnswer: 'Secret model answer',
  position,
  options: [],
});

beforeEach(() => {
  chooseLanguage('en');
  tokenStore.setFromTokenResponse(tokenResponse());
});

describe('choosing how to add questions', () => {
  it('asks once on an exam with no questions, and remembers the choice', async () => {
    const user = userEvent.setup();
    mockApi({ [`GET ${EXAM}`]: [() => jsonResponse(200, exam())], [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [] })] });
    renderApp('/exams/e1');

    expect(await screen.findByText('How do you want to add questions?')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Create manually' }));

    expect(getExtras('e1').method).toBe('manual');
    expect(screen.queryByText('How do you want to add questions?')).not.toBeInTheDocument();
    // The new-question form opens straight away, with the type picker.
    expect(screen.getByRole('group', { name: 'Type' })).toBeInTheDocument();
  });

  it('does not ask again once questions exist, and both ways stay reachable', async () => {
    mockApi({ [`GET ${EXAM}`]: [() => jsonResponse(200, exam())], [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [mcq('q1', 1, 5)] })] });
    renderApp('/exams/e1');
    expect(await screen.findByText('Question 1')).toBeInTheDocument();
    expect(screen.queryByText('How do you want to add questions?')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Add question' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Import from Word instead' })).toBeInTheDocument();
  });

  it('Word import is chosen once and the page then offers that workflow', async () => {
    const user = userEvent.setup();
    saveExtras('e1', { method: 'word' });
    mockApi({ [`GET ${EXAM}`]: [() => jsonResponse(200, exam())], [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [mcq('q1', 1, 5)] })] });
    renderApp('/exams/e1');
    await screen.findByText('Adding questions by Word import.');
    const links = screen.getAllByRole('link', { name: 'Import from Word' }).map((link) => link.getAttribute('href'));
    expect(links).toContain('/import?examId=e1');
    expect(screen.queryByRole('button', { name: 'Add question' })).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Create manually instead' }));
    expect(screen.getByRole('button', { name: 'Add question' })).toBeInTheDocument();
  });
});

describe('question types', () => {
  async function openNewQuestion() {
    const user = userEvent.setup();
    saveExtras('e1', { method: 'manual' });
    mockApi({ [`GET ${EXAM}`]: [() => jsonResponse(200, exam())], [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [] })] });
    renderApp('/exams/e1');
    await user.click(await screen.findByRole('button', { name: 'Add question' }));
    return user;
  }

  it('offers MCQ, Essay and Code, each with its own form', async () => {
    const user = await openNewQuestion();
    const picker = screen.getByRole('group', { name: 'Type' });
    expect(within(picker).getAllByRole('button').map((button) => button.textContent)).toEqual(['MCQ', 'Essay', 'Code']);

    // MCQ: options, no type dropdown repeated.
    expect(screen.getByText('Options (tick every correct answer)')).toBeInTheDocument();
    expect(screen.queryByRole('combobox', { name: 'Type' })).not.toBeInTheDocument();

    await user.click(within(picker).getByRole('button', { name: 'Essay' }));
    expect(screen.queryByText('Options (tick every correct answer)')).not.toBeInTheDocument();

    await user.click(within(picker).getByRole('button', { name: 'Code' }));
    expect(screen.getByRole('form', { name: 'Code question' })).toBeInTheDocument();
    expect(screen.getByRole('switch', { name: 'Auto-Completion' })).toBeInTheDocument();
  });

  it('saves a code question in this browser and makes NO request to the server for it', async () => {
    const user = await openNewQuestion();
    const fetchMock = (await import('vitest')).vi.mocked(fetch);
    await user.click(within(screen.getByRole('group', { name: 'Type' })).getByRole('button', { name: 'Code' }));
    await user.type(screen.getByLabelText('Question text'), 'Write FizzBuzz.');
    await user.click(screen.getByRole('button', { name: 'Save code question' }));

    expect(await screen.findByText('Write FizzBuzz.')).toBeInTheDocument();
    expect(getExtras('e1').codeQuestions).toHaveLength(1);
    expect(fetchMock.mock.calls.filter(([, init]) => (init as RequestInit | undefined)?.method === 'POST')).toHaveLength(0);
  });
});

describe('marks', () => {
  async function start(items: Question[]) {
    const fetchMock = mockApi({
      [`GET ${EXAM}`]: [() => jsonResponse(200, exam())],
      [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items })],
      'PUT /api/questions/q1': [() => jsonResponse(200, items[0])],
      'PUT /api/questions/q2': [() => jsonResponse(200, items[1])],
      'PUT /api/questions/q3': [() => jsonResponse(200, items[2] ?? items[0])],
    });
    renderApp('/exams/e1');
    await screen.findByText('Question 1');
    return { fetchMock, user: userEvent.setup() };
  }

  it('splits the total equally, adds up exactly, and saves each question through the API', async () => {
    const { fetchMock, user } = await start([mcq('q1', 1, 1), essay('q2', 2, 1), mcq('q3', 3, 1)]);
    await user.clear(screen.getByLabelText('Total marks'));
    await user.type(screen.getByLabelText('Total marks'), '10');
    await user.click(screen.getByRole('button', { name: 'Distribute equally' }));

    expect(screen.getByLabelText('Q1')).toHaveValue('3.34');
    expect(screen.getByLabelText('Q2')).toHaveValue('3.33');
    expect(screen.getByLabelText('Q3')).toHaveValue('3.33');
    expect(screen.getByTestId('marks-sum')).toHaveTextContent('Questions add up to 10.00 of 10.00.');

    await user.click(screen.getByRole('button', { name: 'Save marks' }));
    await waitFor(() => expect(callsTo(fetchMock, 'PUT /api/questions/q1')).toHaveLength(1));
    expect(callsTo(fetchMock, 'PUT /api/questions/q2')).toHaveLength(1);
    const body = JSON.parse((callsTo(fetchMock, 'PUT /api/questions/q2')[0][1] as RequestInit).body as string) as Record<string, unknown>;
    expect(body).toMatchObject({ type: 'Essay', marks: 3.33, modelAnswer: 'Secret model answer' });
    expect(await screen.findByText('Marks saved.')).toBeInTheDocument();
  });

  it('refuses to save marks that do not add up to the total, and says by how much', async () => {
    const { fetchMock, user } = await start([mcq('q1', 1, 5), mcq('q2', 2, 5)]);
    await user.clear(screen.getByLabelText('Total marks'));
    await user.type(screen.getByLabelText('Total marks'), '20');
    await user.clear(screen.getByLabelText('Q1'));
    await user.type(screen.getByLabelText('Q1'), '12.5');

    expect(screen.getByTestId('marks-sum')).toHaveTextContent('Questions add up to 17.50, but the total is 20.00.');
    expect(screen.getByRole('button', { name: 'Save marks' })).toBeDisabled();
    expect(callsTo(fetchMock, 'PUT /api/questions/q1')).toHaveLength(0);

    await user.clear(screen.getByLabelText('Q2'));
    await user.type(screen.getByLabelText('Q2'), '7.5');
    expect(screen.getByRole('button', { name: 'Save marks' })).toBeEnabled();
  });

  it('rejects a mark that is not a number', async () => {
    const { user } = await start([mcq('q1', 1, 5)]);
    await user.clear(screen.getByLabelText('Total marks'));
    await user.type(screen.getByLabelText('Total marks'), '5');
    await user.clear(screen.getByLabelText('Q1'));
    await user.type(screen.getByLabelText('Q1'), 'abc');
    expect(screen.getByText('Every question needs marks greater than 0 with at most 2 decimal places.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Save marks' })).toBeDisabled();
  });

  it('includes code questions in the split and keeps their marks in this browser', async () => {
    saveExtras('e1', { method: 'manual', codeQuestions: [{ ...emptyCodeQuestion('c1'), text: 'Code it', marks: 1 }] });
    const { fetchMock, user } = await start([mcq('q1', 1, 1)]);
    await user.clear(screen.getByLabelText('Total marks'));
    await user.type(screen.getByLabelText('Total marks'), '20');
    await user.click(screen.getByRole('button', { name: 'Distribute equally' }));
    await user.click(screen.getByRole('button', { name: 'Save marks' }));

    await waitFor(() => expect(getExtras('e1').codeQuestions[0].marks).toBe(10));
    expect(callsTo(fetchMock, 'PUT /api/questions/q1')).toHaveLength(1);
  });
});

describe('the exam form', () => {
  it('has a subject dropdown from the central list, total marks first, and start, duration and end on one line', async () => {
    mockApi({});
    renderApp('/exams/new');
    const subject = await screen.findByLabelText('Subject');
    expect(subject.tagName).toBe('SELECT');
    expect(within(subject).getByRole('option', { name: 'Databases' })).toBeInTheDocument();
    expect(screen.getByLabelText('Total marks')).toBeInTheDocument();
    // No exam-language option exists on the form.
    const timing = screen.getByRole('group', { name: 'Exam time' });
    expect(within(timing.closest('form')!).queryByLabelText(/language/i)).not.toBeInTheDocument();
    expect(within(timing).getByLabelText('Start date and time')).toBeInTheDocument();
    expect(within(timing).getByLabelText('Duration (minutes)')).toBeInTheDocument();
    expect(within(timing).getByTestId('exam-ends')).toHaveTextContent('—');
  });

  it('computes the end time from start and duration', async () => {
    const user = userEvent.setup();
    mockApi({});
    renderApp('/exams/new');
    fireEvent.change(await screen.findByLabelText('Start date and time'), { target: { value: '2030-01-01T09:00' } });
    await user.clear(screen.getByLabelText('Duration (minutes)'));
    await user.type(screen.getByLabelText('Duration (minutes)'), '90');
    expect(screen.getByTestId('exam-ends')).not.toHaveTextContent('—');
  });

  it('rejects total marks that are not a number', async () => {
    const user = userEvent.setup();
    mockApi({});
    renderApp('/exams/new');
    await user.type(await screen.findByLabelText('Title'), 'Quiz');
    await user.type(screen.getByLabelText('Total marks'), 'lots');
    await user.click(screen.getByRole('button', { name: 'Create exam' }));
    expect(await screen.findByText('The total must be a number greater than 0 with at most 2 decimal places.')).toBeInTheDocument();
  });
});

describe('Edit draft', () => {
  it('loads the saved exam, its questions and its subject, and edits questions in place', async () => {
    saveExtras('e1', { subjectId: 'databases', totalMarks: 10, method: 'manual' });
    mockApi({
      [`GET ${EXAM}`]: [() => jsonResponse(200, exam())],
      [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [mcq('q1', 1, 5), essay('q2', 2, 5)] })],
    });
    renderApp('/exams/e1/edit');
    expect(await screen.findByLabelText('Title')).toHaveValue('Midterm');
    await waitFor(() => expect(screen.getByLabelText('Subject')).toHaveValue('databases'));
    expect(screen.getByLabelText('Total marks', { selector: '#exam-total-marks' })).toHaveValue('10');
    expect(await screen.findByText('Question 1')).toBeInTheDocument();
    expect(screen.getByText('Explain 2')).toBeInTheDocument();

    const user = userEvent.setup();
    await user.click(screen.getAllByRole('button', { name: 'Edit' })[0]);
    expect(screen.getByDisplayValue('Question 1')).toBeInTheDocument(); // the MCQ form is filled with the saved question
  });
});

describe('View as student', () => {
  it('shows what a student sees, never the answers, and writes nothing', async () => {
    saveExtras('e1', {
      subjectId: 'programming',
      codeQuestions: [{ ...emptyCodeQuestion('c1'), text: 'Write a loop.', marks: 4, languages: ['python', 'java'], autoCompletionEnabled: false }],
    });
    const fetchMock = mockApi({
      [`GET ${EXAM}`]: [() => jsonResponse(200, exam())],
      [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [mcq('q1', 1, 5), essay('q2', 2, 5)] })],
    });
    const user = userEvent.setup();
    renderApp('/exams/e1/preview');

    expect(await screen.findByText(/Nothing you do here is saved or submitted/)).toBeInTheDocument();
    expect(screen.getByText('Programming')).toBeInTheDocument();

    // MCQ: choices, no correct-answer marker.
    expect(screen.getByRole('radio', { name: 'Right' })).toBeInTheDocument();
    expect(screen.queryByText('✓')).not.toBeInTheDocument();
    await user.click(screen.getByRole('radio', { name: 'Wrong' }));
    await user.click(screen.getByRole('button', { name: 'Next' }));

    // Essay: an answer box, never the model answer.
    expect(screen.getByLabelText('Your answer')).toBeInTheDocument();
    expect(screen.queryByText('Secret model answer')).not.toBeInTheDocument();
    await user.type(screen.getByLabelText('Your answer'), 'My essay');
    await user.click(screen.getByRole('button', { name: 'Next' }));

    // Code: language, settings, autocomplete state, and a real editor.
    expect(screen.getByText('Write a loop.')).toBeInTheDocument();
    expect(screen.getByLabelText('Language', { selector: '#preview-c1-language' })).toHaveValue('python');
    expect(screen.getByTestId('autocomplete-state')).toHaveTextContent('Auto-completion: off');
    expect(await screen.findByRole('textbox', { name: 'Code editor' })).toBeInTheDocument();

    // Submitting is disabled, and only GET requests were ever made.
    expect(screen.getByRole('button', { name: 'Submit exam' })).toBeDisabled();
    expect(fetchMock.mock.calls.every(([, init]) => ((init as RequestInit | undefined)?.method ?? 'GET') === 'GET')).toBe(true);
  });

  it('an exam with no questions says there is nothing to preview', async () => {
    mockApi({ [`GET ${EXAM}`]: [() => jsonResponse(200, exam())], [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [] })] });
    renderApp('/exams/e1/preview');
    expect(await screen.findByText('Nothing to preview yet')).toBeInTheDocument();
  });

  it('is reachable from the exam page', async () => {
    mockApi({ [`GET ${EXAM}`]: [() => jsonResponse(200, exam())], [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [mcq('q1', 1, 5)] })] });
    renderApp('/exams/e1');
    expect(await screen.findByRole('link', { name: 'View as student' })).toHaveAttribute('href', '/exams/e1/preview');
  });
});


describe('one MCQ editor for single and multiple answers', () => {
  const QUESTIONS_PATH = '/api/exams/e1/questions';

  async function openNewMcq() {
    const user = userEvent.setup();
    saveExtras('e1', { method: 'manual' });
    const fetchMock = mockApi({
      [`GET ${EXAM}`]: [() => jsonResponse(200, exam())],
      [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [] })],
      [`POST ${QUESTIONS_PATH}`]: [() => jsonResponse(201, mcq('q9', 1, 1))],
    });
    renderApp('/exams/e1');
    await user.click(await screen.findByRole('button', { name: 'Add question' }));
    return { user, fetchMock };
  }

  it('has no separate "Multiple" type: only MCQ, Essay and Code', async () => {
    await openNewMcq();
    const picker = screen.getByRole('group', { name: 'Type' });
    expect(within(picker).getAllByRole('button').map((button) => button.textContent)).toEqual(['MCQ', 'Essay', 'Code']);
  });

  it('ticks one correct option for a single-answer question and says so', async () => {
    const { user } = await openNewMcq();
    expect(screen.getByTestId('answer-mode')).toHaveTextContent('Single answer');
    const boxes = screen.getAllByRole('checkbox', { name: /is a correct answer/ });
    expect(boxes.map((box) => (box as HTMLInputElement).checked)).toEqual([true, false]);
    await user.click(boxes[1]);
    expect(screen.getByTestId('answer-mode')).toHaveTextContent('Multiple answers');
  });

  it('saves several correct options in the same MCQ request', async () => {
    const { user, fetchMock } = await openNewMcq();
    await user.type(screen.getByLabelText('Question text'), 'Which are prime?');
    const texts = screen.getAllByLabelText(/^Option \d+ text$/);
    await user.type(texts[0], '2');
    await user.type(texts[1], '4');
    await user.click(screen.getByRole('button', { name: /Add option/ }));
    await user.type(screen.getAllByLabelText(/^Option \d+ text$/)[2], '5');
    const boxes = () => screen.getAllByRole('checkbox', { name: /is a correct answer/ });
    await user.click(boxes()[2]); // A and C are correct
    await user.click(screen.getByRole('button', { name: 'Add question' }));

    const [, init] = callsTo(fetchMock, `POST ${QUESTIONS_PATH}`)[0] as [string, RequestInit];
    const body = JSON.parse(init.body as string) as { type: string; options: Array<{ text: string; isCorrect: boolean }> };
    expect(body.type).toBe('Mcq');
    expect(body.options).toEqual([
      { text: '2', isCorrect: true },
      { text: '4', isCorrect: false },
      { text: '5', isCorrect: true },
    ]);
  });

  it('refuses an MCQ with no correct option before sending', async () => {
    const { user, fetchMock } = await openNewMcq();
    await user.type(screen.getByLabelText('Question text'), 'Q?');
    const texts = screen.getAllByLabelText(/^Option \d+ text$/);
    await user.type(texts[0], 'x');
    await user.type(texts[1], 'y');
    await user.click(screen.getAllByRole('checkbox', { name: /is a correct answer/ })[0]); // untick the only one
    await user.click(screen.getByRole('button', { name: 'Add question' }));
    expect(await screen.findByText('Choose at least one correct option.')).toBeInTheDocument();
    expect(callsTo(fetchMock, `POST ${QUESTIONS_PATH}`)).toHaveLength(0);
  });

  it('edits a stored multiple-answer question with its correct options ticked', async () => {
    const stored: Question = {
      ...mcq('q1', 1, 2),
      options: [
        { id: 'a', text: 'A1', isCorrect: true, position: 1 },
        { id: 'b', text: 'B1', isCorrect: false, position: 2 },
        { id: 'c', text: 'C1', isCorrect: true, position: 3 },
      ],
    };
    saveExtras('e1', { method: 'manual' });
    mockApi({ [`GET ${EXAM}`]: [() => jsonResponse(200, exam())], [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [stored] })] });
    renderApp('/exams/e1');
    expect(await screen.findByText('Several correct answers')).toBeInTheDocument(); // the list still shows one MCQ badge
    const user = userEvent.setup();
    await user.click(screen.getAllByRole('button', { name: 'Edit' })[0]);
    expect(screen.getAllByRole('checkbox', { name: /is a correct answer/ }).map((box) => (box as HTMLInputElement).checked)).toEqual([true, false, true]);
  });

  it('the student preview uses radio buttons for one correct answer and checkboxes for several', async () => {
    const multi: Question = {
      ...mcq('q2', 2, 2),
      options: [
        { id: 'x', text: 'Two', isCorrect: true, position: 1 },
        { id: 'y', text: 'Four', isCorrect: false, position: 2 },
        { id: 'z', text: 'Five', isCorrect: true, position: 3 },
      ],
    };
    mockApi({ [`GET ${EXAM}`]: [() => jsonResponse(200, exam())], [`GET ${QUESTIONS}`]: [() => jsonResponse(200, { items: [mcq('q1', 1, 1), multi] })] });
    const user = userEvent.setup();
    renderApp('/exams/e1/preview');

    expect(await screen.findByRole('radio', { name: 'Right' })).toBeInTheDocument(); // one correct answer
    expect(screen.queryByRole('checkbox')).not.toBeInTheDocument();
    await user.click(screen.getByRole('radio', { name: 'Wrong' }));
    await user.click(screen.getByRole('radio', { name: 'Right' }));
    expect(screen.getByRole('radio', { name: 'Right' })).toBeChecked();
    expect(screen.getByRole('radio', { name: 'Wrong' })).not.toBeChecked(); // single selection

    await user.click(screen.getByRole('button', { name: 'Next' }));
    expect(screen.queryByRole('radio')).not.toBeInTheDocument();
    expect(screen.getByText('Choose all that apply', { selector: 'p' })).toBeInTheDocument();
    await user.click(screen.getByRole('checkbox', { name: 'Two' }));
    await user.click(screen.getByRole('checkbox', { name: 'Five' }));
    expect(screen.getByRole('checkbox', { name: 'Two' })).toBeChecked();
    expect(screen.getByRole('checkbox', { name: 'Five' })).toBeChecked(); // several at once
    expect(screen.queryByText('✓')).not.toBeInTheDocument(); // the key is never shown to the student view
  });
});
