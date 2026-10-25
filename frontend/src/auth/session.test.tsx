import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { en } from '../i18n/en';
import { ar } from '../i18n/ar';
import { jsonResponse, problem, tokenResponse } from '../test/fixtures';
import { callsTo, chooseLanguage, mockApi, renderApp } from '../test/helpers';
import { tokenStore } from './tokenStore';

const REFRESH = 'POST /api/auth/refresh';
const EXAMS = 'GET /api/exams';
const emptyList = () => jsonResponse(200, { items: [], page: 1, pageSize: 10, totalCount: 0 });

// A browser that was reloaded: only the refresh token is left (sessionStorage), the access token is gone.
function reloadedTab() {
  window.sessionStorage.setItem('examProctoring.refreshToken', 'refresh-1');
}

describe('session restoration', () => {
  it('restores the session from the stored refresh token', async () => {
    chooseLanguage('en');
    reloadedTab();
    mockApi({ [REFRESH]: [() => jsonResponse(200, tokenResponse({ accessToken: 'access-2' }))], [EXAMS]: [emptyList] });
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: en['list.title'] })).toBeInTheDocument();
  });

  it.each([
    ['a server error (500)', () => problem(500, undefined, 'internal exception text')],
    ['the rate limit (429)', () => problem(429, undefined, '')],
    [
      'a network error',
      () => {
        throw new TypeError('Failed to fetch');
      },
    ],
  ])('keeps the stored session and offers a retry when the restore fails with %s', async (_name, failure) => {
    chooseLanguage('en');
    reloadedTab();
    const fetchMock = mockApi({ [REFRESH]: [failure, () => jsonResponse(200, tokenResponse({ accessToken: 'access-2' }))], [EXAMS]: [emptyList] });
    const user = userEvent.setup();
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: en['session.unavailableTitle'] })).toBeInTheDocument();
    expect(window.sessionStorage.getItem('examProctoring.refreshToken')).toBe('refresh-1'); // not discarded
    expect(screen.queryByText(en['login.sessionEnded'])).not.toBeInTheDocument();
    expect(screen.queryByText(/internal exception text/)).not.toBeInTheDocument();

    await user.click(screen.getByRole('button', { name: en['common.tryAgain'] }));

    expect(await screen.findByRole('heading', { name: en['list.title'] })).toBeInTheDocument();
    expect(callsTo(fetchMock, REFRESH)).toHaveLength(2); // one retry, no loop
  });

  it('lets the user sign out from the unavailable screen', async () => {
    chooseLanguage('en');
    reloadedTab();
    mockApi({ [REFRESH]: [() => problem(500, undefined, 'x')] });
    const user = userEvent.setup();
    renderApp('/exams');
    await screen.findByRole('heading', { name: en['session.unavailableTitle'] });

    await user.click(screen.getByRole('button', { name: en['common.signOut'] }));

    expect(await screen.findByRole('heading', { name: en['login.title'] })).toBeInTheDocument();
    expect(window.sessionStorage.getItem('examProctoring.refreshToken')).toBeNull();
  });

  it('shows the session-ended message on the sign-in page when the server rejects the refresh token', async () => {
    chooseLanguage('en');
    reloadedTab();
    mockApi({ [REFRESH]: [() => problem(401, 'refresh_token_reused', 'The refresh token was already used.')] });
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: en['login.title'] })).toBeInTheDocument();
    expect(screen.getByText(en['login.sessionEnded'])).toBeInTheDocument();
    expect(window.sessionStorage.getItem('examProctoring.refreshToken')).toBeNull();
  });

  it('the session-ended message follows the language and can be dismissed', async () => {
    reloadedTab();
    mockApi({ [REFRESH]: [() => problem(401, 'token_invalid', 'The refresh token is invalid or has expired.')] });
    const user = userEvent.setup();
    renderApp('/exams');

    expect(await screen.findByText(ar['login.sessionEnded'])).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: ar['common.dismiss'] }));
    expect(screen.queryByText(ar['login.sessionEnded'])).not.toBeInTheDocument();
  });

  it('does not show the session-ended message to a visitor who never had a session', async () => {
    chooseLanguage('en');
    mockApi({});
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: en['login.title'] })).toBeInTheDocument();
    expect(screen.queryByText(en['login.sessionEnded'])).not.toBeInTheDocument();
  });

  it('a user who signs out themselves does not see the session-ended message', async () => {
    chooseLanguage('en');
    tokenStore.setFromTokenResponse(tokenResponse());
    mockApi({ [EXAMS]: [emptyList], 'POST /api/auth/logout': [() => new Response(null, { status: 204 })] });
    const user = userEvent.setup();
    renderApp('/exams');
    await screen.findByRole('heading', { name: en['list.title'] });

    await user.click(screen.getByRole('button', { name: en['common.signOut'] }));

    expect(await screen.findByRole('heading', { name: en['login.title'] })).toBeInTheDocument();
    expect(screen.queryByText(en['login.sessionEnded'])).not.toBeInTheDocument();
  });
});

describe('access denied for other roles', () => {
  it('tells a Student that student exam features are not available yet', async () => {
    chooseLanguage('en');
    tokenStore.setFromTokenResponse(tokenResponse({ role: 'Student' }));
    mockApi({});
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: en['access.title'] })).toBeInTheDocument();
    expect(screen.getByText(en['access.studentNote'])).toBeInTheDocument();
    expect(screen.getByRole('button', { name: en['common.signOut'] })).toBeInTheDocument();
  });

  it('shows an Admin the access-denied screen without the student note, in Arabic by default', async () => {
    tokenStore.setFromTokenResponse(tokenResponse({ role: 'Admin' }));
    mockApi({});
    renderApp('/exams');

    expect(await screen.findByRole('heading', { name: ar['access.title'] })).toBeInTheDocument();
    expect(screen.queryByText(ar['access.studentNote'])).not.toBeInTheDocument();
  });

  it('sends a signed-in student who opens /register to the app instead of the form', async () => {
    chooseLanguage('en');
    tokenStore.setFromTokenResponse(tokenResponse({ role: 'Student' }));
    mockApi({});
    renderApp('/register');

    await waitFor(() => expect(screen.getByRole('heading', { name: en['access.title'] })).toBeInTheDocument());
  });
});
