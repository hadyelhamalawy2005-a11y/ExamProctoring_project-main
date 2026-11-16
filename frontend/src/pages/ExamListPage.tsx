import { Link, useSearchParams } from 'react-router-dom';
import { describeError } from '../api/errors';
import { finishedStatusSupported, listExams } from '../api/exams';
import { Chip } from '../components/Chip';
import { Alert, EmptyState, PageLoader } from '../components/Feedback';
import { Icon } from '../components/Icon';
import { Pagination } from '../components/Pagination';
import { PhaseBadge, StatusBadge } from '../components/StatusBadge';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import type { ExamPage, ExamStatus } from '../types/api';
import { formatDuration } from '../utils/dates';

const STATUSES: ExamStatus[] = ['Draft', 'Published', 'Cancelled', 'Finished'];
const PAGE_SIZE = 10; // the backend default

// GET /api/exams: the instructor's own exams, newest start first, paged, with an optional status filter. Laid out like the
// mobile app's exam list: a create button, status chips, one card per exam, then "Showing n of N" and the pager. Filter
// and page live in the URL so the browser's back button works.
export function ExamListPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const [params, setParams] = useSearchParams();
  const status = STATUSES.find((value) => value === params.get('status'));
  const page = Math.max(1, Number.parseInt(params.get('page') ?? '1', 10) || 1);

  // Until the backend reports Finished, asking it for that status would only be refused: show the empty tab and say why.
  const finishedPending = status === 'Finished' && !finishedStatusSupported();
  const exams = useLoader(
    (signal) => (finishedPending ? Promise.resolve<ExamPage>({ items: [], page: 1, pageSize: PAGE_SIZE, totalCount: 0 }) : listExams({ status, page, pageSize: PAGE_SIZE }, signal)),
    [status, page, finishedPending],
  );

  const setQuery = (changes: Record<string, string | undefined>) => {
    const next = new URLSearchParams(params);
    Object.entries(changes).forEach(([key, value]) => (value ? next.set(key, value) : next.delete(key)));
    setParams(next);
  };

  return (
    <div className="page">
      <Link to="/exams/new/method" className="button button-block">
        <Icon name="add" size={18} />
        {t('list.createExam')}
      </Link>

      <div className="chips" role="group" aria-label={t('list.status')}>
        <Chip selected={!status} onClick={() => setQuery({ status: undefined, page: undefined })}>
          {t('list.all')}
        </Chip>
        {STATUSES.map((value) => (
          <Chip key={value} selected={status === value} onClick={() => setQuery({ status: value, page: undefined })}>
            {t(`status.${value}`)}
          </Chip>
        ))}
      </div>

      {exams.error != null && (
        <Alert tone="error">
          {describeError(exams.error, i18n)}{' '}
          <button type="button" className="link-button" onClick={exams.reload}>
            {t('common.tryAgain')}
          </button>
        </Alert>
      )}

      {exams.loading && !exams.data && <PageLoader label={t('list.loading')} />}

      {exams.data && exams.data.items.length === 0 && (
        <EmptyState icon="assignmentOutline" title={status ? t('list.emptyFiltered', { status: t(`status.${status}`) }) : t('list.emptyNone')}>
          {finishedPending ? <p>{t('list.finishedPending')}</p> : exams.data.totalCount > 0 ? <p>{t('list.pastEnd')}</p> : <p>{t('list.createFirst')}</p>}
        </EmptyState>
      )}

      {exams.data && exams.data.items.length > 0 && (
        <>
          <div className="card-list">
            {exams.data.items.map((exam) => (
              <Link key={exam.id} to={`/exams/${exam.id}`} className="card item-card">
                <h2>
                  <bdi>{exam.title}</bdi>
                </h2>
                <p>
                  {formatDateTime(exam.startsAt)} · {formatDuration(exam.durationMinutes, t)}
                </p>
                {exam.description && (
                  <p className="muted truncate">
                    <bdi>{exam.description}</bdi>
                  </p>
                )}
                <div className="badge-row">
                  <StatusBadge status={exam.status} />
                  <PhaseBadge phase={exam.phase} />
                </div>
              </Link>
            ))}
          </div>
          <Pagination
            page={exams.data.page}
            pageSize={exams.data.pageSize}
            totalCount={exams.data.totalCount}
            onPageChange={(next) => setQuery({ page: String(next) })}
          />
        </>
      )}
    </div>
  );
}
