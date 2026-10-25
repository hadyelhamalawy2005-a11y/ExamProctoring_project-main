import type { TranslationKey } from './en';
import type { I18n, Params } from './translate';

// The backend answers with English messages. Known ones are translated here by matching the exact English text (messages
// with a number use {name} placeholders). The error code and field names stay untouched, so field-error mapping is
// unaffected. Anything unknown is shown as the server sent it, isolated as left-to-right text inside Arabic.
// Source of the texts: the validators and services in src/ExamProctoring.Application and the Identity password policy.

interface Rule {
  pattern: RegExp;
  key: TranslationKey;
  params: string[];
}

function rule(template: string, key: TranslationKey): Rule {
  const params: string[] = [];
  const escaped = template.replace(/[.*+?^$()|[\]\\]/g, '\\$&');
  const source = escaped.replace(/\{(\w+)\}/g, (_match, name: string) => {
    params.push(name);
    return '([\\d.]+)';
  });
  return { pattern: new RegExp(`^${source}$`), key, params };
}

const RULES: Rule[] = [
  rule('One or more fields are invalid.', 'srv.fieldsInvalid'),
  rule('The email or password is incorrect.', 'srv.invalidCredentials'),
  rule('This account is temporarily locked after too many failed attempts. Try again later.', 'srv.accountLocked'),
  rule('This account has been deactivated.', 'srv.accountDeactivated'),
  rule('The temporary password has expired. Ask an administrator for a new one.', 'srv.temporaryExpired'),
  rule('The refresh token is invalid or has expired.', 'srv.refreshInvalid'),
  rule('A valid access token is required.', 'srv.tokenRequired'),
  rule('You must change your password before using this endpoint.', 'srv.passwordChangeRequired'),
  rule('The exam was not found.', 'srv.examNotFound'),
  rule('The question was not found.', 'srv.questionNotFound'),
  rule('The exam can no longer be changed in its current state.', 'srv.examNotEditable'),
  rule('A published exam must keep at least one question.', 'srv.keepOneQuestion'),
  rule('The exam has no questions.', 'srv.noQuestions'),
  rule('The exam is already published.', 'srv.alreadyPublished'),
  rule('A cancelled exam cannot be published.', 'srv.cancelledNotPublishable'),
  rule('The start time has passed.', 'srv.startPassed'),
  rule('The exam is not published.', 'srv.notPublished'),
  rule('A cancelled exam cannot be unpublished.', 'srv.cancelledNotUnpublishable'),
  rule('Only a published exam can be cancelled.', 'srv.onlyPublishedCancellable'),
  rule('The exam is already cancelled.', 'srv.alreadyCancelled'),
  rule('Question {n} has no text.', 'srv.questionNoText'),
  rule('Question {n} has invalid marks.', 'srv.questionBadMarks'),
  rule('Question {n} needs at least 2 options.', 'srv.questionFewOptions'),
  rule('Question {n} has more options than the current maximum of {max}.', 'srv.questionManyOptions'),
  rule('Question {n} needs exactly one correct option.', 'srv.questionOneCorrect'),
  rule('Question {n} repeats an option text.', 'srv.questionRepeats'),
  rule('Status must be Draft, Published or Cancelled.', 'srv.statusInvalid'),
  rule('Page must be 1 or greater.', 'srv.pageInvalid'),
  rule('Page size must be between 1 and 100.', 'srv.pageSizeInvalid'),

  // Sign-up and password fields
  rule('An account with this email already exists.', 'val.duplicateAccount'),
  rule('Full name is required.', 'val.fullNameRequired'),
  rule('Full name must be at most {max} characters.', 'val.fullNameMax'),
  rule('Full name must not contain control characters.', 'val.fullNameControl'),
  rule('Email is required.', 'val.emailRequired'),
  rule('Email is not a valid email address.', 'val.emailInvalid'),
  rule('Password is required.', 'val.passwordRequired'),
  rule('Passwords do not match.', 'val.passwordsMismatch'),
  rule('Current password is required.', 'val.currentRequired'),
  rule('The current password is incorrect.', 'val.currentIncorrect'),
  rule('New password is required.', 'val.newRequired'),
  rule('The new password must be different from the current password.', 'val.newSame'),
  // ASP.NET Core Identity's default texts (policy: 8+ characters, upper case, lower case, digit).
  rule('Passwords must be at least {n} characters.', 'val.passwordMin'),
  rule("Passwords must have at least one uppercase ('A'-'Z').", 'val.passwordUpper'),
  rule("Passwords must have at least one lowercase ('a'-'z').", 'val.passwordLower'),
  rule("Passwords must have at least one digit ('0'-'9').", 'val.passwordDigit'),

  // Word import: the uploaded file and the confirmation list
  rule('A .docx file is required.', 'val.fileRequired'),
  rule('Only .docx files are supported.', 'val.fileExtension'),
  rule('The file is empty.', 'val.fileEmpty'),
  rule('The file is larger than 10 MB.', 'val.fileTooLarge'),
  rule('The file is not a valid Word (.docx) document.', 'val.fileInvalid'),
  rule('The Word document is too complex to read.', 'val.fileComplex'),
  rule('The Word document is too large to read.', 'val.fileHuge'),
  rule('Question is required.', 'val.questionRequired'),
  rule('At least one question is required.', 'val.questionsRequired'),
  rule('At most 200 questions can be imported at once.', 'val.questionsMax'),

  // Exam fields
  rule('Title is required.', 'val.titleRequired'),
  rule('Title must be at most {max} characters.', 'val.titleMax'),
  rule('Description must be at most {max} characters.', 'val.descriptionMax'),
  rule('Start time is required.', 'val.startRequired'),
  rule('Start time must be in the future.', 'val.startFuture'),
  rule('Start time is too far in the future.', 'val.startTooFar'),
  rule('Duration is required.', 'val.durationRequired'),
  rule('Duration must be between {min} and {max} minutes.', 'val.durationRange'),

  // Question fields
  rule('Type is required.', 'val.typeRequired'),
  rule('Type must be Mcq or Essay.', 'val.typeInvalid'),
  rule('Text is required.', 'val.textRequired'),
  rule('Text must be at most {max} characters.', 'val.textMax'),
  rule('Marks are required.', 'val.marksRequired'),
  rule('Marks must be greater than 0.', 'val.marksPositive'),
  rule('Marks must be at most {max}.', 'val.marksMax'),
  rule('Marks can have at most 2 decimal places.', 'val.marksDecimals'),
  rule('Model answer must be at most {max} characters.', 'val.modelAnswerMax'),
  rule('An MCQ question needs at least {min} options.', 'val.optionsMin'),
  rule('An MCQ question can have at most {max} options.', 'val.optionsMax'),
  rule('An MCQ question needs exactly one correct option.', 'val.optionsOneCorrect'),
  rule('Options must not repeat the same text.', 'val.optionsRepeat'),
  rule('Option is required.', 'val.optionMissing'),
  rule('Option text is required.', 'val.optionRequired'),
  rule('Option text must be at most {max} characters.', 'val.optionMax'),
  rule('An Essay question has no options.', 'val.essayNoOptions'),
];

