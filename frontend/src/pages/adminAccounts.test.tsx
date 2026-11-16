import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { beforeEach, describe, expect, it } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { ar } from '../i18n/ar';
import { en } from '../i18n/en';
import { callsTo, chooseLanguage, mockApi, renderApp } from '../test/helpers';
import { jsonResponse, problem, tokenResponse } from '../test/fixtures';
import type { AccountSummary } from '../types/api';

const LIST = 'GET /api/admin/accounts';
const account = (patch: Partial<AccountSummary> = {}): AccountSummary => ({
  id: 'a1',
  fullName: 'Sara Ali',
  email: 'sara@example.test',
  role: 'Student',
  accountStatus: 'Active',
  mustChangePassword: false,
  temporaryPasswordExpiresAt: null,
  isLockedOut: false,
  createdAt: '2030-01-01T09:00:00+00:00',
  lastLoginAt: null,
  statusChangedAt: null,
  statusReason: null,
  ...patch,
});
const page = (items: AccountSummary[], extra: Partial<{ page: number; totalCount: number }> = {}) =>
  jsonResponse(200, { items, page: extra.page ?? 1, pageSize: 20, totalCount: extra.totalCount ?? items.length });

const requestedUrls = (fetchMock: ReturnType<typeof mockApi>) => fetchMock.mock.calls.map(([url]) => String(url));
const bodyOf = (call: unknown[]) => JSON.parse(((call[1] as RequestInit).body as string) ?? 'null') as Record<string, unknown>;

beforeEach(() => {
  chooseLanguage('en');
  tokenStore.setFromTokenResponse(tokenResponse({ role: 'Admin' }));
});

