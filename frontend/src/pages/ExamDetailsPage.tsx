import { useState } from 'react';
import { Link, useLocation, useNavigate, useParams } from 'react-router-dom';
import { describeError } from '../api/errors';
import { getExam } from '../api/exams';
import { ExamActions } from '../components/ExamActions';
import { Alert, Spinner } from '../components/Feedback';
import { QuestionsPanel } from '../components/QuestionsPanel';
import { PhaseBadge, StatusBadge } from '../components/StatusBadge';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import { formatDuration } from '../utils/dates';

type NoticeCode = 'created' | 'saved';

// GET /api/exams/{id} with the lifecycle actions and the question list.
export function ExamDetailsPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const { examId = '' } = useParams();
  const navigate = useNavigate();
  const location = useLocation();
  // The notice is passed as a code (not as text) so it is shown in the language that is active when it is displayed.
  const [notice, setNotice] = useState<NoticeCode | null>((location.state as { notice?: NoticeCode } | null)?.notice ?? null);
  const exam = useLoader((signal) => getExam(examId, signal), [examId]);

  if (exam.loading && !exam.data) return <Spinner label={t('details.loading')} />;

  if (!exam.data) {
    return (
      <div className="page">
        <Alert tone="error">{describeError(exam.error, i18n)}</Alert>
        <Link to="/exams">{t('common.backToExams')}</Link>
      </div>
    );
  }

  const data = exam.data;

  return (
    <div className="page">
      <p>
        <Link to="/exams">
          <span className="icon-flip" aria-hidden="true">
            ←
          </span>{' '}
          {t('details.back')}
        </Link>
      </p>

      {notice && (
        <Alert tone="success" onDismiss={() => setNotice(null)}>
          {t(`notice.${notice}`)}
        </Alert>
      )}
      {exam.error != null && <Alert tone="error">{describeError(exam.error, i18n)}</Alert>}

      <section className="card" aria-labelledby="exam-heading">
        <div className="section-header">
          <div>
            <h1 id="exam-heading" dir="auto">
              {data.title}
            </h1>
            <div className="badge-row">
              <StatusBadge status={data.status} />
              <PhaseBadge phase={data.phase} />
              {exam.loading && <Spinner label={t('details.refreshing')} />}
            </div>
          </div>
        </div>

        {data.description && (
          <p className="exam-description" dir="auto">
            {data.description}
          </p>
        )}

        <dl className="details-grid">
          <div>
            <dt>{t('details.starts')}</dt>
            <dd>{formatDateTime(data.startsAt)}</dd>
          </div>
          <div>
            <dt>{t('details.ends')}</dt>
            <dd>{formatDateTime(data.endsAt)}</dd>
          </div>
          <div>
            <dt>{t('details.duration')}</dt>
            <dd>{formatDuration(data.durationMinutes, t)}</dd>
          </div>
          <div>
            <dt>{t('details.published')}</dt>
            <dd>{data.publishedAt ? formatDateTime(data.publishedAt) : t('details.notPublished')}</dd>
          </div>
          <div>
            <dt>{t('details.warningLimit')}</dt>
            <dd>{t('details.warningValue', { n: formatNumber(data.warningLimit) })}</dd>
          </div>
        </dl>

        <ExamActions
          exam={data}
          onChanged={(updated) => exam.setData(updated)}
          onDeleted={() => navigate('/exams', { replace: true })}
          onStale={exam.reload}
        />
      </section>

      <QuestionsPanel exam={data} onExamStale={exam.reload} />
    </div>
  );
}
