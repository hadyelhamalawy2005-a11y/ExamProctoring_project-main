import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { describeError } from '../api/errors';
import { getExam } from '../api/exams';
import { listQuestions } from '../api/questions';
import { CodeAnswerPanel } from '../components/CodeAnswerPanel';
import { Alert, EmptyState, Spinner } from '../components/Feedback';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import { subjectName } from '../data/subjects';
import { getExtras } from '../local/examExtras';
import type { Question } from '../types/api';
import type { CodeQuestion } from '../types/code';
import { formatDuration } from '../utils/dates';

type PreviewItem = { kind: 'server'; question: Question } | { kind: 'code'; question: CodeQuestion };

// "View as student": the exam as a student would see it, built from the same data the exam page loads (two GET requests,
// nothing else). It never creates an attempt, never submits and never writes anything: answers typed here live in this
// page's memory and are gone when it is closed. Correct answers and model answers are never shown.
export function ExamPreviewPage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const { examId = '' } = useParams();
  const exam = useLoader((signal) => getExam(examId, signal), [examId]);
  const questions = useLoader((signal) => listQuestions(examId, signal), [examId]);
  const [extras] = useState(() => getExtras(examId));
  const [index, setIndex] = useState(0);
  const [choices, setChoices] = useState<Record<string, string[]>>({});
  const [essays, setEssays] = useState<Record<string, string>>({});
  const [code, setCode] = useState<Record<string, string>>({});
  const twoDecimals = { minimumFractionDigits: 2, maximumFractionDigits: 2 };

  if ((exam.loading && !exam.data) || (questions.loading && !questions.data)) return <Spinner label={t('preview.loading')} />;

  if (!exam.data || !questions.data) {
    return (
      <div className="page">
        <Alert tone="error">{describeError(exam.error ?? questions.error, i18n)}</Alert>
        <Link to={`/exams/${examId}`}>{t('editor.backToExam')}</Link>
      </div>
    );
  }

  const items: PreviewItem[] = [
    ...questions.data.items.map((question) => ({ kind: 'server' as const, question })),
    ...extras.codeQuestions.map((question) => ({ kind: 'code' as const, question })),
  ];
  const current = items[Math.min(index, items.length - 1)];
  const subject = subjectName(extras.subjectId);
  const answered = (item: PreviewItem) => {
    if (item.kind === 'code') return (code[item.question.id] ?? item.question.starterCode).trim() !== item.question.starterCode.trim();
    return item.question.type === 'Mcq' ? (choices[item.question.id]?.length ?? 0) > 0 : Boolean(essays[item.question.id]?.trim());
  };

  return (
    <div className="page preview-page">
      <div className="preview-banner" role="status">
        <strong>{t('preview.banner')}</strong> {t('preview.bannerBody')}{' '}
        <Link to={`/exams/${examId}`}>{t('editor.backToExam')}</Link>
      </div>

      <section className="card" aria-labelledby="preview-title">
        <h1 id="preview-title" dir="auto">
          {exam.data.title}
        </h1>
        {subject && <p className="muted">{subject}</p>}
        {exam.data.description && <p dir="auto">{exam.data.description}</p>}
        <dl className="details-grid">
          <div>
            <dt>{t('details.duration')}</dt>
            <dd>{formatDuration(exam.data.durationMinutes, t)}</dd>
          </div>
          <div>
            <dt>{t('preview.questions')}</dt>
            <dd>{formatNumber(items.length)}</dd>
          </div>
          <div>
            <dt>{t('preview.totalMarks')}</dt>
            <dd>
              {formatNumber(
                items.reduce((sum, item) => sum + item.question.marks, 0),
                twoDecimals,
              )}
            </dd>
          </div>
        </dl>
      </section>

      {items.length === 0 ? (
        <EmptyState title={t('preview.emptyTitle')}>
          <p>{t('preview.emptyBody')}</p>
        </EmptyState>
      ) : (
        <div className="preview-layout">
          <nav className="preview-palette" aria-label={t('preview.palette')}>
            {items.map((item, at) => (
              <button
                key={item.question.id}
                type="button"
                className={`palette-button ${at === index ? 'palette-current' : ''} ${answered(item) ? 'palette-answered' : ''}`}
                aria-current={at === index ? 'step' : undefined}
                onClick={() => setIndex(at)}
              >
                {formatNumber(at + 1)}
              </button>
            ))}
          </nav>

          <section className="card preview-question" aria-labelledby="preview-q-heading">
            <div className="question-head">
              <h2 id="preview-q-heading">{t('preview.questionOf', { n: formatNumber(index + 1), total: formatNumber(items.length) })}</h2>
              <span className="question-marks">{t('questions.marks', { marks: formatNumber(current.question.marks, twoDecimals) })}</span>
            </div>
            <p className="question-text" dir="auto">
              {current.question.text}
            </p>

            {current.kind === 'server' && current.question.type === 'Mcq' && (() => {
              // The number of correct options decides how a student answers: one -> pick one (radio buttons), several ->
              // pick all that apply (checkboxes). The answer key itself is never shown.
              const question = current.question;
              const multiple = question.options.filter((option) => option.isCorrect).length > 1;
              const chosen = choices[question.id] ?? [];
              return (
                <fieldset className="student-options">
                  <legend className="sr-only">{multiple ? t('preview.chooseMany') : t('preview.choose')}</legend>
                  {multiple && <p className="field-hint">{t('preview.chooseMany')}</p>}
                  {question.options.map((option) => (
                    <label key={option.id} className="student-option">
                      <input
                        type={multiple ? 'checkbox' : 'radio'}
                        name={`preview-${question.id}`}
                        checked={chosen.includes(option.id)}
                        onChange={() =>
                          setChoices({
                            ...choices,
                            [question.id]: multiple
                              ? chosen.includes(option.id)
                                ? chosen.filter((id) => id !== option.id)
                                : [...chosen, option.id]
                              : [option.id],
                          })
                        }
                      />
                      <span dir="auto">{option.text}</span>
                    </label>
                  ))}
                </fieldset>
              );
            })()}

            {current.kind === 'server' && current.question.type === 'Essay' && (
              <div className="field">
                <label htmlFor="preview-essay">{t('preview.yourAnswer')}</label>
                <textarea
                  id="preview-essay"
                  dir="auto"
                  rows={8}
                  value={essays[current.question.id] ?? ''}
                  onChange={(event) => setEssays({ ...essays, [current.question.id]: event.target.value })}
                />
              </div>
            )}

            {current.kind === 'code' && (
              <CodeAnswerPanel
                key={current.question.id}
                examId={examId}
                question={current.question}
                idPrefix={`preview-${current.question.id}`}
                value={code[current.question.id] ?? current.question.starterCode}
                onChange={(value) => setCode((previous) => ({ ...previous, [current.question.id]: value }))}
              />
            )}

            <div className="form-actions">
              <button type="button" className="button button-secondary" disabled={index === 0} onClick={() => setIndex(index - 1)}>
                {t('preview.previous')}
              </button>
              {index < items.length - 1 ? (
                <button type="button" className="button" onClick={() => setIndex(index + 1)}>
                  {t('preview.next')}
                </button>
              ) : (
                <button type="button" className="button" disabled title={t('preview.submitDisabled')}>
                  {t('preview.submit')}
                </button>
              )}
            </div>
            {index === items.length - 1 && <p className="field-hint">{t('preview.submitDisabled')}</p>}
          </section>
        </div>
      )}
    </div>
  );
}
