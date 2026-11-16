import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { ExamActions } from '../components/ExamActions';
import { StatusBadge } from '../components/StatusBadge';
import { LanguageProvider } from '../i18n/LanguageContext';
import { ar } from '../i18n/ar';
import { en } from '../i18n/en';
import { exam, jsonResponse, tokenResponse } from '../test/fixtures';
import { chooseLanguage, mockApi, renderApp } from '../test/helpers';

// The Finished status. The backend does not send it yet, so these tests use fixtures: they prove the screens are ready for
// it, not that real exams are ever finished. Nothing here works out "finished" from the browser clock.

const EXAMS = 'GET /api/exams';
const finishedExam = () => exam({ id: 'f1', title: 'Past midterm', status: 'Finished', phase: 'Closed' });

beforeEach(() => {
  chooseLanguage('en');
  tokenStore.setFromTokenResponse(tokenResponse({ role: 'Instructor' }));
});
afterEach(() => vi.unstubAllEnvs());

describe('Finished badge', () => {
  it('is labelled in English and in Arabic and styled as its own status', () => {
    const { container, unmount } = render(
      <LanguageProvider>
        <StatusBadge status="Finished" />
      </LanguageProvider>,
    );
    expect(screen.getByText(en['status.Finished'])).toHaveClass('badge-finished');
    unmount();

    chooseLanguage('ar');
    render(
      <LanguageProvider>
        <StatusBadge status="Finished" />
      </LanguageProvider>,
    );
    expect(screen.getByText(ar['status.Finished'])).toBeInTheDocument();
    expect(container).toBeDefined();
  });
});

describe('actions on a finished exam', () => {
  it('offers nothing that would publish, start, edit, cancel or delete it, and says why', () => {
    render(
      <MemoryRouter>
        <ExamActions exam={finishedExam()} onChanged={vi.fn()} onDeleted={vi.fn()} onStale={vi.fn()} />
      </MemoryRouter>,
    );
    for (const name of ['Publish', 'Unpublish', 'Cancel exam', 'Delete', 'Edit']) {
      expect(screen.queryByRole('button', { name })).not.toBeInTheDocument();
      expect(screen.queryByRole('link', { name })).not.toBeInTheDocument();
    }
    expect(screen.getByText(en['actions.finishedNote'])).toBeInTheDocument();
    expect(screen.queryByText(en['actions.startedNote'])).not.toBeInTheDocument();
  });
});

describe('Finished tab in Exam Management', () => {
  it('sits beside Draft, Published and Cancelled', async () => {
    mockApi({ [EXAMS]: [() => jsonResponse(200, { items: [], page: 1, pageSize: 10, totalCount: 0 })] });
    renderApp('/exams');
    for (const label of ['All', 'Draft', 'Published', 'Cancelled', 'Finished']) {
      expect(await screen.findByRole('button', { name: label })).toBeInTheDocument();
    }
  });

  it('while the backend has no Finished status, shows an honest empty tab and never asks the server for it', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({ [EXAMS]: [() => jsonResponse(200, { items: [], page: 1, pageSize: 10, totalCount: 0 })] });
    renderApp('/exams');
    await user.click(await screen.findByRole('button', { name: 'Finished' }));

    expect(await screen.findByText(en['list.finishedPending'])).toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => String(url).includes('status=Finished'))).toBe(false);
  });

  it('when the deployment says the backend supports it, asks for status=Finished and lists those exams apart, with the badge', async () => {
    vi.stubEnv('VITE_FINISHED_STATUS', 'true');
    const user = userEvent.setup();
    const fetchMock = mockApi({
      [EXAMS]: [
        (): Response => jsonResponse(200, { items: [], page: 1, pageSize: 10, totalCount: 0 }),
        (): Response => jsonResponse(200, { items: [finishedExam()], page: 1, pageSize: 10, totalCount: 1 }),
      ],
    });
    renderApp('/exams');
    await user.click(await screen.findByRole('button', { name: 'Finished' }));

    expect(await screen.findByText('Past midterm')).toBeInTheDocument();
    expect(screen.getByText('Finished', { selector: '.badge' })).toBeInTheDocument();
    expect(fetchMock.mock.calls.some(([url]) => String(url).includes('status=Finished'))).toBe(true);
  });
});