const OFFSET_MESSAGE = /^Start time must be a date and time with a time-zone offset/;

// Left-to-right isolate: keeps an English sentence in order inside Arabic text.
const LRI = '⁦';
const PDI = '⁩';

export function localizeServerMessage(message: string, i18n: Pick<I18n, 't' | 'lang'>): string {
  // The server's own text is already English.
  if (i18n.lang === 'en') return message;
  for (const { pattern, key, params } of RULES) {
    const match = pattern.exec(message);
    if (match) {
      return i18n.t(key, Object.fromEntries(params.map((name, index) => [name, match[index + 1]])));
    }
  }
  if (OFFSET_MESSAGE.test(message)) return i18n.t('val.startOffset');
  return i18n.lang === 'ar' ? `${LRI}${message}${PDI}` : message;
}

// A message kept as data (a dictionary key, or the backend's English texts) and turned into text only when it is shown,
// so errors already on screen switch language together with the rest of the page.
export type Msg = string | { key: TranslationKey; params?: Params } | { server: string[] };

export const msg = (key: TranslationKey, params?: Params): Msg => ({ key, params });

export function resolveMsg(message: Msg, i18n: Pick<I18n, 't' | 'lang'>): string {
  if (typeof message === 'string') return message;
  if ('key' in message) return i18n.t(message.key, message.params);
  return message.server.map((text) => localizeServerMessage(text, i18n)).join(' ');
}

// Backend field errors as messages, keyed by the backend's field names (unchanged, so they still match the form fields).
export function serverFieldMsgs(fieldErrors: Record<string, string[]>, options: { all?: boolean } = {}): Record<string, Msg> {
  return Object.fromEntries(
    Object.entries(fieldErrors).map(([field, messages]) => [field, { server: options.all ? messages : messages.slice(0, 1) }]),
  );
}

// Backend field errors ({ "options[1].text": ["Option text is required."] }) → one translated text per field name.
// The keys are returned unchanged, so they still match the form fields.
export function localizeFieldErrors(
  fieldErrors: Record<string, string[]>,
  i18n: Pick<I18n, 't' | 'lang'>,
  options: { all?: boolean } = {},
): Record<string, string> {
  return Object.fromEntries(
    Object.entries(serverFieldMsgs(fieldErrors, options)).map(([field, message]) => [field, resolveMsg(message, i18n)]),
  );
}
