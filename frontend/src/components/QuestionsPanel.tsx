import { useState } from 'react';
import { Link } from 'react-router-dom';
import { ApiError, describeError } from '../api/errors';
import { createQuestion, deleteQuestion, listQuestions, updateQuestion } from '../api/questions';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import type { TranslationKey } from '../i18n/en';
import type { Exam, Question, QuestionRequest } from '../types/api';
import { ConfirmDialog } from './ConfirmDialog';
import { Alert, EmptyState, Spinner } from './Feedback';
import { QuestionForm } from './QuestionForm';

interface QuestionsPanelProps {
  exam: Exam;
  // The exam may have changed on the server (for example it started or was cancelled): reload it.
  onExamStale(): void;
}

// What the last write produced. Errors are kept as errors (not text) so they follow the active language.
type Outcome = { tone: 'success'; text: TranslationKey } | { tone: 'error'; error: unknown };

// Questions can be read at any time. Writes are allowed only while the exam is Draft or Published and has not started;
// the server checks this on every write and answers 409 exam_not_editable otherwise.
export function QuestionsPanel({ exam, onExamStale }: QuestionsPanelProps) {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const questions = useLoader((signal) => listQuestions(exam.id, signal), [exam.id]);
  const [editing, setEditing] = useState<string | 'new' | null>(null);
  const [toDelete, setToDelete] = useState<Question | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [outcome, setOutcome] = useState<Outcome | null>(null);

  const editable = exam.phase === 'Upcoming' && exam.status !== 'Cancelled';
  const twoDecimals = { minimumFractionDigits: 2, maximumFractionDigits: 2 };

  const afterWrite = (text: TranslationKey) => {
    setEditing(null);
    setOutcome({ tone: 'success', text });
    questions.reload(); // positions may have changed: show the server's list
  };

  const handleFailure = (error: unknown) => {
    if (error instanceof ApiError && (error.status === 409 || error.status === 404)) onExamStale();
    throw error; // the form shows the message and field errors
  };

  const save = async (request: QuestionRequest, question?: Question) => {
    try {
      if (question) await updateQuestion(question.id, request);
      else await createQuestion(exam.id, request);
      afterWrite(question ? 'questions.saved' : 'questions.added');
    } catch (error) {
      handleFailure(error);
    }
  };

  const confirmDelete = async () => {
    if (!toDelete) return;
    setDeleting(true);
    try {
      await deleteQuestion(toDelete.id);
      setToDelete(null);
      afterWrite('questions.deleted');
    } catch (error) {
      setToDelete(null);
      setOutcome({ tone: 'error', error });
      if (error instanceof ApiError && (error.status === 409 || error.status === 404)) onExamStale();
    } finally {
      setDeleting(false);
    }
  };

  const items = questions.data?.items ?? [];
  const totalMarks = items.reduce((sum, question) => sum + question.marks, 0);

  return (
    <section className="card" aria-labelledby="questions-heading">
      <div className="section-header">
        <div>
          <h2 id="questions-heading">{t('questions.title')}</h2>
          {questions.data && (
            <p className="muted">
              {t('questions.summary', {
                count: items.length === 1 ? t('questions.countOne', { n: 1 }) : t('questions.countMany', { n: formatNumber(items.length) }),
                marks: formatNumber(totalMarks, twoDecimals),
              })}
            </p>
          )}
        </div>
        {editable && editing !== 'new' && (
          <div className="button-row">
            <Link className="button button-secondary" to={`/import?examId=${encodeURIComponent(exam.id)}`}>
              {t('nav.import')}
            </Link>
            <button type="button" className="button" onClick={() => setEditing('new')}>
              {t('questions.add')}
            </button>
          </div>
        )}
      </div>

      {!editable && (
        <p className="muted">{exam.status === 'Cancelled' ? t('questions.readOnlyCancelled') : t('questions.readOnlyStarted')}</p>
      )}

      {outcome && (
        <Alert tone={outcome.tone} onDismiss={() => setOutcome(null)}>
          {outcome.tone === 'success' ? t(outcome.text) : describeError(outcome.error, i18n)}
        </Alert>
      )}

      {editing === 'new' && (
        <div className="question-editor">
          <h3>{t('questions.newHeading')}</h3>
          <QuestionForm onSubmit={(request) => save(request)} onCancel={() => setEditing(null)} />
        </div>
      )}

      {questions.loading && !questions.data && <Spinner label={t('questions.loading')} />}
      {questions.error != null && (
        <Alert tone="error">
          {describeError(questions.error, i18n)}{' '}
          <button type="button" className="link-button" onClick={questions.reload}>
            {t('common.tryAgain')}
          </button>
        </Alert>
      )}

      {questions.data && items.length === 0 && editing !== 'new' && (
        <EmptyState title={t('questions.emptyTitle')}>
          <p>{editable ? t('questions.emptyEditable') : t('questions.emptyReadOnly')}</p>
        </EmptyState>
      )}

      <ol className="question-list">
        {items.map((question) =>
          editing === question.id ? (
            <li key={question.id} className="question-item question-editor">
              <h3>{t('questions.editHeading', { n: formatNumber(question.position) })}</h3>
              <QuestionForm question={question} onSubmit={(request) => save(request, question)} onCancel={() => setEditing(null)} />
            </li>
          ) : (
            <li key={question.id} className="question-item">
              <div className="question-head">
                <span className="question-number">Q{formatNumber(question.position)}</span>
                <span className="badge badge-neutral">{question.type === 'Mcq' ? t('questions.typeMcq') : t('questions.typeEssay')}</span>
                <span className="question-marks">{t('questions.marks', { marks: formatNumber(question.marks, twoDecimals) })}</span>
              </div>
              <p className="question-text" dir="auto">
                {question.text}
              </p>
              {question.type === 'Mcq' && (
                <ul className="option-list">
                  {question.options.map((option) => (
                    <li key={option.id} className={option.isCorrect ? 'option-correct' : undefined}>
                      <span dir="auto">{option.text}</span>
                      {option.isCorrect && <span className="sr-only"> {t('questions.correctSr')}</span>}
                      {option.isCorrect && <span aria-hidden="true"> ✓</span>}
                    </li>
                  ))}
                </ul>
              )}
              {question.modelAnswer && (
                <p className="model-answer">
                  <strong>{t('questions.modelAnswer')}</strong> <span dir="auto">{question.modelAnswer}</span>
                </p>
              )}
              {editable && (
                <div className="button-row">
                  <button type="button" className="button button-secondary button-small" onClick={() => setEditing(question.id)}>
                    {t('questions.edit')}
                  </button>
                  <button type="button" className="button button-danger-outline button-small" onClick={() => setToDelete(question)}>
                    {t('common.delete')}
                  </button>
                </div>
              )}
            </li>
          ),
        )}
      </ol>

      <ConfirmDialog
        open={toDelete !== null}
        title={t('questions.deleteTitle')}
        confirmLabel={t('common.delete')}
        tone="danger"
        busy={deleting}
        onConfirm={() => void confirmDelete()}
        onCancel={() => setToDelete(null)}
      >
        <p>
          {t('questions.deleteBody', { n: formatNumber(toDelete?.position ?? 0) })}
          {exam.status === 'Published' && ` ${t('questions.deletePublishedNote')}`}
        </p>
      </ConfirmDialog>
    </section>
  );
}
