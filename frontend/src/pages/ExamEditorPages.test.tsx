import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { AuthProvider } from '../auth/AuthContext';
import { tokenStore } from '../auth/tokenStore';
import { exam, jsonResponse, problem, tokenResponse } from '../test/fixtures';
import type { Exam } from '../types/api';
import { EditExamPage } from './ExamEditorPages';

// Answers GET /api/exams/e1 from a queue (the first load, then the reload) and PUT /api/exams/e1 with one response.
function mockServer(loads: Array<Exam | Response>, putResponse: Response) {
  const queue = [...loads];
  const fetchMock = vi.fn((_url: string, init: RequestInit) => {
    if (init.method === 'PUT') return Promise.resolve(putResponse);
    const next = queue.length > 1 ? queue.shift()! : queue[0];
    return Promise.resolve(next instanceof Response ? next : jsonResponse(200, next));
  });
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

function renderEditPage() {
  tokenStore.setFromTokenResponse(tokenResponse());
  return render(
    <AuthProvider>
      <MemoryRouter initialEntries={['/exams/e1/edit']}>
        <Routes>
          <Route path="/exams/:examId/edit" element={<EditExamPage />} />
          <Route path="/exams/:examId" element={<p>Exam details page</p>} />
        </Routes>
      </MemoryRouter>
    </AuthProvider>,
  );
}

async function changeTitleAndSave(title: string) {
  const user = userEvent.setup();
  const input = await screen.findByLabelText('Title');
  await user.clear(input);
  await user.type(input, title);
  await user.click(screen.getByRole('button', { name: 'Save changes' }));
}

const getCalls = (fetchMock: ReturnType<typeof mockServer>) =>
  fetchMock.mock.calls.filter(([, init]) => (init as RequestInit).method === 'GET');

describe('EditExamPage when a save is refused', () => {
  it('409 because the exam has started: shows the server message, reloads, and replaces the form', async () => {
    const detail = 'The exam can no longer be changed in its current state.';
    const fetchMock = mockServer(
      [exam(), exam({ phase: 'Open' })],
      problem(409, 'exam_not_editable', detail),
    );
    renderEditPage();

    await changeTitleAndSave('Changed title');

    expect(await screen.findByText(detail)).toBeInTheDocument();
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Save changes' })).not.toBeInTheDocument());
    expect(screen.getByText(/can no longer be edited because it has started/)).toBeInTheDocument();
    expect(getCalls(fetchMock)).toHaveLength(2); // the first load and the reload
  });

  it('409 while the exam is still editable: shows the message, reloads, and keeps what the user typed', async () => {
    const detail = 'The exam can no longer be changed in its current state.';
    const fetchMock = mockServer([exam(), exam({ title: 'Changed on the server' })], problem(409, 'exam_not_editable', detail));
    renderEditPage();

    await changeTitleAndSave('My unsaved title');

    expect(await screen.findByText(detail)).toBeInTheDocument();
    await waitFor(() => expect(getCalls(fetchMock)).toHaveLength(2));
    expect(screen.getByLabelText('Title')).toHaveValue('My unsaved title'); // not silently overwritten
    expect(screen.getByRole('button', { name: 'Save changes' })).toBeEnabled();
  });

  it('404 because the exam is gone: shows one clear message, hides the form and offers a way back', async () => {
    const fetchMock = mockServer(
      [exam(), problem(404, 'exam_not_found', 'The exam was not found.')],
      problem(404, 'exam_not_found', 'The exam was not found.'),
    );
    renderEditPage();

    await changeTitleAndSave('Changed title');

    const notFoundText = 'This exam was not found, or it belongs to another instructor.';
    expect(await screen.findByText(notFoundText)).toBeInTheDocument();
    await waitFor(() => expect(screen.queryByRole('button', { name: 'Save changes' })).not.toBeInTheDocument());
    expect(screen.getAllByText(notFoundText)).toHaveLength(1);
    expect(screen.getByRole('link', { name: 'Back to my exams' })).toBeInTheDocument();
    expect(getCalls(fetchMock)).toHaveLength(2);
  });

  it('a successful save goes to the details page and does not reload', async () => {
    const fetchMock = mockServer([exam()], jsonResponse(200, exam({ title: 'Saved' })));
    renderEditPage();

    await changeTitleAndSave('Saved');

    expect(await screen.findByText('Exam details page')).toBeInTheDocument();
    expect(getCalls(fetchMock)).toHaveLength(1);
  });

  it('400 field errors stay on the form (no reload)', async () => {
    const fetchMock = mockServer(
      [exam()],
      problem(400, 'validation_failed', 'One or more fields are invalid.', { title: ['Title is required.'] }),
    );
    renderEditPage();

    await changeTitleAndSave('Changed title');

    expect(await screen.findByText('Title is required.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Save changes' })).toBeInTheDocument();
    expect(getCalls(fetchMock)).toHaveLength(1);
  });
});
