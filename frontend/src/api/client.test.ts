import { describe, expect, it, vi } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { jsonResponse, problem, tokenResponse } from '../test/fixtures';
import { apiRequest } from './client';
import { ApiError, describeError } from './errors';

function mockFetch(...responses: Array<Response | Error>) {
  const fetchMock = vi.fn();
  responses.forEach((response) =>
    response instanceof Error ? fetchMock.mockRejectedValueOnce(response) : fetchMock.mockResolvedValueOnce(response),
  );
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

function authorizationOf(call: unknown[]): string | undefined {
  const init = call[1] as RequestInit;
  return (init.headers as Record<string, string>).Authorization;
}

async function caught(promise: Promise<unknown>): Promise<ApiError> {
  try {
    await promise;
  } catch (error) {
    if (error instanceof ApiError) return error;
    throw error;
  }
  throw new Error('Expected the request to fail.');
}

describe('apiRequest', () => {
  it('sends JSON with the bearer token and returns the parsed body', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    const fetchMock = mockFetch(jsonResponse(200, { items: [], page: 1, pageSize: 10, totalCount: 0 }));

    const result = await apiRequest('/api/exams?page=1&pageSize=10');

    expect(result).toEqual({ items: [], page: 1, pageSize: 10, totalCount: 0 });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(authorizationOf(fetchMock.mock.calls[0])).toBe('Bearer access-1');
  });

  it('returns undefined for 204 No Content', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockFetch(new Response(null, { status: 204 }));

    await expect(apiRequest('/api/exams/e1', { method: 'DELETE' })).resolves.toBeUndefined();
  });

  it('turns a 400 ProblemDetails into field errors', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockFetch(problem(400, 'validation_failed', 'One or more fields are invalid.', { 'options[1].text': ['Option text is required.'] }));

    const error = await caught(apiRequest('/api/exams/e1/questions', { method: 'POST', body: {} }));

    expect(error.status).toBe(400);
    expect(error.code).toBe('validation_failed');
    expect(error.fieldErrors['options[1].text']).toEqual(['Option text is required.']);
  });

  it('keeps the backend detail of a lifecycle conflict for display', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockFetch(problem(409, 'exam_not_publishable', 'The exam has no questions.'));

    const error = await caught(apiRequest('/api/exams/e1/publish', { method: 'POST' }));

    expect(error.code).toBe('exam_not_publishable');
    expect(describeError(error)).toBe('The exam has no questions.');
  });

  it('reports an unreachable server as a network error', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockFetch(new TypeError('Failed to fetch'));

    const error = await caught(apiRequest('/api/exams'));

    expect(error.kind).toBe('network');
    expect(describeError(error)).toMatch(/Cannot reach the server/);
  });

  it('never shows server error details to the user', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockFetch(problem(500, undefined, 'System.InvalidOperationException: internal detail'));

    const error = await caught(apiRequest('/api/exams'));

    expect(describeError(error)).toBe('The server had a problem. Please try again later.');
  });

  it('refreshes once after 401 token_invalid and retries with the new token', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    const fetchMock = mockFetch(
      problem(401, 'token_invalid', 'A valid access token is required.'),
      jsonResponse(200, tokenResponse({ accessToken: 'access-2' })),
      jsonResponse(200, { id: 'e1' }),
    );

    const result = await apiRequest('/api/exams/e1');

    expect(result).toEqual({ id: 'e1' });
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(fetchMock.mock.calls[1][0]).toBe('/api/auth/refresh');
    expect(authorizationOf(fetchMock.mock.calls[1])).toBeUndefined();
    expect(authorizationOf(fetchMock.mock.calls[2])).toBe('Bearer access-2');
  });

  it('signs out when the refresh token is rejected', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockFetch(
      problem(401, 'token_invalid', 'A valid access token is required.'),
      problem(401, 'refresh_token_reused', 'The refresh token was already used.'),
    );

    const error = await caught(apiRequest('/api/exams'));

    expect(error.status).toBe(401);
    expect(tokenStore.getSession()).toBeNull();
    expect(tokenStore.getRefreshToken()).toBeNull();
  });

  it('does not try to refresh after a login failure', async () => {
    const fetchMock = mockFetch(problem(401, 'invalid_credentials', 'The email or password is incorrect.'));

    const error = await caught(apiRequest('/api/auth/login', { method: 'POST', body: {}, auth: false }));

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(describeError(error)).toBe('The email or password is incorrect.');
  });
});

