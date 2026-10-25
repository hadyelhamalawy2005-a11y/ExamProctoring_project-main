import type { QuestionImportPreview, QuestionList, QuestionRequest } from '../types/api';
import { apiRequest } from './client';

// QuestionImportController (instructors only). The Word import has two steps: read the file (nothing is saved), then save
// the reviewed questions.

// POST /api/questions/import/preview: multipart/form-data with one file field named "file" (.docx, at most 10 MB).
export function previewQuestionImport(file: File, signal?: AbortSignal): Promise<QuestionImportPreview> {
  const form = new FormData();
  form.append('file', file, file.name);
  return apiRequest<QuestionImportPreview>('/api/questions/import/preview', { method: 'POST', body: form, signal });
}

// POST /api/exams/{examId}/questions/import: appends all questions after the exam's last one, or none (201).
export function importQuestions(examId: string, questions: QuestionRequest[]): Promise<QuestionList> {
  return apiRequest<QuestionList>(`/api/exams/${encodeURIComponent(examId)}/questions/import`, {
    method: 'POST',
    body: { questions },
  });
}
