// Code questions and the settings around an exam that the backend cannot store yet. Everything here is kept in this
// browser only (src/local/examExtras.ts) until the backend gets matching endpoints.

export type CodeLanguageId = 'java' | 'c' | 'cpp' | 'python' | 'javascript';

export const CODE_LANGUAGES: readonly { id: CodeLanguageId; name: string }[] = [
  { id: 'java', name: 'Java' },
  { id: 'c', name: 'C' },
  { id: 'cpp', name: 'C++' },
  { id: 'python', name: 'Python' },
  { id: 'javascript', name: 'JavaScript' },
];

// The indentation the editor uses for each language. It follows the language and is not a setting anyone chooses.
export const INDENT_SIZES: Record<CodeLanguageId, number> = { c: 4, cpp: 4, java: 4, python: 4, javascript: 2 };

export interface CodeQuestion {
  id: string;
  text: string;
  marks: number;
  languages: CodeLanguageId[]; // what students may pick (at least one)
  defaultLanguage: CodeLanguageId;
  // Editor suggestions while the student types (words from the code and the language's keywords). It is not AI code
  // generation and it is not grading. The teacher decides; the student only sees the state.
  autoCompletionEnabled: boolean;
}

// What a student chose in the editor. Kept for the session only.
export interface EditorPreferences {
  language: CodeLanguageId;
}

export const emptyCodeQuestion = (id: string): CodeQuestion => ({
  id,
  text: '',
  marks: 1,
  languages: ['java', 'cpp', 'python'],
  defaultLanguage: 'python',
  autoCompletionEnabled: true,
});

// Questions saved by earlier versions carry fields that no longer exist (starter code, tab sizes, evaluation, editor modes) and call
// the autocomplete flag `autocomplete`. Read them into the current shape and let the old fields go.
export function normalizeCodeQuestion(stored: Partial<CodeQuestion> & { autocomplete?: boolean }): CodeQuestion {
  const base = emptyCodeQuestion(stored.id ?? '');
  return {
    id: base.id,
    text: stored.text ?? base.text,
    marks: stored.marks ?? base.marks,
    languages: stored.languages ?? base.languages,
    defaultLanguage: stored.defaultLanguage ?? base.defaultLanguage,
    autoCompletionEnabled: stored.autoCompletionEnabled ?? stored.autocomplete ?? base.autoCompletionEnabled,
  };
}

export type CodeQuestionProblem = 'text' | 'marks' | 'languages' | 'defaults';

// The same rules the form and the store both rely on: every list has at least one entry and the default is in its list.
export function validateCodeQuestion(question: CodeQuestion): CodeQuestionProblem[] {
  const problems: CodeQuestionProblem[] = [];
  if (!question.text.trim()) problems.push('text');
  if (!(question.marks > 0)) problems.push('marks');
  if (question.languages.length === 0) problems.push('languages');
  if (!question.languages.includes(question.defaultLanguage)) problems.push('defaults');
  return problems;
}
