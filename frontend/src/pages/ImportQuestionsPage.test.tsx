import { fireEvent, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { ar } from '../i18n/ar';
import { en } from '../i18n/en';
import { exam, jsonResponse, problem, tokenResponse } from '../test/fixtures';
import { callsTo, chooseLanguage, mockApi, renderApp } from '../test/helpers';
import type { ImportedQuestion, QuestionImportPreview } from '../types/api';

const PREVIEW = 'POST /api/questions/import/preview';
const EXAMS = 'GET /api/exams';
const CREATE_EXAM = 'POST /api/exams';
const IMPORT_E1 = 'POST /api/exams/e1/questions/import';
const DOCX = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

const goodQuestion = (overrides: Partial<ImportedQuestion> = {}): ImportedQuestion => ({
  number: 1,
  line: 2,
  type: 'Mcq',
  text: 'What does CPU stand for?',
  marks: 2,
  marksDefaulted: false,
  modelAnswer: null,
  options: [
    { label: 'A', text: 'Central Processing Unit', isCorrect: true },
    { label: 'B', text: 'Computer Personal Unit', isCorrect: false },
  ],
  issues: [],
  ...overrides,
});

const missingAnswer = (): ImportedQuestion =>
  goodQuestion({
    number: 2,
    text: 'Which is a language?',
    options: [
      { label: 'A', text: 'HTML', isCorrect: false },
      { label: 'B', text: 'Python', isCorrect: false },
    ],
    issues: [
      { code: 'correct_answer_missing', severity: 'error', message: 'Question 2: the correct answer is missing.', question: 2, line: 8 },
    ],
  });

const preview = (questions: ImportedQuestion[], overrides: Partial<QuestionImportPreview> = {}): QuestionImportPreview => ({
  examTitle: 'Intro to CS',
  defaultMarks: 1,
  maxOptions: 8,
  isValid: questions.every((q) => q.issues.length === 0),
  questions,
  issues: [],
  ...overrides,
});

const examList = () =>
  jsonResponse(200, {
    items: [
      exam({ id: 'e1', title: 'Midterm' }),
      exam({ id: 'e2', title: 'Cancelled one', status: 'Cancelled' }),
      exam({ id: 'e3', title: 'Already started', phase: 'Open' }),
    ],
    page: 1,
    pageSize: 100,
    totalCount: 3,
  });

const file = (name = 'exam.docx', size = 20) => new File([new Uint8Array(size)], name, { type: DOCX });

function start(routes: Parameters<typeof mockApi>[0], path = '/import') {
  chooseLanguage('en');
  tokenStore.setFromTokenResponse(tokenResponse());
  const fetchMock = mockApi({ [EXAMS]: [examList], ...routes });
  renderApp(path);
  return fetchMock;
}

async function upload(user: ReturnType<typeof userEvent.setup>, selected = file()) {
  await user.upload(screen.getByLabelText(en['import.chooseFile']), selected);
}

async function readDocument(user: ReturnType<typeof userEvent.setup>) {
  await upload(user);
  await user.click(screen.getByRole('button', { name: en['import.read'] }));
  await screen.findByRole('heading', { name: en['import.reviewTitle'] });
}

const importButton = (count: string) => screen.getByRole('button', { name: en['import.action.import'].replace('{count}', count) });
const choose = async (user: ReturnType<typeof userEvent.setup>, examId: string) =>
  user.selectOptions(await screen.findByLabelText(en['import.target.exam']), examId);

describe('ImportQuestionsPage: choosing the file', () => {
  it('is reachable from the header and starts with the upload step and a template download', async () => {
    start({}, '/exams');
    const user = userEvent.setup();

    await user.click(await screen.findByRole('link', { name: en['nav.import'] }));

    expect(await screen.findByRole('heading', { name: en['import.title'] })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: en['import.template'] })).toHaveAttribute('href', '/question-import-template.docx');
    expect(screen.getByRole('button', { name: en['import.read'] })).toBeDisabled();
  });

  it('refuses a file that is not .docx before sending anything', async () => {
    const fetchMock = start({});
    const user = userEvent.setup({ applyAccept: false });
    await screen.findByRole('heading', { name: en['import.title'] });

    await user.upload(screen.getByLabelText(en['import.chooseFile']), file('notes.txt'));

    expect(screen.getByText(en['val.fileExtension'])).toBeInTheDocument();
    expect(screen.getByRole('button', { name: en['import.read'] })).toBeDisabled();
    expect(callsTo(fetchMock, PREVIEW)).toHaveLength(0);
  });

  it('refuses an empty file and a file over 10 MB, and shows the name and size of a good one', async () => {
    start({});
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });

    await user.upload(screen.getByLabelText(en['import.chooseFile']), file('empty.docx', 0));
    expect(screen.getByText(en['val.fileEmpty'])).toBeInTheDocument();

    await user.upload(screen.getByLabelText(en['import.chooseFile']), file('big.docx', 10 * 1024 * 1024 + 1));
    expect(screen.getByText(en['val.fileTooLarge'])).toBeInTheDocument();

    await user.upload(screen.getByLabelText(en['import.chooseFile']), file('good.docx', 2048));
    expect(screen.getByText('good.docx')).toBeInTheDocument();
    expect(screen.getByText(/2 KB/)).toBeInTheDocument();
    expect(screen.queryByText(en['val.fileTooLarge'])).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: en['import.read'] })).toBeEnabled();
  });

  it('accepts a dropped file', async () => {
    start({});
    await screen.findByRole('heading', { name: en['import.title'] });
    const zone = screen.getByText(en['import.drop']).closest('.dropzone')!;

    fireEvent.drop(zone, { dataTransfer: { files: [file('dropped.docx')] } });

    expect(await screen.findByText('dropped.docx')).toBeInTheDocument();
  });

  it('sends the file as multipart/form-data in the field "file", with the access token and without a manual Content-Type', async () => {
    const fetchMock = start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });

    await readDocument(user);

    const [url, init] = callsTo(fetchMock, PREVIEW)[0] as [string, RequestInit];
    expect(url).toBe('/api/questions/import/preview');
    expect(init.body).toBeInstanceOf(FormData);
    const sent = (init.body as FormData).get('file') as File;
    expect(sent.name).toBe('exam.docx');
    const headers = init.headers as Record<string, string>;
    expect(headers.Authorization).toBe('Bearer access-1');
    expect(Object.keys(headers).map((h) => h.toLowerCase())).not.toContain('content-type');
  });

  it.each([
    [400, 'validation_failed', { file: ['The file is not a valid Word (.docx) document.'] }, 'The file is not a valid Word (.docx) document.'],
    [400, 'validation_failed', { file: ['The file is empty.'] }, 'The file is empty.'],
    [413, undefined, undefined, en['error.tooLarge']],
    [500, undefined, undefined, en['error.server']],
  ])('shows the server answer %i for the file and lets the user retry', async (status, code, errors, text) => {
    start({ [PREVIEW]: [() => problem(status, code, 'One or more fields are invalid.', errors)] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await upload(user);

    await user.click(screen.getByRole('button', { name: en['import.read'] }));

    expect(await screen.findByRole('alert')).toHaveTextContent(text);
    expect(screen.getByRole('button', { name: en['import.read'] })).toBeEnabled(); // retry
  });

  it('shows the Arabic message for a file problem in Arabic', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockApi({
      [EXAMS]: [examList],
      [PREVIEW]: [() => problem(400, 'validation_failed', 'One or more fields are invalid.', { file: ['The file is empty.'] })],
    });
    renderApp('/import');
    const user = userEvent.setup();
    await user.upload(await screen.findByLabelText(ar['import.chooseFile']), file());

    await user.click(screen.getByRole('button', { name: ar['import.read'] }));

    expect(await screen.findByRole('alert')).toHaveTextContent(ar['val.fileEmpty']);
    expect(document.documentElement.dir).toBe('rtl');
  });
});

