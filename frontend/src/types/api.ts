// TypeScript mirrors of the backend DTOs. Property names are the JSON (camelCase) names the API sends and accepts.
// Source of truth: src/ExamProctoring.Application/Auth/*.cs and src/ExamProctoring.Application/Exams/*.cs.

// ---- Authentication (Application/Auth/TokenResponse.cs, MeResponse.cs) ----

export type Role = 'Admin' | 'Instructor' | 'Student';

export interface AuthUser {
  id: string;
  fullName: string;
  email: string;
  role: Role;
}

export interface TokenResponse {
  tokenType: string; // "Bearer"
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt: string;
  mustChangePassword: boolean;
  user: AuthUser;
}

// ---- Student sign-up (Application/Auth/RegisterStudentRequest.cs, RegisterStudentResponse.cs) ----

// Exactly these four fields; the backend has no role or university field. confirmPassword is validated, never stored.
export interface RegisterRequest {
  fullName: string;
  email: string;
  password: string;
  confirmPassword: string;
}

// 201 body. No tokens: the new student is not signed in.
export interface RegisterResponse {
  id: string;
  fullName: string;
  email: string;
  role: 'Student';
}

// ---- Exams (Application/Exams/ExamRequest.cs, ExamResponse.cs, ExamListResponse.cs) ----

export type ExamStatus = 'Draft' | 'Published' | 'Cancelled';
export type ExamPhase = 'Upcoming' | 'Open' | 'Closed';

export interface Exam {
  id: string;
  title: string;
  description: string | null;
  startsAt: string; // ISO 8601, always UTC (+00:00) in responses
  durationMinutes: number;
  endsAt: string;
  status: ExamStatus;
  phase: ExamPhase;
  warningLimit: number; // set by the system, never sent by the client
  publishedAt: string | null;
}

export interface ExamPage {
  items: Exam[];
  page: number;
  pageSize: number;
  totalCount: number;
}

// startsAt must carry an explicit offset (Z or +hh:mm); the server converts it to UTC.
export interface ExamRequest {
  title: string;
  description: string | null;
  startsAt: string;
  durationMinutes: number;
}

// ---- Questions (Application/Exams/QuestionRequest.cs, QuestionResponse.cs) ----

export type QuestionType = 'Mcq' | 'Essay';

export interface QuestionOption {
  id: string;
  text: string;
  isCorrect: boolean;
  position: number;
}

export interface Question {
  id: string;
  examId: string;
  type: QuestionType;
  text: string;
  marks: number;
  modelAnswer: string | null;
  position: number;
  options: QuestionOption[];
}

export interface QuestionList {
  items: Question[];
}

export interface QuestionOptionRequest {
  text: string;
  isCorrect: boolean;
}

export interface QuestionRequest {
  type: QuestionType;
  text: string;
  marks: number;
  modelAnswer: string | null;
  options: QuestionOptionRequest[];
}

// ---- Word import (Application/Exams/Import/QuestionImportModels.cs) ----

export type ImportSeverity = 'error' | 'warning';

// A problem found in the Word document. code is stable; message is the backend's English text. question is the number
// written in the document, line the position among its non-empty lines.
export interface ImportIssue {
  code: string;
  severity: ImportSeverity;
  message: string;
  question: number | null;
  line: number | null;
}

export interface ImportedOption {
  label: string; // A, B, C ...
  text: string;
  isCorrect: boolean;
}

export interface ImportedQuestion {
  number: number;
  line: number;
  type: QuestionType;
  text: string;
  marks: number;
  marksDefaulted: boolean;
  modelAnswer: string | null;
  options: ImportedOption[];
  issues: ImportIssue[];
}

// POST /api/questions/import/preview: nothing is saved.
export interface QuestionImportPreview {
  examTitle: string | null;
  defaultMarks: number;
  maxOptions: number;
  isValid: boolean;
  questions: ImportedQuestion[];
  issues: ImportIssue[];
}

// POST /api/exams/{examId}/questions/import: the reviewed questions, saved all or none.
export interface QuestionImportRequest {
  questions: QuestionRequest[];
}

// ---- Errors (RFC 9457 ProblemDetails with the backend's stable "code" extension) ----

export interface ProblemDetails {
  status?: number;
  title?: string;
  detail?: string;
  code?: string;
  errors?: Record<string, string[]>;
}
