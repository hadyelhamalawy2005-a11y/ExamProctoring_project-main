// Code questions and the settings around an exam that the backend cannot store yet. Everything here is kept in this
// browser only (src/local/examExtras.ts) until the backend gets matching endpoints.

export type CodeLanguageId = 'java' | 'c' | 'cpp' | 'python' | 'javascript';
export type EditorMode = 'normal' | 'vim' | 'emacs';
export type TabSize = 2 | 4 | 8;
export type CodeEvaluation = 'ai' | 'manual';

export const CODE_LANGUAGES: readonly { id: CodeLanguageId; name: string }[] = [
  { id: 'java', name: 'Java' },
  { id: 'c', name: 'C' },
  { id: 'cpp', name: 'C++' },
  { id: 'python', name: 'Python' },
  { id: 'javascript', name: 'JavaScript' },
];
export const EDITOR_MODES: readonly EditorMode[] = ['normal', 'vim', 'emacs'];
export const TAB_SIZES: readonly TabSize[] = [2, 4, 8];

export interface CodeQuestion {
  id: string;
  text: string;
  marks: number;
  starterCode: string;
  languages: CodeLanguageId[]; // what students may pick (at least one)
  defaultLanguage: CodeLanguageId;
  editorModes: EditorMode[]; // what students may pick (at least one)
  defaultMode: EditorMode;
  tabSizes: TabSize[]; // what students may pick (at least one)
  defaultTabSize: TabSize;
  autocomplete: boolean; // the teacher decides; the student only sees the state
  evaluation: CodeEvaluation;
}

// What a student chose in the editor. Kept for the session only.
export interface EditorPreferences {
  language: CodeLanguageId;
  mode: EditorMode;
  tabSize: TabSize;
}

export const emptyCodeQuestion = (id: string): CodeQuestion => ({
  id,
  text: '',
  marks: 1,
  starterCode: '',
  languages: ['java', 'cpp', 'python'],
  defaultLanguage: 'python',
  editorModes: ['normal', 'vim', 'emacs'],
  defaultMode: 'normal',
  tabSizes: [2, 4, 8],
  defaultTabSize: 4,
  autocomplete: true,
  evaluation: 'manual',
});

export type CodeQuestionProblem = 'text' | 'marks' | 'languages' | 'modes' | 'tabSizes' | 'defaults';

// The same rules the form and the store both rely on: every list has at least one entry and the default is in its list.
export function validateCodeQuestion(question: CodeQuestion): CodeQuestionProblem[] {
  const problems: CodeQuestionProblem[] = [];
  if (!question.text.trim()) problems.push('text');
  if (!(question.marks > 0)) problems.push('marks');
  if (question.languages.length === 0) problems.push('languages');
  if (question.editorModes.length === 0) problems.push('modes');
  if (question.tabSizes.length === 0) problems.push('tabSizes');
  if (
    !question.languages.includes(question.defaultLanguage) ||
    !question.editorModes.includes(question.defaultMode) ||
    !question.tabSizes.includes(question.defaultTabSize)
  ) {
    problems.push('defaults');
  }
  return problems;
}
