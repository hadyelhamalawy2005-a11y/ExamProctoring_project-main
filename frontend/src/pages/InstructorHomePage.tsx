import { Link } from 'react-router-dom';
import { describeError } from '../api/errors';
import { listExams } from '../api/exams';
import { useAuth } from '../auth/AuthContext';
import { Alert, PageLoader } from '../components/Feedback';
import { Icon, type IconName } from '../components/Icon';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import type { ExamStatus } from '../types/api';

// Finished has no card here: the backend cannot count it yet (see docs/Frontend_Pending_Backend.md).
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

  const statIcon: Record<ExamStatus, IconName> = { Draft: 'edit', Published: 'shieldCheck', Cancelled: 'ban', Finished: 'award' };

  return (
    <div className="page">
      {session && (
        <section className="hero pattern">
          <p className="overline">{t(`role.${session.user.role}`)}</p>
          <h1>{t('home.welcome', { name: session.user.fullName })}</h1>
          <p>{t('home.heroBody')}</p>
          <div className="hero-actions">
            <Link to="/exams/new/method" className="button">
              <Icon name="add" size={18} />
              {t('list.createExam')}
            </Link>
            <Link to="/import" className="button button-secondary">
              <Icon name="uploadFile" size={18} />
              {t('nav.import')}
            </Link>
          </div>
        </section>
      )}

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
        <div className="stat-grid">
          {STATUSES.map((status) => (
            <Link key={status} to={`/exams?status=${status}`} className="stat-card" data-testid={`count-${status}`}>
              <span className="sr-only">{t('home.countLine', { label: t(`status.${status}`), n: formatNumber(counts.data![status]) })}</span>
              <span className="stat-card-head" aria-hidden="true">
                <Icon name={statIcon[status]} size={20} />
                {t(`status.${status}`)}
              </span>
              <span className="stat-value" aria-hidden="true">
                {formatNumber(counts.data![status])}
              </span>
            </Link>
          ))}
        </div>
      )}

      <div className="action-grid">
        <div className="card notice-card">
          <span className="feature-tile feature-tile-gold" aria-hidden="true">
            <Icon name="examSheet" size={22} />
          </span>
          <div>
            <h3>{t('home.attempts')}</h3>
            <p className="muted">{t('home.attemptsUnavailable')}</p>
          </div>
        </div>
        <div className="card notice-card">
          <span className="feature-tile" aria-hidden="true">
            <Icon name="flag" size={22} />
          </span>
          <div>
            <h3>{t('nav.incidents')}</h3>
            <p className="muted">{t('home.incidentsUnavailable')}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
