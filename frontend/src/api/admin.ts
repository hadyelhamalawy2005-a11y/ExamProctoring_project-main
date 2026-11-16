import type {
  AccountListParams,
  AccountPage,
  AccountSummary,
  CreateInstructorRequest,
  CreateInstructorResponse,
  TemporaryPasswordResponse,
} from '../types/api';
import { apiRequest } from './client';

// AdminAccountsController (Admin role only). It lists and manages Student and Instructor accounts; Admin accounts are
// never returned or changed. There is no search parameter. The backend has no endpoint to create a student account yet.

export function listAccounts(params: AccountListParams = {}, signal?: AbortSignal): Promise<AccountPage> {
  const query = new URLSearchParams();
  if (params.role) query.set('role', params.role);
  if (params.status) query.set('status', params.status);
  if (params.page) query.set('page', String(params.page));
  if (params.pageSize) query.set('pageSize', String(params.pageSize));
  const text = query.toString();
  return apiRequest<AccountPage>(`/api/admin/accounts${text ? `?${text}` : ''}`, { signal });
}

export function getAccount(id: string, signal?: AbortSignal): Promise<AccountSummary> {
  return apiRequest<AccountSummary>(`/api/admin/accounts/${encodeURIComponent(id)}`, { signal });
}

// 201. Duplicate email -> 409 duplicate_account. The response holds the temporary password: show it once, never store it.
export function createInstructor(request: CreateInstructorRequest): Promise<CreateInstructorResponse> {
  return apiRequest<CreateInstructorResponse>('/api/admin/instructors', {
    method: 'POST',
    body: { fullName: request.fullName, email: request.email },
  });
}

// NOT IN THE BACKEND YET. Creating a student needs identity documents, so it will be a multipart/form-data request
// (fullName, email, nationalIdNumber, nationalIdImage, collegeStudentId, collegeIdImage), never the JSON { fullName, email }
// of an instructor. The body is built by identityFormData() in utils/identity.ts. The screen only sends it when the build
// has VITE_ADMIN_CREATE_STUDENT=true, which must stay off until the backend has the endpoint. The 201 response is the same
// shape as for an instructor, with role "Student" and no document content. See docs/Frontend_Pending_Backend.md.
export const studentCreationSupported = (): boolean => import.meta.env.VITE_ADMIN_CREATE_STUDENT === 'true';

export function createStudent(form: FormData): Promise<CreateInstructorResponse> {
  return apiRequest<CreateInstructorResponse>('/api/admin/students', { method: 'POST', body: form });
}

// 200. Also ends the account's sessions and clears a lockout; the account's status does not change.
export function issueTemporaryPassword(id: string): Promise<TemporaryPasswordResponse> {
  return apiRequest<TemporaryPasswordResponse>(`/api/admin/accounts/${encodeURIComponent(id)}/temporary-password`, { method: 'POST' });
}

// 204. The reason is required (1-500 characters). 409 account_status_unchanged when already deactivated.
export function deactivateAccount(id: string, reason: string): Promise<void> {
  return apiRequest<void>(`/api/admin/accounts/${encodeURIComponent(id)}/deactivate`, { method: 'POST', body: { reason } });
}

// 204. The reason is optional. 409 account_status_unchanged when already active.
export function reactivateAccount(id: string, reason?: string): Promise<void> {
  return apiRequest<void>(`/api/admin/accounts/${encodeURIComponent(id)}/reactivate`, {
    method: 'POST',
    body: reason ? { reason } : {},
  });
}
