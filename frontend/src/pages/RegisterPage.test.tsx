import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { ar } from '../i18n/ar';
import { en } from '../i18n/en';
import { jsonResponse, problem } from '../test/fixtures';
import { callsTo, chooseLanguage, mockApi, renderApp } from '../test/helpers';

const REGISTER = 'POST /api/auth/register';

async function fillForm(overrides: Partial<Record<'name' | 'email' | 'password' | 'confirm', string>> = {}) {
  const user = userEvent.setup();
  const values = { name: 'Sara Ahmed', email: 'sara@example.edu', password: 'Example1pass', confirm: 'Example1pass', ...overrides };
  if (values.name) await user.type(screen.getByLabelText(en['reg.fullName']), values.name);
  if (values.email) await user.type(screen.getByLabelText(en['reg.email']), values.email);
  if (values.password) await user.type(screen.getByLabelText(en['reg.password']), values.password);
  if (values.confirm) await user.type(screen.getByLabelText(en['reg.confirmPassword']), values.confirm);
  return user;
}

const submit = (user: ReturnType<typeof userEvent.setup>) => user.click(screen.getByRole('button', { name: en['reg.submit'] }));

describe('RegisterPage (English)', () => {
  it('creates the account, shows the success panel with a sign-in link, clears the form and does not sign in', async () => {
    chooseLanguage('en');
    const fetchMock = mockApi({
      [REGISTER]: [() => jsonResponse(201, { id: 'u9', fullName: 'Sara Ahmed', email: 'sara@example.edu', role: 'Student' })],
    });
    renderApp('/register');
    const user = await fillForm();

    await submit(user);

    expect(await screen.findByText(en['reg.successBody'])).toBeInTheDocument();
    expect(screen.getByRole('link', { name: en['reg.successSignIn'] })).toHaveAttribute('href', '/login');
    expect(screen.queryByLabelText(en['reg.password'])).not.toBeInTheDocument(); // the form (and both passwords) is gone
    expect(tokenStore.getSession()).toBeNull();
    expect(window.sessionStorage.length).toBe(0);
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('sends exactly fullName, email, password and confirmPassword (no role, no university)', async () => {
    chooseLanguage('en');
    const fetchMock = mockApi({ [REGISTER]: [() => jsonResponse(201, { id: 'u9', fullName: 'S', email: 'a@b.cd', role: 'Student' })] });
    renderApp('/register');
    const user = await fillForm({ name: '  Sara Ahmed  ' });

    await submit(user);
    await screen.findByText(en['reg.successBody']);

    const [url, init] = callsTo(fetchMock, REGISTER)[0] as [string, RequestInit];
    expect(url).toBe('/api/auth/register');
    expect(JSON.parse(init.body as string)).toEqual({
      fullName: 'Sara Ahmed',
      email: 'sara@example.edu',
      password: 'Example1pass',
      confirmPassword: 'Example1pass',
    });
    expect(Object.keys(JSON.parse(init.body as string))).toHaveLength(4);
    expect(screen.queryByText(/universit/i)).not.toBeInTheDocument();
  });

  it('blocks empty fields, a 151-character name, a bad email, a weak password and mismatched passwords before calling the API', async () => {
    chooseLanguage('en');
    const fetchMock = mockApi({});
    renderApp('/register');
    const user = userEvent.setup();

    await submit(user);
    expect(screen.getByText(en['val.fullNameRequired'])).toBeInTheDocument();
    expect(screen.getByText(en['val.emailRequired'])).toBeInTheDocument();
    expect(screen.getByText(en['val.passwordRequired'])).toBeInTheDocument();
    // Focus moves to the first invalid field, which is marked and linked to its message.
    await waitFor(() => expect(screen.getByLabelText(en['reg.fullName'])).toHaveFocus());
    expect(screen.getByLabelText(en['reg.fullName'])).toHaveAttribute('aria-invalid', 'true');
    expect(screen.getByLabelText(en['reg.fullName'])).toHaveAccessibleDescription(en['val.fullNameRequired']);

    await user.click(screen.getByLabelText(en['reg.fullName']));
    await user.paste('x'.repeat(151)); // pasted: typing 151 keys one by one is needlessly slow
    await user.type(screen.getByLabelText(en['reg.email']), 'not-an-email');
    await user.type(screen.getByLabelText(en['reg.password']), 'short');
    await user.type(screen.getByLabelText(en['reg.confirmPassword']), 'different');
    await submit(user);

    expect(screen.getByText(en['val.fullNameMax'].replace('{max}', '150'))).toBeInTheDocument();
    expect(screen.getByText(en['val.emailInvalid'])).toBeInTheDocument();
    expect(screen.getByText(en['val.passwordMin'].replace('{n}', '8'))).toBeInTheDocument();
    expect(screen.getByText(en['val.passwordsMismatch'])).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('maps backend 400 errors to fullName, email, password (several messages) and confirmPassword', async () => {
    chooseLanguage('en');
    mockApi({
      [REGISTER]: [
        () =>
          problem(400, 'validation_failed', 'One or more fields are invalid.', {
            fullName: ['Full name must not contain control characters.'],
            email: ['Email is not a valid email address.'],
            password: ["Passwords must have at least one digit ('0'-'9').", "Passwords must have at least one uppercase ('A'-'Z')."],
            confirmPassword: ['Passwords do not match.'],
          }),
      ],
    });
    renderApp('/register');
    const user = await fillForm();

    await submit(user);

    expect(await screen.findByText('Full name must not contain control characters.')).toBeInTheDocument();
    expect(screen.getByText('Email is not a valid email address.')).toBeInTheDocument();
    expect(screen.getByLabelText(en['reg.password'])).toHaveAccessibleDescription(
      "Passwords must have at least one digit ('0'-'9'). Passwords must have at least one uppercase ('A'-'Z').",
    );
    expect(screen.getByLabelText(en['reg.confirmPassword'])).toHaveAttribute('aria-invalid', 'true');
  });

  it('shows a duplicate account (409) on the email field', async () => {
    chooseLanguage('en');
    mockApi({ [REGISTER]: [() => problem(409, 'duplicate_account', 'An account with this email already exists.')] });
    renderApp('/register');
    const user = await fillForm();

    await submit(user);

    const email = screen.getByLabelText(en['reg.email']);
    await waitFor(() => expect(email).toHaveAttribute('aria-invalid', 'true'));
    expect(email).toHaveAccessibleDescription(en['val.duplicateAccount']);
    expect(screen.queryByText(en['reg.successBody'])).not.toBeInTheDocument();
    expect(screen.getByLabelText(en['reg.fullName'])).toHaveValue('Sara Ahmed'); // the form keeps the input
  });

  it('shows the rate limit (429), network errors and server errors as general messages without server details', async () => {
    chooseLanguage('en');
    mockApi({
      [REGISTER]: [
        () => problem(429, undefined, ''),
        () => {
          throw new TypeError('Failed to fetch');
        },
        () => problem(500, undefined, 'System.InvalidOperationException: secret detail'),
      ],
    });
    renderApp('/register');
    const user = await fillForm();

    await submit(user);
    expect(await screen.findByRole('alert')).toHaveTextContent(en['error.tooMany']);
    await submit(user);
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent(en['error.network']));
    await submit(user);
    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent(en['error.server']));
    expect(screen.queryByText(/secret detail/)).not.toBeInTheDocument();
  });

  it('disables the button and shows a loading label while the request is running', async () => {
    chooseLanguage('en');
    let release: (response: Response) => void = () => undefined;
    mockApi({ [REGISTER]: [() => new Promise<Response>((resolve) => (release = resolve))] });
    renderApp('/register');
    const user = await fillForm();

    await submit(user);

    const busy = await screen.findByRole('button', { name: en['reg.submitting'] });
    expect(busy).toBeDisabled();
    release(jsonResponse(201, { id: 'u9', fullName: 'S', email: 'a@b.cd', role: 'Student' }));
    expect(await screen.findByText(en['reg.successBody'])).toBeInTheDocument();
  });

  it('is reachable from the sign-in page', async () => {
    chooseLanguage('en');
    renderApp('/login');

    expect(screen.getByRole('link', { name: en['login.createAccount'] })).toHaveAttribute('href', '/register');
  });
});

describe('RegisterPage (Arabic, right-to-left)', () => {
  it('is Arabic and right-to-left by default, with the toggle on the page', () => {
    renderApp('/register');

    expect(screen.getByRole('heading', { name: ar['reg.title'] })).toBeInTheDocument();
    expect(screen.getByLabelText(ar['reg.fullName'])).toBeInTheDocument();
    expect(document.documentElement.lang).toBe('ar');
    expect(document.documentElement.dir).toBe('rtl');
    expect(screen.getByRole('button', { name: 'English' })).toBeInTheDocument();
    // Emails and passwords are typed left to right; the name follows its own text direction.
    expect(screen.getByLabelText(ar['reg.email'])).toHaveAttribute('dir', 'ltr');
    expect(screen.getByLabelText(ar['reg.fullName'])).toHaveAttribute('dir', 'auto');
  });

  it('translates validation and the duplicate-account message, and keeps the input when the language changes', async () => {
    mockApi({ [REGISTER]: [() => problem(409, 'duplicate_account', 'An account with this email already exists.')] });
    renderApp('/register');
    const user = userEvent.setup();

    await user.click(screen.getByRole('button', { name: ar['reg.submit'] }));
    expect(screen.getByText(ar['val.fullNameRequired'])).toBeInTheDocument();

    await user.type(screen.getByLabelText(ar['reg.fullName']), 'سارة أحمد');
    await user.type(screen.getByLabelText(ar['reg.email']), 'sara@example.edu');
    await user.type(screen.getByLabelText(ar['reg.password']), 'Example1pass');
    await user.type(screen.getByLabelText(ar['reg.confirmPassword']), 'Example1pass');
    await user.click(screen.getByRole('button', { name: ar['reg.submit'] }));
    await waitFor(() => expect(screen.getByLabelText(ar['reg.email'])).toHaveAccessibleDescription(ar['val.duplicateAccount']));

    await user.click(screen.getByRole('button', { name: 'English' }));

    expect(screen.getByLabelText(en['reg.fullName'])).toHaveValue('سارة أحمد'); // typed input survives the switch
    expect(screen.getByLabelText(en['reg.email'])).toHaveAccessibleDescription(en['val.duplicateAccount']);
    expect(document.documentElement.dir).toBe('ltr');
  });

  it('shows the Arabic success panel with the sign-in link', async () => {
    mockApi({ [REGISTER]: [() => jsonResponse(201, { id: 'u9', fullName: 'S', email: 'a@b.cd', role: 'Student' })] });
    renderApp('/register');
    const user = userEvent.setup();
    await user.type(screen.getByLabelText(ar['reg.fullName']), 'سارة أحمد');
    await user.type(screen.getByLabelText(ar['reg.email']), 'sara@example.edu');
    await user.type(screen.getByLabelText(ar['reg.password']), 'Example1pass');
    await user.type(screen.getByLabelText(ar['reg.confirmPassword']), 'Example1pass');

    await user.click(screen.getByRole('button', { name: ar['reg.submit'] }));

    expect(await screen.findByText(ar['reg.successBody'])).toBeInTheDocument();
    expect(screen.getByRole('link', { name: ar['reg.successSignIn'] })).toHaveAttribute('href', '/login');
  });
});
