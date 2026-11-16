import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import { en } from '../i18n/en';
import { ar } from '../i18n/ar';
import { jsonResponse, problem, tokenResponse } from '../test/fixtures';
import { chooseLanguage, mockApi, renderApp } from '../test/helpers';
import type { Role } from '../types/api';
import { homeFor, landingFor, roleForPath } from './roles';
import { tokenStore } from './tokenStore';

const EXAMS = 'GET /api/exams';
const ACCOUNTS = 'GET /api/admin/accounts';
const emptyExams = () => jsonResponse(200, { items: [], page: 1, pageSize: 10, totalCount: 0 });
const emptyAccounts = () => jsonResponse(200, { items: [], page: 1, pageSize: 20, totalCount: 0 });

const signIn = (role: Role, mustChangePassword = false) => tokenStore.setFromTokenResponse(tokenResponse({ role, mustChangePassword }));

beforeEach(() => chooseLanguage('en'));

describe('role helpers', () => {
  it('maps paths to the role that owns them', () => {
    expect(roleForPath('/admin')).toBe('Admin');
    expect(roleForPath('/admin/accounts/abc?x=1')).toBe('Admin');
    expect(roleForPath('/student')).toBe('Student');
    expect(roleForPath('/exams/e1/edit')).toBe('Instructor');
    expect(roleForPath('/import?examId=e1')).toBe('Instructor');
    expect(roleForPath('/instructor/anything')).toBe('Instructor');
    expect(roleForPath('/administrator')).toBeNull(); // a prefix is not a match
    expect(roleForPath('/login')).toBeNull();
  });

  it('follows a remembered address only when it belongs to the role', () => {
    expect(landingFor('Instructor', '/exams/e1')).toBe('/exams/e1');
    expect(landingFor('Instructor', '/admin/accounts')).toBe(homeFor('Instructor'));
    expect(landingFor('Admin', '/exams')).toBe('/admin/accounts');
    expect(landingFor('Student', undefined)).toBe('/student');
    expect(landingFor('Instructor', '//evil.example/exams')).toBe('/instructor'); // never an external address
  });
});

describe('after sign-in each role lands on its own dashboard', () => {
  async function signInThroughForm(role: Role) {
    const user = userEvent.setup();
    mockApi({
      'POST /api/auth/login': [() => jsonResponse(200, tokenResponse({ role }))],
      [EXAMS]: [emptyExams],
      [ACCOUNTS]: [emptyAccounts],
    });
    renderApp('/login');
    await user.type(await screen.findByLabelText(en['login.email']), 'someone@example.test');
    await user.type(screen.getByLabelText(en['login.password']), 'Passw0rd!x');
    await user.click(screen.getByRole('button', { name: en['login.submit'] }));
  }

  it('Admin -> the accounts list', async () => {
    await signInThroughForm('Admin');
    expect(await screen.findByRole('heading', { name: en['admin.list.title'] })).toBeInTheDocument();
  });

  it('Instructor -> the home screen, with the real exam counts', async () => {
    await signInThroughForm('Instructor');
    expect(await screen.findByRole('heading', { name: 'Welcome, Test Instructor' })).toBeInTheDocument();
    expect(await screen.findByTestId('count-Draft')).toHaveTextContent('Draft: 0');
  });

  it('Student -> the student dashboard, which says exams are not available yet', async () => {
    await signInThroughForm('Student');
    expect(await screen.findByText(en['student.body'])).toBeInTheDocument();
    expect(screen.getByText(en['student.body'])).toBeInTheDocument();
  });

  it('a remembered address from another role is dropped', async () => {
    const user = userEvent.setup();
    mockApi({ 'POST /api/auth/login': [() => jsonResponse(200, tokenResponse({ role: 'Student' }))] });
    renderApp('/admin/accounts'); // signed out: sent to sign-in, remembering /admin/accounts
    await user.type(await screen.findByLabelText(en['login.email']), 'student@example.test');
    await user.type(screen.getByLabelText(en['login.password']), 'Passw0rd!x');
    await user.click(screen.getByRole('button', { name: en['login.submit'] }));
    expect(await screen.findByText(en['student.body'])).toBeInTheDocument();
  });
});

