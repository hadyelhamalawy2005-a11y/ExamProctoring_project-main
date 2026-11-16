import { screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { tokenStore } from '../auth/tokenStore';
import { ar } from '../i18n/ar';
import { en } from '../i18n/en';
import { callsTo, chooseLanguage, mockApi, renderApp } from '../test/helpers';
import { jsonResponse, problem, tokenResponse } from '../test/fixtures';
import { emptyIdentity, validateIdentity } from '../utils/identity';

// Administrator: create a student, with identity documents. The backend has no student endpoint yet, so by default the
// form only checks the input and says that nothing was created or uploaded. With VITE_ADMIN_CREATE_STUDENT=true (the day
// the backend ships it) it posts multipart form data. These tests use fixtures; nothing here proves the real server can do it.

const createdStudent = {
  id: 's9',
  fullName: 'New Student',
  email: 'student@example.test',
  role: 'Student',
  temporaryPassword: 'Tmp#Student-123',
  temporaryPasswordExpiresAt: '2030-01-02T09:00:00+00:00',
};
const NATIONAL_NUMBER = '29801011234567';
const COLLEGE_NUMBER = 'CS-2024-0042';

type User = ReturnType<typeof userEvent.setup>;
const image = (name = 'card.png', type = 'image/png', size = 2048) => new File([new Uint8Array(size)], name, { type });
const nameAndEmail = async (user: User, labels = { name: en['reg.fullName'], email: en['reg.email'] }) => {
  await user.type(await screen.findByLabelText(labels.name), '  New Student ');
  await user.type(screen.getByLabelText(labels.email), 'student@example.test');
};
const fileInput = (id: 'national-id' | 'college-id') => document.getElementById(`${id}-image`) as HTMLInputElement;
const submitButton = () => screen.getByRole('button', { name: en['admin.createStudent.submit'] });
const national = async (user: User, file = image('national.png')) => {
  await user.upload(fileInput('national-id'), file);
  await user.type(document.getElementById('national-id-number') as HTMLInputElement, NATIONAL_NUMBER);
};
const college = async (user: User, file = image('college.jpg', 'image/jpeg')) => {
  await user.upload(fileInput('college-id'), file);
  await user.type(document.getElementById('college-id-number') as HTMLInputElement, COLLEGE_NUMBER);
};
const bodyOf = (call: unknown[]) => (call[1] as RequestInit).body;

let created: string[];
let revoked: string[];
beforeEach(() => {
  chooseLanguage('en');
  tokenStore.setFromTokenResponse(tokenResponse({ role: 'Admin' }));
  created = [];
  revoked = [];
  let n = 0;
  URL.createObjectURL = vi.fn(() => {
    const url = `blob:preview-${++n}`;
    created.push(url);
    return url;
  });
  URL.revokeObjectURL = vi.fn((url: string) => {
    revoked.push(url);
  });
});
afterEach(() => vi.unstubAllEnvs());

describe('the identity rules', () => {
  it('are validated as pure data, with a message in both languages for every error', () => {
    const none = validateIdentity(emptyIdentity());
    expect(Object.keys(none)).toEqual(['identity']);
    const imageOnly = validateIdentity({ ...emptyIdentity(), nationalIdImage: image() });
    expect(Object.keys(imageOnly)).toEqual(['nationalIdNumber']);
    const numberOnly = validateIdentity({ ...emptyIdentity(), collegeStudentId: '123' });
    expect(Object.keys(numberOnly)).toEqual(['collegeIdImage']);
    expect(validateIdentity({ ...emptyIdentity(), nationalIdImage: image(), nationalIdNumber: '1' })).toEqual({});
    expect(validateIdentity({ ...emptyIdentity(), collegeIdImage: image(), collegeStudentId: '1' })).toEqual({});
    for (const key of ['val.identityRequired', 'val.nationalIdImageRequired', 'val.nationalIdNumberRequired', 'val.collegeIdImageRequired', 'val.collegeIdNumberRequired', 'val.idImageType', 'val.idImageSize'] as const) {
      expect(en[key]).toBeTruthy();
      expect(ar[key]).toBeTruthy();
    }
  });
});

describe('creating a student', () => {
  it('is reached from the admin navigation, next to creating an instructor', async () => {
    mockApi({ 'GET /api/admin/accounts': [() => jsonResponse(200, { items: [], page: 1, pageSize: 20, totalCount: 0 })] });
    renderApp('/admin/accounts');
    await screen.findByRole('heading', { name: en['admin.list.title'] });
    const nav = screen.getByRole('navigation', { name: en['nav.main'] });
    expect(within(nav).getByRole('link', { name: en['nav.newStudentShort'] })).toHaveAttribute('href', '/admin/students/new');
    expect(within(nav).getByRole('link', { name: en['nav.newInstructorShort'] })).toHaveAttribute('href', '/admin/instructors/new');
  });

  it('marks the identity documents as required and offers both documents', async () => {
    mockApi({});
    renderApp('/admin/students/new');
    const section = await screen.findByRole('region', { name: /Identity documents/ });
    expect(within(section).getByText(en['identity.mandatory'])).toBeInTheDocument();
    expect(within(section).getByRole('group', { name: en['identity.national'] })).toBeInTheDocument();
    expect(within(section).getByRole('group', { name: en['identity.college'] })).toBeInTheDocument();
  });

  it('blocks submission when no document is selected, and still checks name and email', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({});
    renderApp('/admin/students/new');
    await user.click(await screen.findByRole('button', { name: en['admin.createStudent.submit'] }));
    expect(screen.getByText(en['val.fullNameRequired'])).toBeInTheDocument();
    expect(screen.getByText(en['val.emailRequired'])).toBeInTheDocument();
    expect(screen.getByText(en['val.identityRequired'])).toBeInTheDocument();
    await nameAndEmail(user);
    await user.click(submitButton());
    expect(screen.getByText(en['val.identityRequired'])).toBeInTheDocument();
    expect(screen.queryByText(en['admin.createStudent.notSent'])).not.toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('blocks a National ID image without its number, next to the number field', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await user.upload(fileInput('national-id'), image());
    await user.click(submitButton());
    const number = document.getElementById('national-id-number') as HTMLInputElement;
    expect(number).toHaveAttribute('aria-invalid', 'true');
    expect(number).toHaveAccessibleDescription(en['val.nationalIdNumberRequired']);
    expect(screen.queryByText(en['admin.createStudent.notSent'])).not.toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('blocks a College ID image without its number, next to the number field', async () => {
    const user = userEvent.setup();
    mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await user.upload(fileInput('college-id'), image('c.jpg', 'image/jpeg'));
    await user.click(submitButton());
    expect(document.getElementById('college-id-number')).toHaveAccessibleDescription(en['val.collegeIdNumberRequired']);
    expect(screen.queryByText(en['admin.createStudent.notSent'])).not.toBeInTheDocument();
  });

  it('blocks a number without its image', async () => {
    const user = userEvent.setup();
    mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await user.type(document.getElementById('national-id-number') as HTMLInputElement, NATIONAL_NUMBER);
    await user.click(submitButton());
    expect(screen.getByText(en['val.nationalIdImageRequired'])).toBeInTheDocument();
    expect(screen.queryByText(en['admin.createStudent.notSent'])).not.toBeInTheDocument();
  });

  it('accepts a National ID image with its number alone (valid; nothing is created while the server cannot)', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({});
    renderApp('/admin/students/new');
    expect(await screen.findByText(en['admin.createStudent.unavailable'])).toBeInTheDocument();
    await nameAndEmail(user);
    await national(user);
    await user.click(submitButton());
    expect(await screen.findByText(en['admin.createStudent.notSent'])).toBeInTheDocument();
    expect(screen.queryByText(en['admin.createStudent.createdTitle'])).not.toBeInTheDocument();
    expect(screen.queryByTestId('temp-password')).not.toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('accepts a College ID image with its number alone', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await college(user);
    await user.click(submitButton());
    expect(await screen.findByText(en['admin.createStudent.notSent'])).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('accepts both document pairs together', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await national(user);
    await college(user);
    await user.click(submitButton());
    expect(await screen.findByText(en['admin.createStudent.notSent'])).toBeInTheDocument();
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('becomes invalid again when the only selected document is removed', async () => {
    const user = userEvent.setup();
    mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await national(user);
    await user.click(submitButton());
    expect(await screen.findByText(en['admin.createStudent.notSent'])).toBeInTheDocument();

    const group = screen.getByRole('group', { name: en['identity.national'] });
    await user.click(within(group).getByRole('button', { name: en['identity.remove'] }));
    await user.clear(document.getElementById('national-id-number') as HTMLInputElement);
    await user.click(submitButton());
    expect(screen.getByText(en['val.identityRequired'])).toBeInTheDocument();
    expect(screen.queryByText(en['admin.createStudent.notSent'])).not.toBeInTheDocument();
  });

  it('keeps removing the image but leaving the number invalid too (the pair must be complete)', async () => {
    const user = userEvent.setup();
    mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await national(user);
    await user.click(within(screen.getByRole('group', { name: en['identity.national'] })).getByRole('button', { name: en['identity.remove'] }));
    await user.click(submitButton());
    expect(screen.getByText(en['val.nationalIdImageRequired'])).toBeInTheDocument();
    expect(screen.queryByText(en['admin.createStudent.notSent'])).not.toBeInTheDocument();
  });

  it('refuses a file that is not a JPG, PNG or WebP image, and one that is too large', async () => {
    const user = userEvent.setup({ applyAccept: false });
    mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await user.upload(fileInput('national-id'), new File(['%PDF'], 'card.pdf', { type: 'application/pdf' }));
    await user.type(document.getElementById('national-id-number') as HTMLInputElement, NATIONAL_NUMBER);
    await user.click(submitButton());
    expect(screen.getByText(en['val.idImageType'])).toBeInTheDocument();

    await user.upload(fileInput('national-id'), image('big.png', 'image/png', 5 * 1024 * 1024 + 1));
    await user.click(submitButton());
    expect(screen.getByText('The photo must be 5 MB or smaller.')).toBeInTheDocument();
    expect(screen.queryByText(en['admin.createStudent.notSent'])).not.toBeInTheDocument();
  });

  it('shows the file name and a preview, lets the admin replace or remove it, and releases every preview URL', async () => {
    const user = userEvent.setup();
    mockApi({});
    const { unmount } = renderApp('/admin/students/new');
    await screen.findByRole('region', { name: /Identity documents/ });
    const group = screen.getByRole('group', { name: en['identity.national'] });

    await user.upload(fileInput('national-id'), image('first.png'));
    expect(within(group).getByText('first.png')).toBeInTheDocument();
    expect(within(group).getByRole('img', { name: 'Preview of first.png' })).toHaveAttribute('src', 'blob:preview-1');

    await user.upload(fileInput('national-id'), image('second.png')); // replace
    expect(within(group).getByText('second.png')).toBeInTheDocument();
    expect(within(group).queryByText('first.png')).not.toBeInTheDocument();
    expect(revoked).toContain('blob:preview-1');

    await user.click(within(group).getByRole('button', { name: en['identity.remove'] }));
    expect(within(group).queryByRole('img')).not.toBeInTheDocument();
    expect(revoked).toContain('blob:preview-2');

    await user.upload(fileInput('national-id'), image('third.png'));
    unmount();
    await waitFor(() => expect(revoked).toContain('blob:preview-3'));
    expect(revoked.sort()).toEqual(created.sort()); // nothing is left allocated
  });

  it('never writes the documents or their numbers to browser storage or the console', async () => {
    const user = userEvent.setup();
    const consoleSpies = (['log', 'info', 'warn', 'error', 'debug'] as const).map((level) => vi.spyOn(console, level).mockImplementation(() => undefined));
    mockApi({});
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await national(user, image('secret-national.png'));
    await college(user, image('secret-college.jpg', 'image/jpeg'));
    await user.click(submitButton());
    await screen.findByText(en['admin.createStudent.notSent']);

    for (const storage of [window.localStorage, window.sessionStorage]) {
      const dump = JSON.stringify({ ...storage });
      for (const secret of [NATIONAL_NUMBER, COLLEGE_NUMBER, 'secret-national', 'secret-college']) expect(dump).not.toContain(secret);
    }
    for (const spy of consoleSpies) {
      expect(JSON.stringify(spy.mock.calls)).not.toContain(NATIONAL_NUMBER);
      expect(JSON.stringify(spy.mock.calls)).not.toContain(COLLEGE_NUMBER);
    }
    consoleSpies.forEach((spy) => spy.mockRestore());
  });

  it('with the deployment flag on, sends multipart form data with only the complete pairs, never JSON', async () => {
    vi.stubEnv('VITE_ADMIN_CREATE_STUDENT', 'true');
    const user = userEvent.setup();
    const fetchMock = mockApi({ 'POST /api/admin/students': [() => jsonResponse(201, createdStudent)] });
    renderApp('/admin/students/new');
    expect(screen.queryByText(en['admin.createStudent.unavailable'])).not.toBeInTheDocument();
    await nameAndEmail(user);
    await college(user);
    await user.click(submitButton());

    expect(await screen.findByRole('heading', { name: en['admin.createStudent.createdTitle'] })).toBeInTheDocument();
    expect(screen.getByTestId('temp-password')).toHaveTextContent('Tmp#Student-123');
    const call = callsTo(fetchMock, 'POST /api/admin/students')[0];
    const body = bodyOf(call) as FormData;
    expect(body).toBeInstanceOf(FormData);
    expect([...body.keys()].sort()).toEqual(['collegeIdImage', 'collegeStudentId', 'email', 'fullName']);
    expect(body.get('fullName')).toBe('New Student');
    expect(body.get('collegeStudentId')).toBe(COLLEGE_NUMBER);
    expect((body.get('collegeIdImage') as File).name).toBe('college.jpg');
    expect(((call[1] as RequestInit).headers as Record<string, string>)['Content-Type']).toBeUndefined(); // the browser sets the boundary
    expect(callsTo(fetchMock, 'POST /api/admin/instructors')).toHaveLength(0);
    // After success the documents are dropped.
    expect(revoked.length).toBe(created.length);
  });

  it('sends both pairs when both are given', async () => {
    vi.stubEnv('VITE_ADMIN_CREATE_STUDENT', 'true');
    const user = userEvent.setup();
    const fetchMock = mockApi({ 'POST /api/admin/students': [() => jsonResponse(201, createdStudent)] });
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await national(user);
    await college(user);
    await user.click(submitButton());
    await screen.findByTestId('temp-password');
    const body = bodyOf(callsTo(fetchMock, 'POST /api/admin/students')[0]) as FormData;
    expect([...body.keys()].sort()).toEqual(['collegeIdImage', 'collegeStudentId', 'email', 'fullName', 'nationalIdImage', 'nationalIdNumber']);
  });

  it('refuses to present an account as a created student when the server answers with another role', async () => {
    vi.stubEnv('VITE_ADMIN_CREATE_STUDENT', 'true');
    const user = userEvent.setup();
    mockApi({ 'POST /api/admin/students': [() => jsonResponse(201, { ...createdStudent, role: 'Instructor' })] });
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await national(user);
    await user.click(submitButton());
    expect(await screen.findByRole('alert')).toBeInTheDocument();
    expect(screen.queryByTestId('temp-password')).not.toBeInTheDocument();
  });

  it('shows a duplicate email on the email field and keeps the chosen documents', async () => {
    vi.stubEnv('VITE_ADMIN_CREATE_STUDENT', 'true');
    const user = userEvent.setup();
    mockApi({ 'POST /api/admin/students': [() => problem(409, 'duplicate_account', 'An account with this email already exists.')] });
    renderApp('/admin/students/new');
    await nameAndEmail(user);
    await national(user);
    await user.click(submitButton());
    expect(await screen.findByText(en['val.duplicateAccount'])).toBeInTheDocument();
    expect(screen.getByText('national.png')).toBeInTheDocument();
  });

  it('shows the validation messages in Arabic', async () => {
    const user = userEvent.setup();
    chooseLanguage('ar');
    mockApi({});
    renderApp('/admin/students/new');
    await user.click(await screen.findByRole('button', { name: ar['admin.createStudent.submit'] }));
    expect(screen.getByText(ar['val.identityRequired'])).toBeInTheDocument();
    expect(screen.getByRole('region', { name: /وثائق الهوية/ })).toBeInTheDocument();

    await user.upload(fileInput('college-id'), image('c.jpg', 'image/jpeg'));
    await user.click(screen.getByRole('button', { name: ar['admin.createStudent.submit'] }));
    expect(screen.getByText(ar['val.collegeIdNumberRequired'])).toBeInTheDocument();
    expect(document.getElementById('national-id-number')).toHaveAttribute('dir', 'ltr');
  });
});

describe('creating an instructor is unchanged', () => {
  it('has no identity documents and still posts exactly { fullName, email } as JSON to /api/admin/instructors', async () => {
    const user = userEvent.setup();
    const fetchMock = mockApi({ 'POST /api/admin/instructors': [() => jsonResponse(201, { ...createdStudent, id: 'i1', role: 'Instructor' })] });
    renderApp('/admin/instructors/new');
    await nameAndEmail(user);
    expect(screen.queryByRole('region', { name: /Identity documents/ })).not.toBeInTheDocument();
    expect(document.querySelector('input[type="file"]')).toBeNull();
    await user.click(screen.getByRole('button', { name: en['admin.create.submit'] }));
    expect(await screen.findByTestId('temp-password')).toBeInTheDocument();
    const call = callsTo(fetchMock, 'POST /api/admin/instructors')[0];
    expect(JSON.parse((call[1] as RequestInit).body as string)).toEqual({ fullName: 'New Student', email: 'student@example.test' });
    expect(((call[1] as RequestInit).headers as Record<string, string>)['Content-Type']).toBe('application/json');
  });
});
