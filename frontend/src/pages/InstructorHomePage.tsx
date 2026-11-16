import { Link } from 'react-router-dom';
import { describeError } from '../api/errors';
import { listExams } from '../api/exams';
import { useAuth } from '../auth/AuthContext';
import { Alert, PageLoader } from '../components/Feedback';
import { Icon } from '../components/Icon';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import type { ExamStatus } from '../types/api';

const STATUSES: ExamStatus[] = ['Draft', 'Published', 'Cancelled'];

// The instructor's home: a welcome card, the create button, and how many exams there are per status. The counts are the
// real totals from GET /api/exams (one call per status, page size 1). Attempts and incidents have no server endpoints, so
// those sections say so instead of showing zeros.
export function InstructorHomePage() {
  const i18n = useI18n();
  const { t, formatNumber } = i18n;
  const { session } = useAuth();
  const counts = useLoader(
    async (signal) => {
      const pages = await Promise.all(STATUSES.map((status) => listExams({ status, page: 1, pageSize: 1 }, signal)));
      return Object.fromEntries(STATUSES.map((status, index) => [status, pages[index].totalCount])) as Record<ExamStatus, number>;
    },
    [],
  );

  return (
    <div className="page">
      {session && (
        <div className="card">
          <h1>{t('home.welcome', { name: session.user.fullName })}</h1>
          <p className="muted">{t(`role.${session.user.role}`)}</p>
        </div>
      )}

      <Link to="/exams/new/method" className="button button-block">
        <Icon name="add" size={18} />
        {t('list.createExam')}
      </Link>

      <Link to="/import" className="button button-secondary button-block">
        <Icon name="uploadFile" size={18} />
        {t('nav.import')}
      </Link>

      <h2 className="section-title">{t('home.yourExams')}</h2>
      {counts.loading && !counts.data && <PageLoader label={t('list.loading')} />}
      {counts.error != null && (
        <Alert tone="error">
          {describeError(counts.error, i18n)}{' '}
          <button type="button" className="link-button" onClick={counts.reload}>
            {t('common.tryAgain')}
          </button>
        </Alert>
      )}
      {counts.data && (
        <div className="count-row">
          {STATUSES.map((status) => (
            <span key={status} data-testid={`count-${status}`}>
              {t('home.countLine', { label: t(`status.${status}`), n: formatNumber(counts.data![status]) })}
            </span>
          ))}
        </div>
      )}

      <h2 className="section-title">{t('home.attempts')}</h2>
      <p className="muted">{t('home.attemptsUnavailable')}</p>
      <h2 className="section-title">{t('nav.incidents')}</h2>
      <p className="muted">{t('home.incidentsUnavailable')}</p>
    </div>
  );
}
