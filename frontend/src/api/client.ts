import { tokenStore } from '../auth/tokenStore';
import type { ProblemDetails, TokenResponse } from '../types/api';
import { ApiError, isTemporaryFailure } from './errors';

// Empty base URL = same origin (the Vite dev server proxies /api to the backend). See .env.example.
const BASE_URL = (import.meta.env.VITE_API_BASE_URL ?? '').replace(/\/+$/, '');

// Refresh a little before the access token expires instead of waiting for a 401.
const REFRESH_MARGIN_MS = 30_000;

export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE';

export interface RequestOptions {
  method?: HttpMethod;
  body?: unknown;
  signal?: AbortSignal;
  // false for the anonymous endpoints (login, refresh).
  auth?: boolean;
}

// Every API call goes through here: JSON in and out, the bearer token, ProblemDetails errors, and one transparent
// token refresh when the access token has expired.
export async function apiRequest<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const useAuth = options.auth ?? true;

  if (useAuth) {
    const session = tokenStore.getSession();
    if (session && session.accessTokenExpiresAt - Date.now() < REFRESH_MARGIN_MS) {
      try {
        await refreshSession();
      } catch (error) {
        // The refresh failed temporarily (no answer, 429 or 5xx); the session is kept. The request may still go ahead
        // with the current access token, but only while that token has not expired. An expired token is never sent.
        const current = tokenStore.getSession();
        if (!current || current.accessTokenExpiresAt <= Date.now()) throw error;
      }
    }
  }

  try {
    return await send<T>(path, options);
  } catch (error) {
    const expired =
      useAuth &&
      error instanceof ApiError &&
      error.status === 401 &&
      (!error.code || error.code === 'token_invalid') &&
      tokenStore.getRefreshToken() !== null;
    if (expired && (await refreshSession())) {
      return send<T>(path, options);
    }
    throw error;
  }
}

let refreshInFlight: Promise<boolean> | null = null;

// Exchanges the stored refresh token for a new token pair. Only one refresh runs at a time: the backend rotates
// refresh tokens, and presenting an already-used one is treated as reuse and ends the session.
// Resolves false (and signs out) when the refresh token is rejected; throws on network errors.
export function refreshSession(): Promise<boolean> {
  if (!refreshInFlight) {
    refreshInFlight = runRefresh().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

async function runRefresh(): Promise<boolean> {
  const refreshToken = tokenStore.getRefreshToken();
  if (!refreshToken) {
    tokenStore.clear();
    return false;
  }

  try {
    const tokens = await send<TokenResponse>('/api/auth/refresh', {
      method: 'POST',
      body: { refreshToken },
      auth: false,
    });
    tokenStore.setFromTokenResponse(tokens);
    return true;
  } catch (error) {
    if (isTemporaryFailure(error)) {
      throw error; // the server could not answer right now; keep the session and let the caller report it
    }
    // The server answered and rejected the refresh token (401 token_invalid / refresh_token_reused, 403 for a
    // deactivated account or expired temporary password, or an unusable token): the session is over. The sign-in page
    // then says so. Temporary failures (above) never get here, and a user's own sign-out does not set this reason.
    tokenStore.clear('sessionEnded');
    return false;
  }
}

async function send<T>(path: string, options: RequestOptions): Promise<T> {
  const { method = 'GET', body, signal, auth = true } = options;

  const headers: Record<string, string> = { Accept: 'application/json' };
  // A FormData (file upload) is sent as it is: the browser sets "multipart/form-data" with the right boundary itself, so
  // Content-Type must not be set here. Everything else is JSON.
  const isForm = body instanceof FormData;
  if (body !== undefined && !isForm) headers['Content-Type'] = 'application/json';
  const accessToken = auth ? tokenStore.getSession()?.accessToken : undefined;
  if (accessToken) headers.Authorization = `Bearer ${accessToken}`;

  let response: Response;
  try {
    response = await fetch(`${BASE_URL}${path}`, {
      method,
      headers,
      body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
      signal,
    });
  } catch {
    throw new ApiError(signal?.aborted ? 'aborted' : 'network', 0);
  }

  if (response.status === 204) return undefined as T;

  let payload: unknown;
  try {
    const text = await response.text();
    payload = text ? JSON.parse(text) : undefined;
  } catch {
    if (signal?.aborted) throw new ApiError('aborted', 0);
    payload = undefined; // not JSON (for example an HTML error page from a proxy)
  }

  if (!response.ok) {
    const problem = typeof payload === 'object' && payload !== null ? (payload as ProblemDetails) : {};
    throw new ApiError('http', response.status, problem);
  }

  return payload as T;
}