describe('a user cannot open another role’s area', () => {
  const cases: Array<[Role, string, string]> = [
    ['Instructor', '/admin/accounts', en['access.adminTitle']],
    ['Instructor', '/student', en['access.studentTitle']],
    ['Student', '/admin/accounts', en['access.adminTitle']],
    ['Student', '/exams', en['access.title']],
    ['Admin', '/exams', en['access.title']],
    ['Admin', '/student', en['access.studentTitle']],
  ];
  it.each(cases)('%s opening %s sees the access screen with a way to their own dashboard', async (role, path, title) => {
    signIn(role);
    mockApi({});
    renderApp(path);
    expect(await screen.findByRole('heading', { name: title })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: en['access.goHome'] })).toHaveAttribute('href', homeFor(role));
  });

  it('makes no request for another role’s data', async () => {
    signIn('Instructor');
    const fetchMock = mockApi({});
    renderApp('/admin/accounts');
    await screen.findByRole('heading', { name: en['access.adminTitle'] });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('a role written into browser storage grants nothing', async () => {
    signIn('Instructor');
    window.localStorage.setItem('role', 'Admin');
    window.localStorage.setItem('user', JSON.stringify({ role: 'Admin' }));
    window.sessionStorage.setItem('role', 'Admin');
    mockApi({});
    renderApp('/admin/accounts');
    expect(await screen.findByRole('heading', { name: en['access.adminTitle'] })).toBeInTheDocument();
  });

  it('the access-denied screen is translated, in Arabic', async () => {
    chooseLanguage('ar');
    signIn('Student');
    mockApi({});
    renderApp('/admin/accounts');
    expect(await screen.findByRole('heading', { name: ar['access.adminTitle'] })).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute('dir', 'rtl');
  });
});

describe('sessions', () => {
  it('a visitor without a session is sent to sign-in from every area', async () => {
    for (const path of ['/admin/accounts', '/student', '/exams']) {
      mockApi({});
      const { unmount } = renderApp(path);
      expect(await screen.findByRole('heading', { name: en['login.title'] })).toBeInTheDocument();
      unmount();
    }
  });

  it('a pending password change comes before any dashboard', async () => {
    for (const role of ['Admin', 'Instructor', 'Student'] as const) {
      tokenStore.clear();
      signIn(role, true);
      mockApi({});
      const { unmount } = renderApp(homeFor(role));
      expect(await screen.findByRole('heading', { name: en['cp.titleRequired'] })).toBeInTheDocument();
      unmount();
    }
  });

  it('after the forced password change, an admin goes to the admin area (not to /exams)', async () => {
    const user = userEvent.setup();
    signIn('Admin', true);
    mockApi({
      'POST /api/auth/change-password': [() => jsonResponse(200, tokenResponse({ role: 'Admin' }))],
      [ACCOUNTS]: [emptyAccounts],
    });
    renderApp('/change-password');
    await user.type(await screen.findByLabelText(en['cp.current']), 'Temp0rary!pw');
    await user.type(screen.getByLabelText(en['cp.new'], { exact: true }), 'Br4nd!NewPassw0rd');
    await user.type(screen.getByLabelText(en['cp.repeat']), 'Br4nd!NewPassw0rd');
    await user.click(screen.getByRole('button', { name: en['cp.submit'] }));
    expect(await screen.findByRole('heading', { name: en['admin.list.title'] })).toBeInTheDocument();
  });

  it('a refresh token the server rejects ends the session and returns to sign-in', async () => {
    window.sessionStorage.setItem('examProctoring.refreshToken', 'stale');
    mockApi({ 'POST /api/auth/refresh': [() => problem(401, 'token_invalid', 'The refresh token is invalid or has expired.')] });
    renderApp('/admin/accounts');
    expect(await screen.findByRole('heading', { name: en['login.title'] })).toBeInTheDocument();
  });

  it('a 403 from the server on an admin call is shown as an error, not as an empty list', async () => {
    signIn('Admin');
    mockApi({ [ACCOUNTS]: [() => problem(403, undefined, 'Forbidden')] });
    renderApp('/admin/accounts');
    await waitFor(() => expect(screen.getByRole('alert')).toBeInTheDocument());
    expect(screen.queryByText(en['admin.list.emptyNone'])).not.toBeInTheDocument();
  });

  it('"/" sends each role home', async () => {
    signIn('Admin');
    mockApi({ [ACCOUNTS]: [emptyAccounts] });
    renderApp('/');
    expect(await screen.findByRole('heading', { name: en['admin.list.title'] })).toBeInTheDocument();
  });
});
