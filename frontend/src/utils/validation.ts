import { msg, resolveMsg, type Msg } from '../i18n/serverMessages';
import { englishI18n, type I18n } from '../i18n/translate';
import type { QuestionType } from '../types/api';
import { localInputToApi } from './dates';

// Early checks that mirror the backend validators (ExamRequestValidator, QuestionRequestValidator,
// RegisterStudentRequestValidator, AccountFieldRules, EmailRules) so users see mistakes before submitting. The backend
// stays the authority: its 400 field errors are shown as well. Messages are returned as data (Msg) and translated when shown. Limits come from Domain/Exams/ExamFieldLimits.cs, Exam.cs, QuestionRules.cs
// and Auth/AccountFieldRules.cs.

export const LIMITS = {
  titleMax: 200,
  descriptionMax: 2000,
  durationMin: 1,
  durationMax: 360,
  questionTextMax: 4000,
  modelAnswerMax: 4000,
  optionTextMax: 1000,
  minMcqOptions: 2,
  maxMarks: 9999.99,
  fullNameMax: 150,
  emailMax: 256,
  passwordMin: 8,
} as const;

export type FieldErrors = Record<string, Msg>;

export interface ExamFormValues {
  title: string;
  description: string;
  startsAtLocal: string; // datetime-local value
  durationMinutes: string;
}

export function validateExamForm(
  values: ExamFormValues,
  options: { startTimeChanged: boolean },
): FieldErrors {
  const errors: FieldErrors = {};
  const title = values.title.trim();
  if (!title) errors.title = msg('val.titleRequired');
  else if (title.length > LIMITS.titleMax) errors.title = msg('val.titleMax', { max: LIMITS.titleMax });

  if (values.description.trim().length > LIMITS.descriptionMax) {
    errors.description = msg('val.descriptionMax', { max: LIMITS.descriptionMax });
  }

  if (!values.startsAtLocal) {
    errors.startsAt = msg('val.startRequired');
  } else if (options.startTimeChanged) {
    const iso = localInputToApi(values.startsAtLocal);
    if (!iso) errors.startsAt = msg('val.startInvalid');
    else if (Date.parse(iso) <= Date.now()) errors.startsAt = msg('val.startFuture');
  }

  const duration = Number(values.durationMinutes);
  if (!values.durationMinutes.trim()) errors.durationMinutes = msg('val.durationRequired');
  else if (!Number.isInteger(duration) || duration < LIMITS.durationMin || duration > LIMITS.durationMax) {
    errors.durationMinutes = msg('val.durationRange', { min: LIMITS.durationMin, max: LIMITS.durationMax });
  }

  return errors;
}

// Marks: greater than 0, at most 9999.99, at most two decimal places.
export function marksMessage(value: string): Msg | null {
  const trimmed = value.trim();
  if (!trimmed) return msg('val.marksRequired');
  if (!/^\d+(\.\d+)?$/.test(trimmed)) return msg('val.marksNumber');
  const marks = Number(trimmed);
  if (marks <= 0) return msg('val.marksPositive');
  if (marks > LIMITS.maxMarks) return msg('val.marksMax', { max: LIMITS.maxMarks });
  if (!/^\d+(\.\d{1,2})?0*$/.test(trimmed)) return msg('val.marksDecimals');
  return null;
}

// The same check as a plain string in the given language (English by default).
export function validateMarks(value: string, i18n: Pick<I18n, 't' | 'lang'> = englishI18n): string | null {
  const message = marksMessage(value);
  return message ? resolveMsg(message, i18n) : null;
}

// Text comparison used by the backend for repeated options: trimmed, ignoring letter case.
export function sameOptionText(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase();
}

// ---- A question being edited (the manual form and the Word import review share these checks) ----

export interface QuestionDraftValues {
  type: QuestionType;
  text: string;
  marks: string;
  modelAnswer: string;
  options: Array<{ text: string; isCorrect: boolean }>;
}

