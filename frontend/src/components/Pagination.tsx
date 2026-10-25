import { useI18n } from '../i18n/LanguageContext';

interface PaginationProps {
  page: number;
  pageSize: number;
  totalCount: number;
  onPageChange(page: number): void;
}

export function Pagination({ page, pageSize, totalCount, onPageChange }: PaginationProps) {
  const { t, formatNumber } = useI18n();
  const pageCount = Math.max(1, Math.ceil(totalCount / pageSize));
  const first = totalCount === 0 ? 0 : (page - 1) * pageSize + 1;
  const last = Math.min(page * pageSize, totalCount);

  return (
    <nav className="pagination" aria-label={t('pagination.label')}>
      <span className="pagination-summary">
        {totalCount === 0
          ? t('pagination.none')
          : t('pagination.summary', { first: formatNumber(first), last: formatNumber(last), total: formatNumber(totalCount) })}
      </span>
      <div className="pagination-buttons">
        <button type="button" className="button button-secondary" disabled={page <= 1} onClick={() => onPageChange(page - 1)}>
          <span className="icon-flip" aria-hidden="true">
            ‹
          </span>{' '}
          {t('pagination.previous')}
        </button>
        <span className="pagination-page">
          {t('pagination.page', { page: formatNumber(page), count: formatNumber(pageCount) })}
        </span>
        <button
          type="button"
          className="button button-secondary"
          disabled={page >= pageCount}
          onClick={() => onPageChange(page + 1)}
        >
          {t('pagination.next')}{' '}
          <span className="icon-flip" aria-hidden="true">
            ›
          </span>
        </button>
      </div>
    </nav>
  );
}
