import { en } from '../i18n/en';
import { localizeServerMessage } from '../i18n/serverMessages';
import type { I18n } from '../i18n/translate';
import type { ImportedQuestion, ImportIssue, QuestionRequest, QuestionType } from '../types/api';
import { validateQuestionDraft, type FieldErrors } from './validation';

// A question from the Word document while the instructor reviews it. The text fields are strings, as in the manual form,
// so they can be edited freely; toRequest turns them into the API's QuestionRequest.

export interface DraftOption {
  key: string;
  label: string;
  text: string;
  isCorrect: boolean;
}

export interface QuestionDraft {
  key: string;
  number: number;
  type: QuestionType;
  text: string;
  marks: string;
  marksDefaulted: boolean;
  modelAnswer: string;
  options: DraftOption[];
  // What the backend found in the document. Once the instructor edits the question these are no longer shown: the question
  // is checked again, here and by the backend on import.
  issues: ImportIssue[];
  edited: boolean;
}

export function toDraft(question: ImportedQuestion, index: number): QuestionDraft {
  return {
    key: `q${index}`,
    number: question.number,
    type: question.type,
    text: question.text,
    marks: String(question.marks),
    marksDefaulted: question.marksDefaulted,
    modelAnswer: question.modelAnswer ?? '',
    options: question.options.map((option, optionIndex) => ({
      key: `q${index}o${optionIndex}`,
      label: option.label,
      text: option.text,
      isCorrect: option.isCorrect,
    })),
    issues: question.issues,
    edited: false,
  };
}

export const hasErrorIssue = (draft: QuestionDraft): boolean => draft.issues.some((issue) => issue.severity === 'error');

// Blocks the import: the backend found an error in the document and the instructor has not changed the question yet.
export const isBlocked = (draft: QuestionDraft): boolean => !draft.edited && hasErrorIssue(draft);

export const validateDraft = (draft: QuestionDraft): FieldErrors =>
  validateQuestionDraft({ type: draft.type, text: draft.text, marks: draft.marks, modelAnswer: draft.modelAnswer, options: draft.options });

// The body of POST /api/exams/{id}/questions/import for one question: the same fields as the manual form sends.
export function toRequest(draft: QuestionDraft): QuestionRequest {
  return {
    type: draft.type,
    text: draft.text.trim(),
    marks: Number(draft.marks.trim()),
    modelAnswer: draft.modelAnswer.trim() ? draft.modelAnswer.trim() : null,
    options: draft.type === 'Mcq' ? draft.options.map((option) => ({ text: option.text.trim(), isCorrect: option.isCorrect })) : [],
  };
}

// The text of a problem found in the document. English: the backend's own message (it has the details), without the
// "Question N:" prefix when it belongs to a question (the card already says which). Arabic: the translation for the issue's
// code, or the translated/isolated backend message when there is none.
export function issueText(issue: ImportIssue, i18n: Pick<I18n, 't' | 'lang'>): string {
  const stripped = issue.message.replace(/^Question \d+: /, '');
  if (i18n.lang === 'en') return issue.question === null ? issue.message : stripped;

  const key = `import.issue.${issue.code}`;
  if (key in en) return i18n.t(key as keyof typeof en, { line: issue.line ?? '' });
  return localizeServerMessage(stripped, i18n);
}

// Errors of the confirmation request, keyed "questions[3].options[1].text", grouped by question index with the key the
// question card uses ("options[1].text"). Keys that do not belong to a question (for example "questions") are returned
// under -1.
export function groupConfirmErrors(fieldErrors: Record<string, string[]>): Map<number, Record<string, string[]>> {
  const grouped = new Map<number, Record<string, string[]>>();
  for (const [key, messages] of Object.entries(fieldErrors)) {
    const match = /^questions\[(\d+)\](?:\.(.+))?$/.exec(key);
    const index = match ? Number(match[1]) : -1;
    const field = match ? (match[2] ?? 'question') : key;
    grouped.set(index, { ...(grouped.get(index) ?? {}), [field]: messages });
  }
  return grouped;
}
