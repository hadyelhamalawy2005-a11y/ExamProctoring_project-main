import { screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import { ar } from '../i18n/ar';
import { en } from '../i18n/en';
import { jsonResponse, problem, tokenResponse } from '../test/fixtures';
import { callsTo, chooseLanguage, mockApi, renderApp } from '../test/helpers';

const LOGIN = 'POST /api/auth/login';

beforeEach(() => chooseLanguage('en'));

describe('the sign-in page design', () => {
  it('shows the brand, the heading, the administrator-account subtitle and the supporting note', async () => {
    mockApi({});
    renderApp('/login');
    expect(await screen.findByRole('img', { name: 'Examora' })).toBeInTheDocument();
    expect(screen.getByText(en['brand.line1'])).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: 'Sign in' })).toBeInTheDocument();
    expect(screen.getByText('Sign in with the account your administrator gave you.')).toBeInTheDocument();
    expect(screen.getByText('Accounts are created by your administrator.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Sign in' })).toBeInTheDocument();
  });

  it('keeps student registration and links to the forgot-password screen', async () => {
    mockApi({});
    renderApp('/login');
    expect(await screen.findByRole('link', { name: en['login.createAccount'] })).toHaveAttribute('href', '/register');
    expect(screen.getByRole('link', { name: en['login.forgot'] })).toHaveAttribute('href', '/forgot-password');
  });

  it('the forgot-password screen says there is no automatic reset and returns to sign-in', async () => {
    const user = userEvent.setup();
    mockApi({});
    renderApp('/forgot-password');
    expect(await screen.findByText(/no automatic password reset/i)).toBeInTheDocument();
    await user.click(screen.getByRole('link', { name: en['forgot.back'] }));
    expect(await screen.findByRole('heading', { name: en['login.title'] })).toBeInTheDocument();
  });

  it('the password can be shown and hidden, and starts hidden', async () => {
    const user = userEvent.setup();
    mockApi({});
    renderApp('/login');
    const password = await screen.findByLabelText(en['login.password'], { selector: 'input' });
    expect(password).toHaveAttribute('type', 'password');
    await user.type(password, 'Secret1234');

    await user.click(screen.getByRole('button', { name: en['login.showPassword'] }));
    expect(password).toHaveAttribute('type', 'text');
    expect(password).toHaveValue('Secret1234');

    await user.click(screen.getByRole('button', { name: en['login.hidePassword'] }));
    expect(password).toHaveAttribute('type', 'password');
  });

  it('refuses to send an empty form and marks both fields', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({});
    renderApp('/login');
    await user.click(await screen.findByRole('button', { name: en['login.submit'] }));
    expect(screen.getByText(en['val.emailRequired'])).toBeInTheDocument();
    expect(screen.getByText(en['val.passwordRequired'])).toBeInTheDocument();
    expect(screen.getByLabelText(en['login.email'])).toHaveAttribute('aria-invalid', 'true');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('signs in through the real endpoint with the typed email and password', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({
      [LOGIN]: [() => jsonResponse(200, tokenResponse({ role: 'Student' }))],
    });
    renderApp('/login');
    await user.type(await screen.findByLabelText(en['login.email']), ' student@example.test ');
    await user.type(screen.getByLabelText(en['login.password'], { selector: 'input' }), 'Passw0rd!x');
    await user.click(screen.getByRole('button', { name: en['login.submit'] }));
    expect(await screen.findByText(en['student.body'])).toBeInTheDocument();
    const body = JSON.parse((callsTo(fetchMock, LOGIN)[0][1] as RequestInit).body as string) as Record<string, string>;
    expect(body).toEqual({ email: 'student@example.test', password: 'Passw0rd!x' });
  });

  it('shows the backend’s error for a wrong password and keeps the page usable', async () => {
    const user = userEvent.setup();
    mockApi({ [LOGIN]: [() => problem(401, 'invalid_credentials', 'The email or password is incorrect.')] });
    renderApp('/login');
    await user.type(await screen.findByLabelText(en['login.email']), 'a@example.test');
    await user.type(screen.getByLabelText(en['login.password'], { selector: 'input' }), 'wrong');
    await user.click(screen.getByRole('button', { name: en['login.submit'] }));
    expect(await screen.findByRole('alert')).toHaveTextContent('The email or password is incorrect.');
    expect(screen.getByRole('button', { name: en['login.submit'] })).toBeEnabled();
  });

  it('in Arabic: right to left, Arabic texts, the brand name unchanged', async () => {
    chooseLanguage('ar');
    mockApi({});
    renderApp('/login');
    expect(await screen.findByRole('heading', { name: ar['login.title'] })).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute('dir', 'rtl');
    expect(screen.getByText(ar['login.subtitle'])).toBeInTheDocument();
    expect(screen.getByText(ar['login.accountsByAdmin'])).toBeInTheDocument();
    expect(screen.getByRole('img', { name: 'Examora' })).toBeInTheDocument();
    expect(screen.getByText(ar['brand.line1'])).toBeInTheDocument();
    // Email and password are typed left to right, even on a right-to-left page.
    expect(screen.getByLabelText(ar['login.email'])).toHaveAttribute('dir', 'ltr');
  });
});
