import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ApiError, describeError } from '../api/errors';
import { createQuestion, deleteQuestion, listQuestions, updateQuestion } from '../api/questions';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import type { TranslationKey } from '../i18n/en';
import { getExtras, newLocalId, removeCodeQuestion, saveExtras, upsertCodeQuestion, type ExamExtras, type QuestionMethod } from '../local/examExtras';
import type { Exam, Question, QuestionRequest, QuestionType } from '../types/api';
import { emptyCodeQuestion, type CodeQuestion } from '../types/code';
import { CodeQuestionForm } from './CodeQuestionForm';
import { ConfirmDialog } from './ConfirmDialog';
import { Alert, EmptyState, Spinner } from './Feedback';
import { MarksPlanner } from './MarksPlanner';
import { QuestionForm } from './QuestionForm';

interface QuestionsPanelProps {
  exam: Exam;
  // The exam may have changed on the server (for example it started or was cancelled): reload it.
  onExamStale(): void;
}

// What the last write produced. Errors are kept as errors (not text) so they follow the active language.
type NewKind = QuestionType | 'Code';

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
  const navigate = useNavigate();
  // Browser-only settings of this exam (see local/examExtras.ts): how questions are entered, and the code questions.
  const [extras, setExtras] = useState<ExamExtras>(() => getExtras(exam.id));
  const [newKind, setNewKind] = useState<NewKind>('Mcq');
  const [editingCode, setEditingCode] = useState<CodeQuestion | null>(null);
  const [codeToDelete, setCodeToDelete] = useState<CodeQuestion | null>(null);

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
  const codeQuestions = extras.codeQuestions;
  const totalMarks = items.reduce((sum, question) => sum + question.marks, 0) + codeQuestions.reduce((sum, question) => sum + question.marks, 0);
  const questionCount = items.length + codeQuestions.length;

  const chooseMethod = (chosen: QuestionMethod) => {
    setExtras(saveExtras(exam.id, { method: chosen }));
    if (chosen === 'word') navigate(`/import?examId=${encodeURIComponent(exam.id)}`);
    else setEditing('new');
  };

  const saveCode = (question: CodeQuestion) => {
    setExtras(upsertCodeQuestion(exam.id, question));
    setEditingCode(null);
    setEditing(null);
    setOutcome({ tone: 'success', text: 'questions.saved' });
  };

  const confirmDeleteCode = () => {
    if (!codeToDelete) return;
    setExtras(removeCodeQuestion(exam.id, codeToDelete.id));
    setCodeToDelete(null);
    setOutcome({ tone: 'success', text: 'questions.deleted' });
  };

  // The method is chosen once. Until then (and only for an exam with no questions) the choice is offered.
  const method = extras.method ?? (questionCount > 0 ? 'manual' : null);

  return (
    <section className="card" aria-labelledby="questions-heading">
      <div className="section-header">
        <div>
          <h2 id="questions-heading">{t('questions.title')}</h2>
          {questions.data && (
            <p className="muted">
              {t('questions.summary', {
                count: questionCount === 1 ? t('questions.countOne', { n: 1 }) : t('questions.countMany', { n: formatNumber(questionCount) }),
                marks: formatNumber(totalMarks, twoDecimals),
              })}
            </p>
          )}
        </div>
        <div className="button-row">
          <Link className="button button-secondary" to={`/exams/${encodeURIComponent(exam.id)}/preview`}>
            {t('preview.action')}
          </Link>
          {editable && editing !== 'new' && method !== null && (
            <>
              {method === 'word' ? (
                <Link className="button" to={`/import?examId=${encodeURIComponent(exam.id)}`}>
                  {t('nav.import')}
                </Link>
              ) : (
                <button
                  type="button"
                  className="button"
                  onClick={() => {
                    setNewKind('Mcq');
                    setEditing('new');
                  }}
                >
                  {t('questions.add')}
                </button>
              )}
            </>
          )}
        </div>
      </div>

      {editable && method !== null && editing !== 'new' && (
        <p className="muted method-note">
          {method === 'word' ? t('method.usingWord') : t('method.usingManual')}{' '}
          <button type="button" className="link-button" onClick={() => setExtras(saveExtras(exam.id, { method: method === 'word' ? 'manual' : 'word' }))}>
            {method === 'word' ? t('method.switchManual') : t('method.switchWord')}
          </button>
        </p>
      )}

      {!editable && (
        <p className="muted">{exam.status === 'Cancelled' ? t('questions.readOnlyCancelled') : t('questions.readOnlyStarted')}</p>
      )}

      {outcome && (
        <Alert tone={outcome.tone} onDismiss={() => setOutcome(null)}>
          {outcome.tone === 'success' ? t(outcome.text) : describeError(outcome.error, i18n)}
        </Alert>
      )}

      {editable && method === null && !questions.loading && editing !== 'new' && (
        <div className="method-chooser" role="group" aria-labelledby="method-heading">
          <h3 id="method-heading">{t('method.title')}</h3>
          <p className="muted">{t('method.intro')}</p>
          <div className="button-row">
            <button type="button" className="button" onClick={() => chooseMethod('manual')}>
              {t('method.manual')}
            </button>
            <button type="button" className="button button-secondary" onClick={() => chooseMethod('word')}>
              {t('method.word')}
            </button>
          </div>
        </div>
      )}

      {editing === 'new' && (
        <div className="question-editor">
          <h3>{t('questions.newHeading')}</h3>
          <div className="type-picker" role="group" aria-label={t('qform.type')}>
            {(['Mcq', 'Essay', 'Code'] as const).map((kind) => (
              <button
                key={kind}
                type="button"
                className={`button ${newKind === kind ? '' : 'button-secondary'}`}
                aria-pressed={newKind === kind}
                onClick={() => setNewKind(kind)}
              >
                {t(`questions.type${kind}`)}
              </button>
            ))}
          </div>
          {newKind === 'Code' ? (
            <CodeQuestionForm question={emptyCodeQuestion(newLocalId())} onSubmit={saveCode} onCancel={() => setEditing(null)} />
          ) : (
            <QuestionForm key={newKind} lockedType={newKind} onSubmit={(request) => save(request)} onCancel={() => setEditing(null)} />
          )}
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

      {questions.data && questionCount === 0 && editing !== 'new' && method !== null && (
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
                {question.type === 'Mcq' && question.options.filter((option) => option.isCorrect).length > 1 && (
                  <span className="muted">{t('questions.multipleAnswers')}</span>
                )}
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

      {codeQuestions.length > 0 && (
        <div className="code-questions">
          <h3>{t('questions.codeHeading')}</h3>
          <p className="muted">{t('code.localNotice')}</p>
          <ol className="question-list" start={items.length + 1}>
            {codeQuestions.map((question) =>
              editingCode?.id === question.id ? (
                <li key={question.id} className="question-item question-editor">
                  <CodeQuestionForm question={editingCode} onSubmit={saveCode} onCancel={() => setEditingCode(null)} />
                </li>
              ) : (
                <li key={question.id} className="question-item">
                  <div className="question-head">
                    <span className="badge badge-neutral">{t('questions.typeCode')}</span>
                    <span className="question-marks">{t('questions.marks', { marks: formatNumber(question.marks, twoDecimals) })}</span>
                    <span className="badge badge-neutral">{question.autoCompletionEnabled ? t('code.autocompleteOn') : t('code.autocompleteOff')}</span>
                  </div>
                  <p className="question-text" dir="auto">
                    {question.text}
                  </p>
                  {editable && (
                    <div className="button-row">
                      <button type="button" className="button button-secondary button-small" onClick={() => setEditingCode(question)}>
                        {t('questions.edit')}
                      </button>
                      <button type="button" className="button button-danger-outline button-small" onClick={() => setCodeToDelete(question)}>
                        {t('common.delete')}
                      </button>
                    </div>
                  )}
                </li>
              ),
            )}
          </ol>
        </div>
      )}

      {editable && questions.data && questionCount > 0 && (
        <MarksPlanner
          examId={exam.id}
          questions={items}
          codeQuestions={codeQuestions}
          totalMarks={extras.totalMarks}
          onTotalChange={(total) => setExtras(saveExtras(exam.id, { totalMarks: total }))}
          onSaved={() => {
            setExtras(getExtras(exam.id));
            questions.reload();
          }}
        />
      )}

      <ConfirmDialog
        open={codeToDelete !== null}
        title={t('questions.deleteTitle')}
        confirmLabel={t('common.delete')}
        tone="danger"
        onConfirm={confirmDeleteCode}
        onCancel={() => setCodeToDelete(null)}
      >
        <p>{t('questions.deleteCodeBody')}</p>
      </ConfirmDialog>

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
