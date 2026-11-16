import { normalizeCodeQuestion, type CodeQuestion, type EditorPreferences } from '../types/code';
import { readJson, writeJson } from './safeStorage';

// TEMPORARY, BROWSER-ONLY. The backend has no fields for these yet, so they live in localStorage, keyed by exam id:
// subject, planned total marks, how the questions are being entered, and code questions. They are not shared between
// browsers and disappear if the browser data is cleared. No API call is made for any of it.

export type QuestionMethod = 'manual' | 'word';

export interface ExamExtras {
  subjectId: string | null;
  totalMarks: number | null;
  method: QuestionMethod | null; // chosen once per exam
  codeQuestions: CodeQuestion[];
}

const key = (examId: string) => `examExtras.${examId}`;
const empty = (): ExamExtras => ({ subjectId: null, totalMarks: null, method: null, codeQuestions: [] });

export function getExtras(examId: string): ExamExtras {
  const stored = { ...empty(), ...readJson<Partial<ExamExtras>>(key(examId), {}) };
  return { ...stored, codeQuestions: stored.codeQuestions.map(normalizeCodeQuestion) };
}

export function saveExtras(examId: string, patch: Partial<ExamExtras>): ExamExtras {
  const next = { ...getExtras(examId), ...patch };
  writeJson(key(examId), next);
  return next;
}

export function upsertCodeQuestion(examId: string, question: CodeQuestion): ExamExtras {
  const current = getExtras(examId).codeQuestions;
  const exists = current.some((item) => item.id === question.id);
  return saveExtras(examId, {
    codeQuestions: exists ? current.map((item) => (item.id === question.id ? question : item)) : [...current, question],
  });
}

export function removeCodeQuestion(examId: string, questionId: string): ExamExtras {
  return saveExtras(examId, { codeQuestions: getExtras(examId).codeQuestions.filter((item) => item.id !== questionId) });
}

export const newLocalId = () => `local-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

// A student's editor choices live for the browser session only (sessionStorage), per exam and question.
const prefKey = (examId: string, questionId: string) => `editorPrefs.${examId}.${questionId}`;

export function readPreferences(examId: string, questionId: string): Partial<EditorPreferences> {
  try {
    const raw = window.sessionStorage.getItem(prefKey(examId, questionId));
    return raw ? (JSON.parse(raw) as Partial<EditorPreferences>) : {};
  } catch {
    return {};
  }
}

export function writePreferences(examId: string, questionId: string, prefs: EditorPreferences): void {
  try {
    window.sessionStorage.setItem(prefKey(examId, questionId), JSON.stringify(prefs));
  } catch {
    // Not stored: the editor keeps working with what is on screen.
  }
}
