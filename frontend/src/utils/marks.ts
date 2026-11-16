import { LIMITS } from './validation';

// Marks are worked in hundredths (the backend keeps two decimal places), so sums are exact and never drift.
const toCents = (value: number) => Math.round(value * 100);
const fromCents = (cents: number) => cents / 100;

export const MARKS_DECIMALS = 2;

// Splits `total` equally between `count` questions. When it does not divide exactly, the first questions get one
// hundredth more, so the parts always add up to the total. Example: 20 over 10 -> 2 each; 10 over 3 -> 3.34, 3.33, 3.33.
// Returns null when the split is impossible (no questions, or less than 0.01 per question).
export function distributeMarks(total: number, count: number): number[] | null {
  const cents = toCents(total);
  if (!Number.isFinite(total) || count < 1 || cents < count) return null;
  const base = Math.floor(cents / count);
  const extra = cents - base * count;
  return Array.from({ length: count }, (_, index) => fromCents(base + (index < extra ? 1 : 0)));
}

export const sumMarks = (marks: readonly number[]): number => fromCents(marks.reduce((sum, mark) => sum + toCents(mark), 0));

export type MarksProblem = 'totalRequired' | 'totalInvalid' | 'totalTooLarge' | 'tooManyQuestions' | 'markInvalid' | 'sumMismatch';

// Parses text such as "2.5" (a dot or an Arabic decimal comma, no thousands separators). null when it is not a number.
export function parseMarks(text: string): number | null {
  const normalised = text.trim().replace(',', '.');
  if (!/^\d+(\.\d+)?$/.test(normalised)) return null;
  return Number(normalised);
}

export function hasValidDecimals(value: number): boolean {
  return Math.abs(value * 100 - Math.round(value * 100)) < 1e-9;
}

// Checks the total and every question's marks. `entries` are the texts typed for each question.
export function validatePlan(totalText: string, entries: readonly string[]): { problem: MarksProblem | null; index?: number } {
  if (!totalText.trim()) return { problem: 'totalRequired' };
  const total = parseMarks(totalText);
  if (total === null || total <= 0 || !hasValidDecimals(total)) return { problem: 'totalInvalid' };
  if (total > LIMITS.maxMarks * Math.max(entries.length, 1)) return { problem: 'totalTooLarge' };
  if (entries.length > 0 && toCents(total) < entries.length) return { problem: 'tooManyQuestions' };
  const values: number[] = [];
  for (let index = 0; index < entries.length; index++) {
    const value = parseMarks(entries[index]);
    if (value === null || value <= 0 || value > LIMITS.maxMarks || !hasValidDecimals(value)) return { problem: 'markInvalid', index };
    values.push(value);
  }
  if (values.length > 0 && toCents(sumMarks(values)) !== toCents(total)) return { problem: 'sumMismatch' };
  return { problem: null };
}