// Keys follow the backend's: text, marks, modelAnswer, options (the group), options[i].text (i from 0).
export function validateQuestionDraft(values: QuestionDraftValues): FieldErrors {
  const found: FieldErrors = {};
  const trimmed = values.text.trim();
  if (!trimmed) found.text = msg('val.textRequired');
  else if (trimmed.length > LIMITS.questionTextMax) found.text = msg('val.textMax', { max: LIMITS.questionTextMax });

  const marksError = marksMessage(values.marks);
  if (marksError) found.marks = marksError;

  if (values.modelAnswer.trim().length > LIMITS.modelAnswerMax) {
    found.modelAnswer = msg('val.modelAnswerMax', { max: LIMITS.modelAnswerMax });
  }

  if (values.type === 'Mcq') {
    values.options.forEach((option, index) => {
      const value = option.text.trim();
      if (!value) found[`options[${index}].text`] = msg('val.optionRequired');
      else if (value.length > LIMITS.optionTextMax) {
        found[`options[${index}].text`] = msg('val.optionMax', { max: LIMITS.optionTextMax });
      }
    });
    if (values.options.length < LIMITS.minMcqOptions) found.options = msg('val.optionsMin', { min: LIMITS.minMcqOptions });
    else if (values.options.filter((option) => option.isCorrect).length !== 1) found.options = msg('val.optionsOneCorrect');
    else {
      const filled = values.options.map((option) => option.text).filter((value) => value.trim());
      const repeated = filled.some((value, index) => filled.findIndex((other) => sameOptionText(other, value)) !== index);
      if (repeated) found.options = msg('val.optionsRepeat');
    }
  }
  return found;
}

// ---- Student sign-up (POST /api/auth/register) ----

export interface RegisterFormValues {
  fullName: string;
  email: string;
  password: string;
  confirmPassword: string;
}

// The backend's EmailRules, applied to the trimmed value: 1-256 characters, no whitespace, control or invisible format
// characters, exactly one '@' with text on both sides, and a domain that contains a dot, doesn't start or end with '.' or
// '-' and has no "..". Any domain and non-English letters are allowed.
export function isValidEmail(raw: string): boolean {
  const value = raw.trim();
  if (value.length < 1 || value.length > LIMITS.emailMax) return false;
  if (/[\s\p{Cc}\p{Cf}]/u.test(value)) return false;
  const at = value.indexOf('@');
  if (at <= 0 || at === value.length - 1 || at !== value.lastIndexOf('@')) return false;
  const domain = value.slice(at + 1);
  return domain.includes('.') && !/^[.-]/.test(domain) && !/[.-]$/.test(domain) && !domain.includes('..');
}

export function validateRegisterForm(values: RegisterFormValues): FieldErrors {
  const errors: FieldErrors = {};

  const name = values.fullName.trim();
  if (!name) errors.fullName = msg('val.fullNameRequired');
  else if (name.length > LIMITS.fullNameMax) errors.fullName = msg('val.fullNameMax', { max: LIMITS.fullNameMax });
  else if (/\p{Cc}/u.test(values.fullName)) errors.fullName = msg('val.fullNameControl');

  if (!values.email.trim()) errors.email = msg('val.emailRequired');
  else if (!isValidEmail(values.email)) errors.email = msg('val.emailInvalid');

  // The password policy (Identity): at least 8 characters, an upper case letter, a lower case letter and a digit.
  if (!values.password) errors.password = msg('val.passwordRequired');
  else if (values.password.length < LIMITS.passwordMin) errors.password = msg('val.passwordMin', { n: LIMITS.passwordMin });
  else if (!/[A-Z]/.test(values.password)) errors.password = msg('val.passwordUpper');
  else if (!/[a-z]/.test(values.password)) errors.password = msg('val.passwordLower');
  else if (!/\d/.test(values.password)) errors.password = msg('val.passwordDigit');

  if (values.confirmPassword !== values.password) errors.confirmPassword = msg('val.passwordsMismatch');
  return errors;
}