describe('ImportQuestionsPage: reviewing', () => {
  it('shows the questions with their options and the marked correct answer, and saves nothing yet', async () => {
    const fetchMock = start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion(), goodQuestion({ number: 2, text: 'Second?' })]))] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });

    await readDocument(user);

    expect(screen.getByText(/Intro to CS/)).toBeInTheDocument();
    expect(screen.getByDisplayValue('What does CPU stand for?')).toBeInTheDocument();
    expect(screen.getByDisplayValue('Second?')).toBeInTheDocument();
    const firstCard = screen.getAllByRole('listitem').find((li) => li.querySelector('textarea')?.value === 'What does CPU stand for?')!;
    expect(within(firstCard).getByRole('radio', { name: en['qform.optionCorrect'].replace('{n}', 'A') })).toBeChecked();
    expect(within(firstCard).getByRole('radio', { name: en['qform.optionCorrect'].replace('{n}', 'B') })).not.toBeChecked();
    expect(callsTo(fetchMock, IMPORT_E1)).toHaveLength(0);
    expect(screen.getByText(new RegExp(en['import.allGood']))).toBeInTheDocument();
  });

  it('flags a question with a problem, blocks the import, and unblocks it after the instructor fixes the question', async () => {
    start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion(), missingAnswer()]))] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);

    expect(screen.getByText(en['import.card.attention'])).toBeInTheDocument();
    expect(screen.getByText('the correct answer is missing.')).toBeInTheDocument(); // the backend's text, without "Question 2:"
    expect(importButton('2 questions')).toBeDisabled();
    expect(screen.getByText(new RegExp(en['import.fixFirst']))).toBeInTheDocument();

    const problemCard = screen.getAllByRole('listitem').find((li) => li.querySelector('textarea')?.value === 'Which is a language?')!;
    await user.click(within(problemCard).getByRole('radio', { name: en['qform.optionCorrect'].replace('{n}', 'B') }));

    await waitFor(() => expect(importButton('2 questions')).toBeEnabled());
    expect(screen.queryByText(en['import.card.attention'])).not.toBeInTheDocument();
    expect(screen.getByText(en['import.card.edited'])).toBeInTheDocument();
  });

  it('lets the instructor remove a question from the import', async () => {
    start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion(), missingAnswer()]))] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);

    const [removeProblem] = screen.getAllByRole('button', { name: en['import.card.remove'] }).slice(-1);
    await user.click(removeProblem);

    expect(screen.queryByDisplayValue('Which is a language?')).not.toBeInTheDocument();
    expect(importButton('1 question')).toBeEnabled();
  });

  it('shows the document notes (warnings)', async () => {
    start({
      [PREVIEW]: [
        () =>
          jsonResponse(
            200,
            preview([goodQuestion()], {
              issues: [{ code: 'text_outside_question', severity: 'warning', message: 'Line 1 is before the first question and was ignored: "Midterm".', question: null, line: 1 }],
            }),
          ),
      ],
    });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });

    await readDocument(user);

    expect(screen.getByRole('heading', { name: en['import.notesTitle'] })).toBeInTheDocument();
    expect(screen.getByText(/Line 1 is before the first question/)).toBeInTheDocument();
  });

  it('shows the problems in Arabic, with Arabic labels', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockApi({ [EXAMS]: [examList], [PREVIEW]: [() => jsonResponse(200, preview([missingAnswer()]))] });
    renderApp('/import');
    const user = userEvent.setup();
    await user.upload(await screen.findByLabelText(ar['import.chooseFile']), file());
    await user.click(screen.getByRole('button', { name: ar['import.read'] }));

    expect(await screen.findByRole('heading', { name: ar['import.reviewTitle'] })).toBeInTheDocument();
    expect(screen.getByText(ar['import.issue.correct_answer_missing'])).toBeInTheDocument();
    expect(screen.getByText(ar['import.card.attention'])).toBeInTheDocument();
  });

  it('discards the import after a confirmation, without saving anything', async () => {
    const fetchMock = start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);

    await user.click(screen.getByRole('button', { name: en['import.action.cancel'] }));
    expect(screen.getByRole('dialog', { name: en['import.discardTitle'] })).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: en['common.keep'] }));
    expect(screen.getByRole('heading', { name: en['import.reviewTitle'] })).toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: en['import.action.cancel'] }));
    await user.click(screen.getByRole('button', { name: en['import.discard'] }));

    expect(await screen.findByRole('heading', { name: en['import.title'] })).toBeInTheDocument();
    expect(fetchMock.mock.calls.filter(([, init]) => (init as RequestInit | undefined)?.method === 'POST')).toHaveLength(1); // only the preview
  });
});

