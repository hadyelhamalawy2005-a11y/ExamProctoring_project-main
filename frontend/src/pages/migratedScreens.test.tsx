import { screen, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { ar } from '../i18n/ar';
import { en } from '../i18n/en';
import { getExtras } from '../local/examExtras';
import { exam, jsonResponse, tokenResponse } from '../test/fixtures';
import { chooseLanguage, mockApi, renderApp } from '../test/helpers';
import type { Role } from '../types/api';

// The destinations of the mobile app, in the web app: instructor Home, the create-exam method screen, and the screens
// whose data the backend cannot serve yet (which must say so, and must not call anything or show sample data).

const EXAMS = 'GET /api/exams';
const list = (totalCount: number) => () => jsonResponse(200, { items: [], page: 1, pageSize: 1, totalCount });
const signIn = (role: Role) => tokenStore.setFromTokenResponse(tokenResponse({ role }));

beforeEach(() => chooseLanguage('en'));

describe('instructor Home', () => {
  it('shows the welcome card and the real exam totals per status', async () => {
    signIn('Instructor');
    const fetchMock = mockApi({ [EXAMS]: [list(2), list(5), list(1)] });
    renderApp('/instructor');
    expect(await screen.findByRole('heading', { name: 'Welcome, Test Instructor' })).toBeInTheDocument();
    expect(await screen.findByTestId('count-Draft')).toHaveTextContent('Draft: 2');
    expect(screen.getByTestId('count-Published')).toHaveTextContent('Published: 5');
    expect(screen.getByTestId('count-Cancelled')).toHaveTextContent('Cancelled: 1');
    const urls = fetchMock.mock.calls.map(([url]) => String(url));
    expect(urls).toEqual(
      expect.arrayContaining(['/api/exams?page=1&pageSize=1&status=Draft', '/api/exams?page=1&pageSize=1&status=Published', '/api/exams?page=1&pageSize=1&status=Cancelled']),
    );
  });

  it('says attempts and incidents are not available instead of showing zeros', async () => {
    signIn('Instructor');
    mockApi({ [EXAMS]: [list(0)] });
    renderApp('/instructor');
    expect(await screen.findByText(en['home.attemptsUnavailable'])).toBeInTheDocument();
    expect(screen.getByText(en['home.incidentsUnavailable'])).toBeInTheDocument();
  });

  it('a failed load is an error with retry, not zeros', async () => {
    signIn('Instructor');
    mockApi({ [EXAMS]: [() => jsonResponse(500, { status: 500 })] });
    renderApp('/instructor');
    expect(await screen.findByRole('alert')).toBeInTheDocument();
    expect(screen.queryByTestId('count-Draft')).not.toBeInTheDocument();
  });

  it('has the mobile app’s four tabs, and Create exam goes to the method screen', async () => {
    signIn('Instructor');
    mockApi({ [EXAMS]: [list(0)] });
    renderApp('/instructor');
    const nav = await screen.findByRole('navigation', { name: en['nav.main'] });
    expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual(['Home', 'Exams', 'Incidents', 'Profile']);
    expect(screen.getByRole('link', { name: en['list.createExam'] })).toHaveAttribute('href', '/exams/new/method');
  });

  it('in Arabic, right to left', async () => {
    chooseLanguage('ar');
    signIn('Instructor');
    mockApi({ [EXAMS]: [list(0)] });
    renderApp('/instructor');
    expect(await screen.findByRole('link', { name: ar['nav.incidents'] })).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute('dir', 'rtl');
  });
});

describe('create exam: the method is chosen once', () => {
  it('offers manual or Word, and the choice is carried to the new exam', async () => {
    const user = userEvent.setup();
    signIn('Instructor');
    mockApi({
      'POST /api/exams': [() => jsonResponse(201, exam({ id: 'new1' }))],
      'GET /api/exams/new1': [() => jsonResponse(200, exam({ id: 'new1' }))],
      'GET /api/exams/new1/questions': [() => jsonResponse(200, { items: [] })],
    });
    renderApp('/exams/new/method');
    await user.click(await screen.findByRole('link', { name: new RegExp(en['method.manual']) }));

    await user.type(await screen.findByLabelText(en['examForm.title']), 'Quiz');
    await user.type(screen.getByLabelText(en['examForm.start']), '2099-01-01T09:00').catch(() => undefined);
    // The start field is a datetime-local input; set it the way the browser reports it.
    const start = screen.getByLabelText(en['examForm.start']) as HTMLInputElement;
    const { fireEvent } = await import('@testing-library/react');
    fireEvent.change(start, { target: { value: '2099-01-01T09:00' } });
    await user.click(screen.getByRole('button', { name: en['editor.create'] }));

    expect(await screen.findByRole('heading', { name: 'Midterm' })).toBeInTheDocument(); // the exam page of the created exam
    expect(getExtras('new1').method).toBe('manual');
  });

  it('the Word method continues to the import screen for the new exam', async () => {
    const user = userEvent.setup();
    signIn('Instructor');
    mockApi({
      'POST /api/exams': [() => jsonResponse(201, exam({ id: 'new2' }))],
      [EXAMS]: [() => jsonResponse(200, { items: [exam({ id: 'new2' })], page: 1, pageSize: 100, totalCount: 1 })],
    });
    renderApp('/exams/new?method=word');
    await user.type(await screen.findByLabelText(en['examForm.title']), 'Quiz');
    const { fireEvent } = await import('@testing-library/react');
    fireEvent.change(screen.getByLabelText(en['examForm.start']), { target: { value: '2099-01-01T09:00' } });
    await user.click(screen.getByRole('button', { name: en['editor.create'] }));
    expect(await screen.findByRole('heading', { name: en['import.title'] })).toBeInTheDocument();
    expect(getExtras('new2').method).toBe('word');
  });
});

describe('destinations the backend cannot serve yet', () => {
  const instructor: Array<[string, string]> = [
    ['/incidents', en['unavailable.incidents']],
    ['/incidents/i1', en['unavailable.incidents']],
    ['/exams/e1/attempts', en['unavailable.attempts']],
  ];
  it.each(instructor)('instructor %s says what is missing and calls nothing', async (path, body) => {
    signIn('Instructor');
    const fetchMock = mockApi({});
    renderApp(path);
    expect(await screen.findByText(en['unavailable.title'])).toBeInTheDocument();
    expect(screen.getByText(body)).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  const student: Array<[string, string]> = [
    ['/student/exams', en['unavailable.studentExams']],
    ['/student/results', en['unavailable.studentResults']],
    ['/student/exams/e1', en['unavailable.studentExam']],
    ['/student/exams/e1/consent', en['unavailable.studentExam']],
    ['/student/exams/e1/system-check', en['unavailable.studentExam']],
    ['/student/attempts/a1', en['unavailable.attempt']],
    ['/student/attempts/a1/result', en['unavailable.attempt']],
  ];
  it.each(student)('student %s says what is missing and calls nothing', async (path, body) => {
    signIn('Student');
    const fetchMock = mockApi({});
    renderApp(path);
    expect(await screen.findByText(en['unavailable.title'])).toBeInTheDocument();
    expect(screen.getByText(body)).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('the student tabs are Home, Exams, Results and Profile', async () => {
    signIn('Student');
    mockApi({});
    renderApp('/student/results');
    const nav = await screen.findByRole('navigation', { name: en['nav.main'] });
    expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual(['Home', 'Exams', 'Results', 'Profile']);
  });

  it('a student cannot open the instructor’s incident screen', async () => {
    signIn('Student');
    mockApi({});
    renderApp('/incidents');
    expect(await screen.findByRole('heading', { name: en['access.title'] })).toBeInTheDocument();
  });
});