describe('the accounts list', () => {
  it('shows name, email, role, status and last sign-in from the API', async () => {
    mockApi({ [LIST]: [() => page([account(), account({ id: 'a2', fullName: 'Omar K', email: 'omar@example.test', role: 'Instructor', accountStatus: 'Deactivated', lastLoginAt: '2030-02-01T10:00:00+00:00' })])] });
    renderApp('/admin/accounts');
    const sara = await screen.findByRole('link', { name: /Sara Ali/ });
    expect(within(sara).getByText('sara@example.test')).toBeInTheDocument();
    expect(within(sara).getByText('Student')).toBeInTheDocument();
    expect(within(sara).getByText('Active')).toBeInTheDocument();
    const omar = screen.getByRole('link', { name: /Omar K/ });
    expect(within(omar).getByText('Instructor')).toBeInTheDocument();
    expect(within(omar).getByText('Deactivated')).toBeInTheDocument();
    expect(sara).toHaveAttribute('href', '/admin/accounts/a1');
  });

  it('shows a loading state, then the table', async () => {
    mockApi({ [LIST]: [() => page([account()])] });
    renderApp('/admin/accounts');
    expect(screen.getByText(en['admin.list.loading'])).toBeInTheDocument();
    expect(await screen.findByRole('link', { name: /Sara Ali/ })).toBeInTheDocument();
  });

  it('empty: an empty state; with filters, a different message', async () => {
    mockApi({ [LIST]: [() => page([])] });
    renderApp('/admin/accounts');
    expect(await screen.findByText(en['admin.list.emptyNone'])).toBeInTheDocument();
  });

  it('an error is shown as an error with a retry, never as an empty list', async () => {
    const user = userEvent.setup();
    mockApi({ [LIST]: [() => problem(500, undefined, 'boom'), () => page([account()])] });
    renderApp('/admin/accounts');
    expect(await screen.findByRole('alert')).toHaveTextContent(en['error.server']);
    expect(screen.queryByText(en['admin.list.emptyNone'])).not.toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: en['common.tryAgain'] }));
    expect(await screen.findByRole('link', { name: /Sara Ali/ })).toBeInTheDocument();
  });

  it('filters by role and status with the backend’s query parameters, and goes back to page 1', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({ [LIST]: [() => page([account()])] });
    renderApp('/admin/accounts?page=3');
    await screen.findByRole('link', { name: /Sara Ali/ });
    expect(requestedUrls(fetchMock)[0]).toBe('/api/admin/accounts?page=3&pageSize=20');

    await user.click(within(screen.getByRole('group', { name: en['admin.list.role'] })).getByRole('button', { name: 'Instructor' }));
    await waitFor(() => expect(requestedUrls(fetchMock).at(-1)).toBe('/api/admin/accounts?role=Instructor&page=1&pageSize=20'));
    await user.click(within(screen.getByRole('group', { name: en['admin.list.status'] })).getByRole('button', { name: 'Deactivated' }));
    await waitFor(() => expect(requestedUrls(fetchMock).at(-1)).toBe('/api/admin/accounts?role=Instructor&status=Deactivated&page=1&pageSize=20'));
  });

  it('shows a filter-specific empty message', async () => {
    mockApi({ [LIST]: [() => page([])] });
    renderApp('/admin/accounts?role=Student');
    expect(await screen.findByText(en['admin.list.emptyFiltered'])).toBeInTheDocument();
  });

  it('pages through the list with the real page, size and total', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({
      [LIST]: [
        () => page([account()], { page: 1, totalCount: 45 }),
        () => page([account({ id: 'a2', fullName: 'Page Two' })], { page: 2, totalCount: 45 }),
      ],
    });
    renderApp('/admin/accounts');
    expect(await screen.findByText('1–20 of 45')).toBeInTheDocument();
    expect(screen.getByText('Page 1 of 3')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: /Next/ }));
    expect(await screen.findByRole('link', { name: /Page Two/ })).toBeInTheDocument();
    expect(requestedUrls(fetchMock).at(-1)).toBe('/api/admin/accounts?page=2&pageSize=20');
  });

  it('in Arabic: right to left, with Arabic labels and statuses', async () => {
    chooseLanguage('ar');
    mockApi({ [LIST]: [() => page([account({ accountStatus: 'Deactivated' })])] });
    renderApp('/admin/accounts');
    expect(await screen.findByRole('heading', { name: ar['admin.list.title'] })).toBeInTheDocument();
    expect(document.documentElement).toHaveAttribute('dir', 'rtl');
    const card = screen.getByRole('link', { name: /Sara Ali/ });
    expect(within(card).getByText(ar['account.status.Deactivated'])).toBeInTheDocument();
    expect(within(card).getByText(ar['role.Student'])).toBeInTheDocument();
  });

  it('uses the admin shell: a title bar and navigation to the accounts, a new instructor and the profile', async () => {
    mockApi({ [LIST]: [() => page([])] });
    renderApp('/admin/accounts');
    expect(await screen.findByRole('heading', { name: en['admin.list.title'] })).toBeInTheDocument();
    const nav = screen.getByRole('navigation', { name: en['nav.main'] });
    expect(within(nav).getAllByRole('link').map((link) => link.textContent)).toEqual(['Accounts', 'Instructor', 'Student', 'Profile']);
    expect(within(nav).getByRole('link', { name: en['nav.profile'] })).toHaveAttribute('href', '/profile');
    expect(screen.getByRole('link', { name: en['admin.list.newInstructor'] })).toHaveAttribute('href', '/admin/instructors/new');
    expect(screen.getByRole('link', { name: en['admin.list.newStudent'] })).toHaveAttribute('href', '/admin/students/new');
  });
});

