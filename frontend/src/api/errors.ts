import { localizeServerMessage } from '../i18n/serverMessages';
import { englishI18n, type I18n } from '../i18n/translate';
import type { ProblemDetails } from '../types/api';

export type ApiErrorKind = 'http' | 'network' | 'aborted';

// One error type for every failed call. For HTTP errors, code, detail and fieldErrors come from the backend's
// ProblemDetails body (application/problem+json). They stay in the backend's English; only the text shown to the user
// is translated (describeError and serverMessages.ts).
export class ApiError extends Error {
  readonly kind: ApiErrorKind;
  readonly status: number; // 0 when no response was received
  readonly code?: string;
  readonly detail?: string;
  readonly fieldErrors: Record<string, string[]>;

  constructor(kind: ApiErrorKind, status: number, problem: ProblemDetails = {}) {
    super(problem.detail ?? (kind === 'network' ? 'Network error' : `HTTP ${status}`));
    this.name = 'ApiError';
    this.kind = kind;
    this.status = status;
    this.code = problem.code;
    this.detail = problem.detail;
    this.fieldErrors = problem.errors ?? {};
  }
}

export function isAbortError(error: unknown): boolean {
  return error instanceof ApiError && error.kind === 'aborted';
}

// Network errors, rate limits and server errors say nothing about the request itself or about the credentials.
export function isTemporaryFailure(error: unknown): boolean {
  if (!(error instanceof ApiError)) return false;
  return error.kind === 'network' || error.kind === 'aborted' || error.status === 429 || error.status >= 500;
}

type Translation = Pick<I18n, 't' | 'lang'>;

// A message that is safe to show to the user, in the active language (English when none is given). Server-error details
// are never shown, because in Development the backend may put internal exception messages there.
export function describeError(error: unknown, i18n: Translation = englishI18n): string {
  const { t } = i18n;
  if (!(error instanceof ApiError)) return t('error.generic');

  if (error.kind === 'network') return t('error.network');

  const detail = error.detail ? localizeServerMessage(error.detail, i18n) : undefined;

  switch (error.status) {
    case 400:
      return detail ?? t('error.badRequest');
    case 401:
      return error.code === 'token_invalid' || !error.code ? t('error.sessionEnded') : (detail ?? t('error.signInFailed'));
    case 403:
      if (error.code === 'password_change_required') return t('error.passwordChangeRequired');
      if (error.code) return detail ?? t('error.notAllowed');
      return t('error.noAccess');
    case 404:
      if (error.code === 'exam_not_found') return t('error.examNotFound');
      if (error.code === 'question_not_found') return t('error.questionNotFound');
      return t('error.notFound');
    case 409:
      return detail ?? t('error.conflict');
    case 413:
      return t('error.tooLarge');
    case 429:
      return t('error.tooMany');
    default:
      return error.status >= 500 ? t('error.server') : (detail ?? t('error.requestFailed', { status: error.status }));
  }
}
