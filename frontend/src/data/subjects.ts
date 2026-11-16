// The one list of subjects the exam form offers. TEMPORARY: the backend has no subject or course endpoint yet.
// When it does, replace the body of listSubjects() with the API call; every caller already awaits it and only uses
// { id, name }, so nothing else changes.

export interface Subject {
  id: string; // stable, stored with the exam
  name: string; // shown as is: subject names are not translated
}

const SUBJECTS: readonly Subject[] = [
  { id: 'programming', name: 'Programming' },
  { id: 'data-structures', name: 'Data Structures & Algorithms' },
  { id: 'databases', name: 'Databases' },
  { id: 'networks', name: 'Computer Networks' },
  { id: 'operating-systems', name: 'Operating Systems' },
  { id: 'software-engineering', name: 'Software Engineering' },
  { id: 'mathematics', name: 'Mathematics' },
  { id: 'physics', name: 'Physics' },
  { id: 'english', name: 'English' },
];

export async function listSubjects(): Promise<readonly Subject[]> {
  return SUBJECTS;
}

export const subjectName = (id: string | null | undefined): string | null =>
  SUBJECTS.find((subject) => subject.id === id)?.name ?? null;
