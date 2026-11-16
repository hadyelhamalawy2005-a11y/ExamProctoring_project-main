import { useEffect, useMemo, useState } from 'react';
import { describeError } from '../api/errors';
import { updateQuestion } from '../api/questions';
import { useI18n } from '../i18n/LanguageContext';
import { upsertCodeQuestion } from '../local/examExtras';
import type { Question, QuestionRequest } from '../types/api';
import type { CodeQuestion } from '../types/code';
import { distributeMarks, parseMarks, sumMarks, validatePlan, type MarksProblem } from '../utils/marks';
import { Alert } from './Feedback';

interface MarksPlannerProps {
  examId: string;
  questions: Question[];
  codeQuestions: CodeQuestion[];
  totalMarks: number | null;
  onTotalChange(total: number | null): void;
  onSaved(): void; // marks were written: reload the list
}

interface Row {
  id: string;
  label: string;
  kind: 'server' | 'code';
  marks: number;
}

const toRequest = (question: Question, marks: number): QuestionRequest => ({
  type: question.type,
  text: question.text,
  marks,
  modelAnswer: question.modelAnswer,
  options: question.options.map((option) => ({ text: option.text, isCorrect: option.isCorrect })),
});

const problemKey = (problem: MarksProblem) => `marks.problem.${problem}` as const;

// The teacher sets the exam's total marks first; "Distribute equally" splits it between all questions (decimals
// allowed, always adding up exactly), and each question can then be adjusted by hand. Saving is refused unless the
// questions add up to the total. Marks of MCQ and Essay questions are written to the backend one question at a time
// (PUT /api/questions/{id}); marks of code questions are kept in this browser with the question.
export function MarksPlanner({ examId, questions, codeQuestions, totalMarks, onTotalChange, onSaved }: MarksPlannerProps) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const rows = useMemo<Row[]>(
    () => [
      ...questions.map((question) => ({ id: question.id, label: `Q${question.position}`, kind: 'server' as const, marks: question.marks })),
      ...codeQuestions.map((question, index) => ({ id: question.id, label: `Q${questions.length + index + 1}`, kind: 'code' as const, marks: question.marks })),
    ],
    [questions, codeQuestions],
  );
  const signature = rows.map((row) => `${row.id}:${row.marks}`).join('|');
  const [totalText, setTotalText] = useState(totalMarks === null ? '' : String(totalMarks));
  const [entries, setEntries] = useState<string[]>(rows.map((row) => String(row.marks)));
  const [busy, setBusy] = useState(false);
  const [saved, setSaved] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);

  // The questions changed (added, deleted, reloaded): start again from what is stored.
  useEffect(() => {
    setEntries(rows.map((row) => String(row.marks)));
    setSaved(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [signature]);

  const plan = validatePlan(totalText, entries);
  const typedSum = entries.every((entry) => parseMarks(entry) !== null) ? sumMarks(entries.map((entry) => parseMarks(entry)!)) : null;
  const total = parseMarks(totalText);
  const difference = typedSum !== null && total !== null ? Math.round((typedSum - total) * 100) / 100 : null;
  const changed = entries.some((entry, index) => parseMarks(entry) !== rows[index]?.marks);
  const twoDecimals = { minimumFractionDigits: 2, maximumFractionDigits: 2 };

  const setTotal = (text: string) => {
    setTotalText(text);
    setSaved(false);
    const value = parseMarks(text);
    onTotalChange(value !== null && value > 0 ? value : null);
  };

  const distribute = () => {
    const parts = total === null ? null : distributeMarks(total, rows.length);
    if (!parts) return;
    setEntries(parts.map(String));
    setSaved(false);
  };

  const save = async () => {
    setBusy(true);
    setFailure(null);
    try {
      for (let index = 0; index < rows.length; index++) {
        const marks = parseMarks(entries[index])!;
        if (marks === rows[index].marks) continue;
        if (rows[index].kind === 'server') {
          await updateQuestion(rows[index].id, toRequest(questions.find((question) => question.id === rows[index].id)!, marks));
        } else {
          upsertCodeQuestion(examId, { ...codeQuestions.find((question) => question.id === rows[index].id)!, marks });
        }
      }
      setSaved(true);
      onSaved();
    } catch (error) {
      setFailure(error);
      onSaved(); // some questions may have been written before the failure: show the server's marks
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="marks-planner" aria-labelledby="marks-heading">
      <h3 id="marks-heading">{t('marks.title')}</h3>
      <p className="muted">{t('marks.intro')}</p>

      <div className="marks-total">
        <label htmlFor="marks-total-input">{t('marks.total')}</label>
        <input id="marks-total-input" dir="ltr" inputMode="decimal" value={totalText} onChange={(event) => setTotal(event.target.value)} aria-invalid={plan.problem === 'totalInvalid' || plan.problem === 'totalRequired'} />
        <button type="button" className="button button-secondary" onClick={distribute} disabled={rows.length === 0 || total === null || !distributeMarks(total, rows.length)}>
          {t('marks.distribute')}
        </button>
      </div>

      {rows.length > 0 && (
        <ul className="marks-rows">
          {rows.map((row, index) => (
            <li key={row.id}>
              <label htmlFor={`marks-${row.id}`}>
                {row.label}
                {row.kind === 'code' && <span className="badge badge-neutral">{t('questions.typeCode')}</span>}
              </label>
              <input
                id={`marks-${row.id}`}
                dir="ltr"
                inputMode="decimal"
                value={entries[index] ?? ''}
                onChange={(event) => {
                  setEntries((previous) => previous.map((entry, at) => (at === index ? event.target.value : entry)));
                  setSaved(false);
                }}
                aria-invalid={plan.problem === 'markInvalid' && plan.index === index}
              />
            </li>
          ))}
        </ul>
      )}

      {rows.length > 0 && typedSum !== null && total !== null && (
        <p className={difference === 0 ? 'marks-ok' : 'field-error'} role="status" data-testid="marks-sum">
          {difference === 0
            ? t('marks.sumOk', { sum: formatNumber(typedSum, twoDecimals), total: formatNumber(total, twoDecimals) })
            : t('marks.sumDiff', { sum: formatNumber(typedSum, twoDecimals), total: formatNumber(total, twoDecimals) })}
        </p>
      )}
      {plan.problem && plan.problem !== 'sumMismatch' && totalText.trim() !== '' && <p className="field-error">{t(problemKey(plan.problem))}</p>}
      {failure != null && <Alert tone="error">{describeError(failure, i18n)}</Alert>}
      {saved && <Alert tone="success">{t('marks.saved')}</Alert>}

      {rows.length > 0 && (
        <div className="form-actions">
          <button type="button" className="button" onClick={() => void save()} disabled={busy || plan.problem !== null || !changed}>
            {busy ? t('common.saving') : t('marks.save')}
          </button>
        </div>
      )}
    </section>
  );
}