describe('creating an instructor', () => {
  const created = {
    id: 'i9',
    fullName: 'New Teacher',
    email: 'new@example.test',
    role: 'Instructor',
    temporaryPassword: 'Tmp#Secret-123',
    temporaryPasswordExpiresAt: '2030-01-02T09:00:00+00:00',
  };

  it('sends exactly fullName and email, then shows the temporary password once', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({ 'POST /api/admin/instructors': [() => jsonResponse(201, created)] });
    renderApp('/admin/instructors/new');
    await user.type(await screen.findByLabelText(en['reg.fullName']), '  New Teacher ');
    await user.type(screen.getByLabelText(en['reg.email']), 'new@example.test');
    await user.click(screen.getByRole('button', { name: en['admin.create.submit'] }));

    expect(await screen.findByTestId('temp-password')).toHaveTextContent('Tmp#Secret-123');
    const call = callsTo(fetchMock, 'POST /api/admin/instructors')[0];
    expect(bodyOf(call)).toEqual({ fullName: 'New Teacher', email: 'new@example.test' });
    expect(screen.getByText(en['admin.tp.shownOnce'])).toBeInTheDocument();
    expect(screen.getByRole('link', { name: en['admin.create.open'] })).toHaveAttribute('href', '/admin/accounts/i9');

    // Done: the password leaves the page and is not kept anywhere.
    await user.click(screen.getByRole('button', { name: en['admin.tp.done'] }));
    expect(screen.queryByText('Tmp#Secret-123')).not.toBeInTheDocument();
    for (const storage of [window.localStorage, window.sessionStorage]) {
      expect(JSON.stringify({ ...storage })).not.toContain('Tmp#Secret-123');
    }
  });

  it('validates before sending', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({ 'POST /api/admin/instructors': [() => jsonResponse(201, created)] });
    renderApp('/admin/instructors/new');
    await user.click(await screen.findByRole('button', { name: en['admin.create.submit'] }));
    expect(screen.getByText(en['val.fullNameRequired'])).toBeInTheDocument();
    expect(screen.getByText(en['val.emailRequired'])).toBeInTheDocument();
    await user.type(screen.getByLabelText(en['reg.fullName']), 'Teacher');
    await user.type(screen.getByLabelText(en['reg.email']), 'not-an-email');
    await user.click(screen.getByRole('button', { name: en['admin.create.submit'] }));
    expect(screen.getByText(en['val.emailInvalid'])).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('shows the backend’s validation errors on the fields', async () => {
    const user = userEvent.setup();
    mockApi({
      'POST /api/admin/instructors': [
        () => problem(400, 'validation_failed', 'One or more fields are invalid.', { fullName: ['Full name must not contain control characters.'] }),
      ],
    });
    renderApp('/admin/instructors/new');
    await user.type(await screen.findByLabelText(en['reg.fullName']), 'Teacher');
    await user.type(screen.getByLabelText(en['reg.email']), 'teacher@example.test');
    await user.click(screen.getByRole('button', { name: en['admin.create.submit'] }));
    expect(await screen.findByText('Full name must not contain control characters.')).toBeInTheDocument();
  });

  it('a duplicate email is shown on the email field', async () => {
    const user = userEvent.setup();
    mockApi({ 'POST /api/admin/instructors': [() => problem(409, 'duplicate_account', 'An account with this email already exists.')] });
    renderApp('/admin/instructors/new');
    await user.type(await screen.findByLabelText(en['reg.fullName']), 'Teacher');
    await user.type(screen.getByLabelText(en['reg.email']), 'teacher@example.test');
    await user.click(screen.getByRole('button', { name: en['admin.create.submit'] }));
    expect(await screen.findByText(en['val.duplicateAccount'])).toBeInTheDocument();
  });
});

