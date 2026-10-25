import { describe, expect, it, vi } from 'vitest';
import { jsonResponse, problem } from '../test/fixtures';
import { register } from './auth';
import { ApiError } from './errors';

const form = { fullName: 'Sara Ahmed', email: 'sara@example.edu', password: 'Example1pass', confirmPassword: 'Example1pass' };

describe('register', () => {
  it('posts exactly the four contract fields, anonymously, and returns the account without tokens', async () => {
    const created = { id: 'u9', fullName: 'Sara Ahmed', email: 'sara@example.edu', role: 'Student' };
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse(201, created));
    vi.stubGlobal('fetch', fetchMock);

    // An extra property (for example from a wider form object) must never reach the backend.
    const result = await register({ ...form, role: 'Admin', universityId: '1' } as typeof form);

    expect(result).toEqual(created);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe('/api/auth/register');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toEqual(form);
    expect(Object.keys(JSON.parse(init.body as string)).sort()).toEqual(['confirmPassword', 'email', 'fullName', 'password']);
    expect((init.headers as Record<string, string>).Authorization).toBeUndefined();
  });

  it('does not store any session after a successful sign-up', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(jsonResponse(201, { id: 'u9', fullName: 'S', email: 'a@b.cd', role: 'Student' })),
    );

    await register(form);

    expect(window.sessionStorage.length).toBe(0);
  });

  it('exposes 400 field errors for email, password and confirmPassword', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        problem(400, 'validation_failed', 'One or more fields are invalid.', {
          email: ['Email is not a valid email address.'],
          password: ['Passwords must have at least one digit.', 'Passwords must have at least one uppercase letter.'],
          confirmPassword: ['Passwords do not match.'],
        }),
      ),
    );

    const error = await register(form).catch((e: unknown) => e);

    expect(error).toBeInstanceOf(ApiError);
    const apiError = error as ApiError;
    expect(apiError.status).toBe(400);
    expect(apiError.fieldErrors.email).toEqual(['Email is not a valid email address.']);
    expect(apiError.fieldErrors.password).toHaveLength(2);
    expect(apiError.fieldErrors.confirmPassword).toEqual(['Passwords do not match.']);
  });

  it('exposes 409 duplicate_account and 429', async () => {
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValueOnce(problem(409, 'duplicate_account', 'An account with this email already exists.'))
        .mockResolvedValueOnce(problem(429, undefined, '')),
    );

    const duplicate = (await register(form).catch((e: unknown) => e)) as ApiError;
    const limited = (await register(form).catch((e: unknown) => e)) as ApiError;

    expect(duplicate.status).toBe(409);
    expect(duplicate.code).toBe('duplicate_account');
    expect(limited.status).toBe(429);
  });
});
