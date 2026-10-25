import { Link, useSearchParams } from 'react-router-dom';
import { describeError } from '../api/errors';
import { listExams } from '../api/exams';
import { Alert, EmptyState, Spinner } from '../components/Feedback';
import { Pagination } from '../components/Pagination';
import { PhaseBadge, StatusBadge } from '../components/StatusBadge';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import type { ExamStatus } from '../types/api';
import { formatDuration } from '../utils/dates';

const STATUSES: ExamStatus[] = ['Draft', 'Published', 'Cancelled'];
const PAGE_SIZES = [10, 25, 50];

// GET /api/exams: the instructor's own exams, newest start first, paged (pageSize 1-100, default 10), with an
// optional status filter. Filter and page live in the URL so the browser's back button works.
export function ExamListPage() {
  const i18n = useI18n();
  const { t, formatDateTime, formatNumber } = i18n;
  const [params, setParams] = useSearchParams();
  const status = STATUSES.find((value) => value === params.get('status'));
  const page = Math.max(1, Number.parseInt(params.get('page') ?? '1', 10) || 1);
  const pageSize = PAGE_SIZES.includes(Number(params.get('pageSize'))) ? Number(params.get('pageSize')) : 10;

  const exams = useLoader((signal) => listExams({ status, page, pageSize }, signal), [status, page, pageSize]);

  const setQuery = (changes: Record<string, string | undefined>) => {
    const next = new URLSearchParams(params);
    Object.entries(changes).forEach(([key, value]) => (value ? next.set(key, value) : next.delete(key)));
    setParams(next);
  };

  return (
    <div className="page">
      <div className="page-header">
        <div>
          <h1>{t('list.title')}</h1>
          <p className="muted">{t('list.tzNote')}</p>
        </div>
        <Link to="/exams/new" className="button">
          {t('list.newExam')}
        </Link>
      </div>

      <div className="toolbar">
        <label className="inline-field">
          {t('list.status')}
          <select value={status ?? ''} onChange={(event) => setQuery({ status: event.target.value || undefined, page: undefined })}>
            <option value="">{t('list.all')}</option>
            {STATUSES.map((value) => (
              <option key={value} value={value}>
                {t(`status.${value}`)}
              </option>
            ))}
          </select>
        </label>
        <label className="inline-field">
          {t('list.perPage')}
          <select value={pageSize} onChange={(event) => setQuery({ pageSize: event.target.value, page: undefined })}>
            {PAGE_SIZES.map((size) => (
              <option key={size} value={size}>
                {formatNumber(size)}
              </option>
            ))}
          </select>
        </label>
        {exams.loading && exams.data && <Spinner label={t('list.updating')} />}
      </div>

      {exams.error != null && (
        <Alert tone="error">
          {describeError(exams.error, i18n)}{' '}
          <button type="button" className="link-button" onClick={exams.reload}>
            {t('common.tryAgain')}
          </button>
        </Alert>
      )}

      {exams.loading && !exams.data && <Spinner label={t('list.loading')} />}

      {exams.data && exams.data.items.length === 0 && (
        <EmptyState title={status ? t('list.emptyFiltered', { status: t(`status.${status}`) }) : t('list.emptyNone')}>
          {exams.data.totalCount > 0 ? (
            <p>{t('list.pastEnd')}</p>
          ) : (
            <p>
              <Link to="/exams/new">{t('list.createFirst')}</Link>
            </p>
          )}
        </EmptyState>
      )}

      {exams.data && exams.data.items.length > 0 && (
        <>
          <table className="exam-table">
            <thead>
              <tr>
                <th scope="col">{t('list.colTitle')}</th>
                <th scope="col">{t('list.colStarts')}</th>
                <th scope="col">{t('list.colDuration')}</th>
                <th scope="col">{t('list.colStatus')}</th>
                <th scope="col">{t('list.colPhase')}</th>
              </tr>
            </thead>
            <tbody>
              {exams.data.items.map((exam) => (
                <tr key={exam.id}>
                  <td className="cell-title">
                    <Link to={`/exams/${exam.id}`} className="exam-title-link" dir="auto">
                      {exam.title}
                    </Link>
                    {exam.description && (
                      <div className="muted truncate" dir="auto">
                        {exam.description}
                      </div>
                    )}
                  </td>
                  <td data-label={t('list.colStarts')}>{formatDateTime(exam.startsAt)}</td>
                  <td data-label={t('list.colDuration')}>{formatDuration(exam.durationMinutes, t)}</td>
                  <td data-label={t('list.colStatus')}>
                    <StatusBadge status={exam.status} />
                  </td>
                  <td data-label={t('list.colPhase')}>
                    <PhaseBadge phase={exam.phase} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
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