describe('ImportQuestionsPage: importing', () => {
  const savedResponse = () => jsonResponse(201, { items: [{ id: 'q1' }, { id: 'q2' }] });

  it('lists only exams that can still receive questions', async () => {
    start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);

    const select = await screen.findByLabelText(en['import.target.exam']);
    const options = within(select).getAllByRole('option').map((o) => o.textContent);
    expect(options.some((text) => text?.startsWith('Midterm'))).toBe(true);
    expect(options.some((text) => text?.includes('Cancelled one'))).toBe(false);
    expect(options.some((text) => text?.includes('Already started'))).toBe(false);
  });

  it('saves the reviewed questions into the chosen exam and shows a link to it', async () => {
    const fetchMock = start({
      [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion(), goodQuestion({ number: 2, type: 'Essay', text: 'Explain RAM.', marks: 5, modelAnswer: 'Fast memory.', options: [] })]))],
      [IMPORT_E1]: [savedResponse],
    });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await user.clear(screen.getByDisplayValue('What does CPU stand for?'));
    await user.type(screen.getAllByLabelText(en['qform.text'])[0], 'Edited question?');
    await choose(user, 'e1');

    await user.click(importButton('2 questions'));

    expect(await screen.findByRole('heading', { name: en['import.doneTitle'] })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: en['import.openExam'] })).toHaveAttribute('href', '/exams/e1');
    const [, init] = callsTo(fetchMock, IMPORT_E1)[0] as [string, RequestInit];
    expect(JSON.parse(init.body as string)).toEqual({
      questions: [
        {
          type: 'Mcq',
          text: 'Edited question?',
          marks: 2,
          modelAnswer: null,
          options: [
            { text: 'Central Processing Unit', isCorrect: true },
            { text: 'Computer Personal Unit', isCorrect: false },
          ],
        },
        { type: 'Essay', text: 'Explain RAM.', marks: 5, modelAnswer: 'Fast memory.', options: [] },
      ],
    });
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer access-1');
  });

  it('preselects the exam from the link on the exam page', async () => {
    start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))], [IMPORT_E1]: [savedResponse] }, '/import?examId=e1');
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);

    await waitFor(() => expect(screen.getByLabelText(en['import.target.exam'])).toHaveValue('e1'));
    await user.click(importButton('1 question'));

    expect(await screen.findByRole('heading', { name: en['import.doneTitle'] })).toBeInTheDocument();
  });

  it('asks for an exam when none is chosen and sends nothing', async () => {
    const fetchMock = start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await screen.findByLabelText(en['import.target.exam']);

    await user.click(importButton('1 question'));

    expect(await screen.findByText(en['val.examRequired'])).toBeInTheDocument();
    expect(screen.getByLabelText(en['import.target.exam'])).toHaveAttribute('aria-invalid', 'true');
    expect(callsTo(fetchMock, IMPORT_E1)).toHaveLength(0);
  });

  it('checks the edited questions before sending: a question without a correct answer is not sent', async () => {
    const fetchMock = start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))], [IMPORT_E1]: [savedResponse] }, '/import?examId=e1');
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await screen.findByDisplayValue('Central Processing Unit');
    await user.clear(screen.getByDisplayValue('Central Processing Unit'));

    await user.click(importButton('1 question'));

    expect(await screen.findByText(en['val.optionRequired'])).toBeInTheDocument();
    expect(callsTo(fetchMock, IMPORT_E1)).toHaveLength(0);
  });

  it('creates a new exam from the details the instructor enters, then imports into it', async () => {
    const fetchMock = start({
      [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))],
      [CREATE_EXAM]: [() => jsonResponse(201, exam({ id: 'new1', title: 'Intro to CS' }))],
      'POST /api/exams/new1/questions/import': [savedResponse],
    });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await user.click(screen.getByRole('radio', { name: en['import.target.new'] }));
    expect(screen.getByLabelText(en['examForm.title'])).toHaveValue('Intro to CS'); // from the document

    await user.click(importButton('1 question')); // start time still missing
    expect(await screen.findByText(en['val.startRequired'])).toBeInTheDocument();
    expect(callsTo(fetchMock, CREATE_EXAM)).toHaveLength(0);

    fireEvent.change(screen.getByLabelText(en['examForm.start']), { target: { value: '2099-01-01T09:00' } });
    await user.click(importButton('1 question'));

    expect(await screen.findByRole('heading', { name: en['import.doneTitle'] })).toBeInTheDocument();
    const [, init] = callsTo(fetchMock, CREATE_EXAM)[0] as [string, RequestInit];
    const body = JSON.parse(init.body as string);
    expect(Object.keys(body).sort()).toEqual(['description', 'durationMinutes', 'startsAt', 'title']);
    expect(body.title).toBe('Intro to CS');
    expect(body.startsAt).toMatch(/^2099-01-01T09:00:00[+-]\d{2}:\d{2}$/); // with the browser's offset
    expect(screen.getByRole('link', { name: en['import.openExam'] })).toHaveAttribute('href', '/exams/new1');
  });

  it('does not create the new exam twice when a failed import is retried', async () => {
    const fetchMock = start({
      [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))],
      [CREATE_EXAM]: [() => jsonResponse(201, exam({ id: 'new1', title: 'Intro to CS' }))],
      'POST /api/exams/new1/questions/import': [() => problem(500, undefined, 'boom'), savedResponse],
    });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await user.click(screen.getByRole('radio', { name: en['import.target.new'] }));
    fireEvent.change(screen.getByLabelText(en['examForm.start']), { target: { value: '2099-01-01T09:00' } });

    await user.click(importButton('1 question'));
    expect(await screen.findByRole('alert')).toHaveTextContent(en['error.server']);
    expect(screen.getByText(en['import.target.created'].replace('{title}', 'Intro to CS'))).toBeInTheDocument();

    await user.click(importButton('1 question'));

    expect(await screen.findByRole('heading', { name: en['import.doneTitle'] })).toBeInTheDocument();
    expect(callsTo(fetchMock, CREATE_EXAM)).toHaveLength(1);
    expect(callsTo(fetchMock, 'POST /api/exams/new1/questions/import')).toHaveLength(2);
  });

  it('sends only one request when the button is clicked twice quickly', async () => {
    let release: (response: Response) => void = () => undefined;
    const fetchMock = start(
      { [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))], [IMPORT_E1]: [() => new Promise<Response>((resolve) => (release = resolve))] },
      '/import?examId=e1',
    );
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await waitFor(() => expect(screen.getByLabelText(en['import.target.exam'])).toHaveValue('e1'));

    const button = importButton('1 question');
    await user.dblClick(button);

    expect(await screen.findByRole('button', { name: en['import.action.importing'] })).toBeDisabled();
    expect(callsTo(fetchMock, IMPORT_E1)).toHaveLength(1);
    release(savedResponse());
    expect(await screen.findByRole('heading', { name: en['import.doneTitle'] })).toBeInTheDocument();
    expect(callsTo(fetchMock, IMPORT_E1)).toHaveLength(1);
  });

  it('puts the backend field errors on the right question and keeps everything the instructor typed', async () => {
    start(
      {
        [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion(), goodQuestion({ number: 2, text: 'Second?' })]))],
        [IMPORT_E1]: [
          () =>
            problem(400, 'validation_failed', 'One or more fields are invalid.', {
              'questions[1].options[0].text': ['Option text must be at most 1000 characters.'],
              'questions[1].marks': ['Marks can have at most 2 decimal places.'],
            }),
        ],
      },
      '/import?examId=e1',
    );
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await waitFor(() => expect(screen.getByLabelText(en['import.target.exam'])).toHaveValue('e1'));

    await user.click(importButton('2 questions'));

    expect(await screen.findByText('Option text must be at most 1000 characters.')).toBeInTheDocument();
    expect(screen.getByText('Marks can have at most 2 decimal places.')).toBeInTheDocument();
    const second = screen.getAllByRole('listitem').find((li) => li.querySelector('textarea')?.value === 'Second?')!;
    expect(within(second).getByText('Marks can have at most 2 decimal places.')).toBeInTheDocument();
    expect(screen.getByDisplayValue('What does CPU stand for?')).toBeInTheDocument();
  });

  it.each([
    [409, 'exam_not_editable', 'The exam can no longer be changed in its current state.'],
    [404, 'exam_not_found', en['error.examNotFound']],
  ])('shows a %i answer from the import and keeps the review so nothing is lost', async (status, code, text) => {
    start(
      { [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))], [IMPORT_E1]: [() => problem(status, code, 'The exam can no longer be changed in its current state.')] },
      '/import?examId=e1',
    );
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await waitFor(() => expect(screen.getByLabelText(en['import.target.exam'])).toHaveValue('e1'));

    await user.click(importButton('1 question'));

    expect(await screen.findByRole('alert')).toHaveTextContent(text);
    expect(screen.getByDisplayValue('What does CPU stand for?')).toBeInTheDocument();
    expect(importButton('1 question')).toBeEnabled(); // can retry or choose another exam
  });

  it('can import another file after a success', async () => {
    start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion()]))], [IMPORT_E1]: [savedResponse] }, '/import?examId=e1');
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });
    await readDocument(user);
    await waitFor(() => expect(screen.getByLabelText(en['import.target.exam'])).toHaveValue('e1'));
    await user.click(importButton('1 question'));
    await screen.findByRole('heading', { name: en['import.doneTitle'] });

    await user.click(screen.getByRole('button', { name: en['import.another'] }));

    expect(await screen.findByRole('heading', { name: en['import.title'] })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: en['import.read'] })).toBeDisabled();
  });
});