describe('account details and actions', () => {
  const ONE = 'GET /api/admin/accounts/a1';

  it('shows every field the API returns', async () => {
    mockApi({ [ONE]: [() => jsonResponse(200, account({ isLockedOut: true, mustChangePassword: true, temporaryPasswordExpiresAt: '2030-01-05T09:00:00+00:00', statusReason: 'Left the course', accountStatus: 'Deactivated', statusChangedAt: '2030-01-03T09:00:00+00:00' }))] });
    renderApp('/admin/accounts/a1');
    expect(await screen.findByRole('heading', { name: 'Sara Ali' })).toBeInTheDocument();
    expect(screen.getByText('sara@example.test')).toBeInTheDocument();
    expect(screen.getByText('Left the course')).toBeInTheDocument();
    expect(within(document.querySelector('dl')!).getByText(en['admin.detail.lockedOut']).nextSibling).toHaveTextContent('Yes');
    expect(screen.getByRole('button', { name: en['admin.reactivate.button'] })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: en['admin.deactivate.button'] })).not.toBeInTheDocument();
  });

  it('an account that does not exist is a clear error with a way back', async () => {
    mockApi({ [ONE]: [() => problem(404, 'account_not_found', 'The account was not found.')] });
    renderApp('/admin/accounts/a1');
    expect(await screen.findByRole('alert')).toHaveTextContent(en['error.notFound']);
    expect(screen.getByRole('link', { name: en['admin.detail.back'] })).toBeInTheDocument();
  });

  it('missing optional data shows a dash instead of breaking', async () => {
    mockApi({ [ONE]: [() => jsonResponse(200, account())] });
    renderApp('/admin/accounts/a1');
    await screen.findByRole('heading', { name: 'Sara Ali' });
    expect(screen.getAllByText('—').length).toBeGreaterThanOrEqual(3);
  });

  it('issues a temporary password after confirmation and shows it once', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({
      [ONE]: [() => jsonResponse(200, account())],
      'POST /api/admin/accounts/a1/temporary-password': [() => jsonResponse(200, { temporaryPassword: 'Tmp#Reset-999', temporaryPasswordExpiresAt: '2030-01-02T09:00:00+00:00' })],
    });
    renderApp('/admin/accounts/a1');
    await user.click(await screen.findByRole('button', { name: en['admin.tp.button'] }));
    expect(callsTo(fetchMock, 'POST /api/admin/accounts/a1/temporary-password')).toHaveLength(0); // not before confirming
    const dialog = screen.getByRole('dialog');
    await user.click(within(dialog).getByRole('button', { name: en['admin.tp.confirm'] }));

    expect(await screen.findByTestId('temp-password')).toHaveTextContent('Tmp#Reset-999');
    await user.click(screen.getByRole('button', { name: en['admin.tp.done'] }));
    expect(screen.queryByText('Tmp#Reset-999')).not.toBeInTheDocument();
  });

  it('cancelling the confirmation does nothing', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({ [ONE]: [() => jsonResponse(200, account())] });
    renderApp('/admin/accounts/a1');
    await user.click(await screen.findByRole('button', { name: en['admin.tp.button'] }));
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: en['common.keep'] }));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
    expect(fetchMock.mock.calls.every(([, init]) => ((init as RequestInit | undefined)?.method ?? 'GET') === 'GET')).toBe(true);
  });

  it('deactivation needs a reason, sends it, and reloads the account', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({
      [ONE]: [() => jsonResponse(200, account()), () => jsonResponse(200, account({ accountStatus: 'Deactivated', statusReason: 'Left the course' }))],
      'POST /api/admin/accounts/a1/deactivate': [() => new Response(null, { status: 204 })],
    });
    renderApp('/admin/accounts/a1');
    await user.click(await screen.findByRole('button', { name: en['admin.deactivate.button'] }));
    const dialog = screen.getByRole('dialog');

    await user.click(within(dialog).getByRole('button', { name: en['admin.deactivate.confirm'] }));
    expect(within(dialog).getByText(en['val.reasonRequired'])).toBeInTheDocument();
    expect(callsTo(fetchMock, 'POST /api/admin/accounts/a1/deactivate')).toHaveLength(0);

    await user.type(within(dialog).getByLabelText(en['admin.deactivate.reason']), '  Left the course ');
    await user.click(within(dialog).getByRole('button', { name: en['admin.deactivate.confirm'] }));

    expect(await screen.findByText(en['admin.deactivate.done'])).toBeInTheDocument();
    expect(bodyOf(callsTo(fetchMock, 'POST /api/admin/accounts/a1/deactivate')[0])).toEqual({ reason: 'Left the course' });
    expect(await screen.findByRole('button', { name: en['admin.reactivate.button'] })).toBeInTheDocument();
  });

  it('a reason over 500 characters is refused before sending', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({ [ONE]: [() => jsonResponse(200, account())] });
    renderApp('/admin/accounts/a1');
    await user.click(await screen.findByRole('button', { name: en['admin.deactivate.button'] }));
    const dialog = screen.getByRole('dialog');
    await user.click(within(dialog).getByLabelText(en['admin.deactivate.reason']));
    await user.paste('x'.repeat(501));
    await user.click(within(dialog).getByRole('button', { name: en['admin.deactivate.confirm'] }));
    expect(within(dialog).getByText('The reason must be at most 500 characters.')).toBeInTheDocument();
    expect(callsTo(fetchMock, 'POST /api/admin/accounts/a1/deactivate')).toHaveLength(0);
  });

  it('reactivation works without a reason', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({
      [ONE]: [() => jsonResponse(200, account({ accountStatus: 'Deactivated' })), () => jsonResponse(200, account())],
      'POST /api/admin/accounts/a1/reactivate': [() => new Response(null, { status: 204 })],
    });
    renderApp('/admin/accounts/a1');
    await user.click(await screen.findByRole('button', { name: en['admin.reactivate.button'] }));
    await user.click(within(screen.getByRole('dialog')).getByRole('button', { name: en['admin.reactivate.confirm'] }));
    expect(await screen.findByText(en['admin.reactivate.done'])).toBeInTheDocument();
    expect(bodyOf(callsTo(fetchMock, 'POST /api/admin/accounts/a1/reactivate')[0])).toEqual({});
    expect(await screen.findByRole('button', { name: en['admin.deactivate.button'] })).toBeInTheDocument();
  });

  it('an invalid state change (already deactivated) shows the server’s message and reloads', async () => {
    const user = userEvent.setup();
    mockApi({
      [ONE]: [() => jsonResponse(200, account()), () => jsonResponse(200, account({ accountStatus: 'Deactivated' }))],
      'POST /api/admin/accounts/a1/deactivate': [() => problem(409, 'account_status_unchanged', 'The account is already deactivated.')],
    });
    renderApp('/admin/accounts/a1');
    await user.click(await screen.findByRole('button', { name: en['admin.deactivate.button'] }));
    const dialog = screen.getByRole('dialog');
    await user.type(within(dialog).getByLabelText(en['admin.deactivate.reason']), 'duplicate');
    await user.click(within(dialog).getByRole('button', { name: en['admin.deactivate.confirm'] }));
    expect(await screen.findByRole('alert')).toHaveTextContent('The account is already deactivated.');
    expect(await screen.findByRole('button', { name: en['admin.reactivate.button'] })).toBeInTheDocument();
  });

  it('in Arabic the server’s "already deactivated" message is translated', async () => {
    chooseLanguage('ar');
    const user = userEvent.setup();
    mockApi({
      [ONE]: [() => jsonResponse(200, account())],
      'POST /api/admin/accounts/a1/deactivate': [() => problem(409, 'account_status_unchanged', 'The account is already deactivated.')],
    });
    renderApp('/admin/accounts/a1');
    await user.click(await screen.findByRole('button', { name: ar['admin.deactivate.button'] }));
    const dialog = screen.getByRole('dialog');
    await user.type(within(dialog).getByLabelText(ar['admin.deactivate.reason']), 'x');
    await user.click(within(dialog).getByRole('button', { name: ar['admin.deactivate.confirm'] }));
    expect(await screen.findByRole('alert')).toHaveTextContent(ar['srv.alreadyDeactivated']);
  });
});