describe('refresh failures', () => {
  async function expiredSessionThenRefreshFails(refreshFailure: Response | Error) {
    tokenStore.setFromTokenResponse(tokenResponse());
    mockFetch(problem(401, 'token_invalid', 'A valid access token is required.'), refreshFailure);
    return caught(apiRequest('/api/exams'));
  }

  it('keeps the session when the refresh is rate limited (429)', async () => {
    const error = await expiredSessionThenRefreshFails(problem(429, undefined, ''));

    expect(error.status).toBe(429);
    expect(describeError(error)).toMatch(/Too many attempts/);
    expect(tokenStore.getSession()).not.toBeNull();
    expect(tokenStore.getRefreshToken()).toBe('refresh-1');
  });

  it('keeps the session when the refresh gets a server error (500) and shows no server detail', async () => {
    const error = await expiredSessionThenRefreshFails(problem(500, undefined, 'internal exception text'));

    expect(error.status).toBe(500);
    expect(describeError(error)).toBe('The server had a problem. Please try again later.');
    expect(tokenStore.getSession()).not.toBeNull();
    expect(tokenStore.getRefreshToken()).toBe('refresh-1');
  });

  it('keeps the session when the server cannot be reached during the refresh', async () => {
    const error = await expiredSessionThenRefreshFails(new TypeError('Failed to fetch'));

    expect(error.kind).toBe('network');
    expect(tokenStore.getRefreshToken()).toBe('refresh-1');
  });

  it.each([
    [401, 'token_invalid'],
    [401, 'refresh_token_reused'],
    [403, 'account_deactivated'],
    [403, 'temporary_password_expired'],
  ])('signs out when the refresh answers %i %s', async (status, code) => {
    await expiredSessionThenRefreshFails(problem(status, code, 'rejected'));

    expect(tokenStore.getSession()).toBeNull();
    expect(tokenStore.getRefreshToken()).toBeNull();
  });

  it('runs only one refresh for parallel requests (single-flight)', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    const fetchMock = vi.fn((url: string, init: RequestInit) => {
      if (url === '/api/auth/refresh') return Promise.resolve(jsonResponse(200, tokenResponse({ accessToken: 'access-2' })));
      const bearer = (init.headers as Record<string, string>).Authorization;
      return Promise.resolve(
        bearer === 'Bearer access-2' ? jsonResponse(200, { ok: true }) : problem(401, 'token_invalid', 'expired'),
      );
    });
    vi.stubGlobal('fetch', fetchMock);

    await Promise.all([apiRequest('/api/exams'), apiRequest('/api/exams/e1')]);

    expect(fetchMock.mock.calls.filter(([url]) => url === '/api/auth/refresh')).toHaveLength(1);
  });
});

describe('pre-emptive refresh failing temporarily', () => {
  // A token that is still valid for 10 seconds (inside the 30-second refresh margin) or already expired.
  function signInWithTokenExpiringIn(milliseconds: number) {
    tokenStore.setFromTokenResponse({
      ...tokenResponse(),
      accessTokenExpiresAt: new Date(Date.now() + milliseconds).toISOString(),
    });
  }

  it.each([
    ['429', problem(429, undefined, '')],
    ['500', problem(500, undefined, 'internal exception text')],
    ['a network error', new TypeError('Failed to fetch')],
  ])('sends the request with the still-valid token when the refresh fails with %s', async (_name, failure) => {
    signInWithTokenExpiringIn(10_000);
    const fetchMock = mockFetch(failure, jsonResponse(200, { id: 'e1' }));

    const result = await apiRequest('/api/exams/e1');

    expect(result).toEqual({ id: 'e1' });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(fetchMock.mock.calls[0][0]).toBe('/api/auth/refresh');
    expect(fetchMock.mock.calls[1][0]).toBe('/api/exams/e1');
    expect(authorizationOf(fetchMock.mock.calls[1])).toBe('Bearer access-1');
    expect(tokenStore.getSession()).not.toBeNull();
    expect(tokenStore.getRefreshToken()).toBe('refresh-1');
  });

  it.each([
    ['429', problem(429, undefined, '')],
    ['500', problem(500, undefined, 'internal exception text')],
    ['a network error', new TypeError('Failed to fetch')],
  ])('never sends an expired token: the refresh failure (%s) is reported and the session is kept', async (_name, failure) => {
    signInWithTokenExpiringIn(-1_000);
    const fetchMock = mockFetch(failure);

    const error = await caught(apiRequest('/api/exams/e1'));

    expect(fetchMock).toHaveBeenCalledTimes(1); // only the refresh; the original request was not sent
    expect(fetchMock.mock.calls[0][0]).toBe('/api/auth/refresh');
    expect(error.kind === 'network' || error.status === 429 || error.status === 500).toBe(true);
    expect(tokenStore.getSession()).not.toBeNull();
    expect(tokenStore.getRefreshToken()).toBe('refresh-1');
  });

  it('retries only once: a 401 after a failed refresh is followed by one more refresh attempt, then an error', async () => {
    signInWithTokenExpiringIn(10_000);
    const fetchMock = mockFetch(
      problem(500, undefined, 'x'), // pre-emptive refresh fails temporarily
      problem(401, 'token_invalid', 'A valid access token is required.'), // the server rejects the token anyway
      problem(500, undefined, 'x'), // the refresh after the 401 fails again
    );

    const error = await caught(apiRequest('/api/exams/e1'));

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(error.status).toBe(500);
    expect(tokenStore.getRefreshToken()).toBe('refresh-1');
  });

  it('still signs out when the server rejects the refresh token during the pre-emptive refresh', async () => {
    signInWithTokenExpiringIn(10_000);
    mockFetch(problem(401, 'token_invalid', 'The refresh token is invalid or has expired.'), problem(401, 'token_invalid', 'x'));

    await caught(apiRequest('/api/exams/e1'));

    expect(tokenStore.getSession()).toBeNull();
    expect(tokenStore.getRefreshToken()).toBeNull();
  });
});

describe('change-password errors', () => {
  it('403 account_locked is an error message and does not refresh or sign out', async () => {
    tokenStore.setFromTokenResponse(tokenResponse());
    const detail = 'This account is temporarily locked after too many failed attempts. Try again later.';
    const fetchMock = mockFetch(problem(403, 'account_locked', detail));

    const error = await caught(
      apiRequest('/api/auth/change-password', { method: 'POST', body: { currentPassword: 'x', newPassword: 'y' } }),
    );

    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(describeError(error)).toBe(detail);
    expect(tokenStore.getSession()).not.toBeNull();
    expect(tokenStore.getRefreshToken()).toBe('refresh-1');
  });
});
