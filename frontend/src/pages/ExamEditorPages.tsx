import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { createExam, getExam, updateExam } from '../api/exams';
import { ApiError, describeError } from '../api/errors';
import { ExamForm } from '../components/ExamForm';
import { Alert, Spinner } from '../components/Feedback';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import type { ExamRequest } from '../types/api';

// POST /api/exams: a new exam always starts as a Draft.
export function CreateExamPage() {
  const { t } = useI18n();
  const navigate = useNavigate();
  return (
    <div className="page page-narrow">
      <h1>{t('editor.newTitle')}</h1>
      <p className="muted">{t('editor.newIntro')}</p>
      <ExamForm
        submitLabel={t('editor.create')}
        onSubmit={async (request) => {
          const exam = await createExam(request);
          navigate(`/exams/${exam.id}`, { replace: true, state: { notice: 'created' } });
        }}
        onCancel={() => navigate('/exams')}
      />
    </div>
  );
}

// PUT /api/exams/{id}: allowed for Draft and Published exams before they start.
export function EditExamPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const { examId = '' } = useParams();
  const navigate = useNavigate();
  const exam = useLoader((signal) => getExam(examId, signal), [examId]);
  // The 404 / 409 that refused the last save (kept as the error so its text follows the active language).
  const [refusal, setRefusal] = useState<ApiError | null>(null);
  const notFound = exam.error instanceof ApiError && exam.error.status === 404;

  // The server is the authority: after a 404 or 409 the exam is loaded again. The form keeps what the user typed while
  // the exam can still be edited; once it can't be edited (started, cancelled, gone) the form is replaced by the
  // explanation, so nobody stays on a form that can never be saved.
  const save = async (request: ExamRequest) => {
    setRefusal(null);
    try {
      await updateExam(examId, request);
    } catch (error) {
      if (error instanceof ApiError && (error.status === 404 || error.status === 409)) {
        setRefusal(error);
        exam.reload();
        return;
      }
      throw error; // 400 field errors and other failures are shown by the form itself
    }
    navigate(`/exams/${examId}`, { replace: true, state: { notice: 'saved' } });
  };

  return (
    <div className="page page-narrow">
      <p>
        <Link to={`/exams/${examId}`}>
          <span className="icon-flip" aria-hidden="true">
            ←
          </span>{' '}
          {t('editor.backToExam')}
        </Link>
      </p>
      <h1>{t('editor.editTitle')}</h1>
      {exam.loading && !exam.data && <Spinner label={t('details.loading')} />}
      {refusal && <Alert tone="error">{describeError(refusal, i18n)}</Alert>}
      {exam.error != null && !(refusal && notFound) && <Alert tone="error">{describeError(exam.error, i18n)}</Alert>}
      {exam.data && (exam.data.phase !== 'Upcoming' || exam.data.status === 'Cancelled') && (
        <Alert tone="info">{exam.data.status === 'Cancelled' ? t('editor.cannotEditCancelled') : t('editor.cannotEditStarted')}</Alert>
      )}
      {exam.data && exam.data.phase === 'Upcoming' && exam.data.status !== 'Cancelled' && !notFound && (
        <ExamForm exam={exam.data} submitLabel={t('editor.save')} onSubmit={save} onCancel={() => navigate(`/exams/${examId}`)} />
      )}
      {notFound && <Link to="/exams">{t('common.backToExams')}</Link>}
    </div>
  );
}