describe('ImportQuestionsPage: warnings do not block', () => {
  const inferredEssay = (): ImportedQuestion =>
    goodQuestion({
      number: 3,
      type: 'Essay',
      text: 'Discuss the role of the CPU.',
      options: [],
      issues: [
        {
          code: 'inferred_essay',
          severity: 'warning',
          message: 'Question 3: no options or answer letter were found, so it is imported as an essay question. Check it.',
          question: 3,
          line: 4,
        },
        { code: 'unexpected_line', severity: 'warning', message: 'Question 3: line 9 does not belong to the question and was not imported: "End".', question: 3, line: 9 },
      ],
    });

  it('shows the warnings on the question but leaves the import enabled and the question unflagged', async () => {
    start({ [PREVIEW]: [() => jsonResponse(200, preview([goodQuestion(), inferredEssay()]))] });
    const user = userEvent.setup();
    await screen.findByRole('heading', { name: en['import.title'] });

    await readDocument(user);

    expect(screen.getByText(/no options or answer letter were found/)).toBeInTheDocument();
    expect(screen.getByText(/line 9 does not belong to the question/)).toBeInTheDocument();
    expect(screen.queryByText(en['import.card.attention'])).not.toBeInTheDocument();
    expect(importButton('2 questions')).toBeEnabled();
    expect(screen.getByText(new RegExp(en['import.allGood']))).toBeInTheDocument();
  });

  it('shows the inferred-essay warning in Arabic', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockApi({ [EXAMS]: [examList], [PREVIEW]: [() => jsonResponse(200, preview([inferredEssay()]))] });
    renderApp('/import');
    const user = userEvent.setup();
    await user.upload(await screen.findByLabelText(ar['import.chooseFile']), file());
    await user.click(screen.getByRole('button', { name: ar['import.read'] }));

    expect(await screen.findByText(ar['import.issue.inferred_essay'])).toBeInTheDocument();
    expect(screen.queryByText(ar['import.card.attention'])).not.toBeInTheDocument();
  });
});
