import { Link, useSearchParams } from 'react-router-dom';
import { listAccounts } from '../api/admin';
import { describeError } from '../api/errors';
import { Chip } from '../components/Chip';
import { Alert, EmptyState, PageLoader } from '../components/Feedback';
import { Icon } from '../components/Icon';
import { Pagination } from '../components/Pagination';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import type { AccountStatus, ManagedRole } from '../types/api';

const ROLES: ManagedRole[] = ['Student', 'Instructor'];
const STATUSES: AccountStatus[] = ['Active', 'Deactivated'];
const PAGE_SIZE = 20; // the backend default; the page size is not a user setting here

export function AccountStatusBadge({ status }: { status: AccountStatus }) {
  const { t } = useI18n();
  return <span className={`badge ${status === 'Active' ? 'badge-published' : 'badge-cancelled'}`}>{t(`account.status.${status}`)}</span>;
}

// GET /api/admin/accounts?role=&status=&page=&pageSize=: Students and Instructors, paged. The backend has no search
// parameter, so there is no search box. Filters and the page live in the URL so the back button works.
export function AdminAccountsPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const [params, setParams] = useSearchParams();
  const role = ROLES.find((value) => value === params.get('role'));
  const status = STATUSES.find((value) => value === params.get('status'));
  const page = Math.max(1, Number.parseInt(params.get('page') ?? '1', 10) || 1);

  const accounts = useLoader((signal) => listAccounts({ role, status, page, pageSize: PAGE_SIZE }, signal), [role, status, page]);

  const setQuery = (changes: Record<string, string | undefined>) => {
    const next = new URLSearchParams(params);
    Object.entries(changes).forEach(([key, value]) => (value ? next.set(key, value) : next.delete(key)));
    setParams(next);
  };

  const filtered = Boolean(role || status);

  return (
    <div className="page">
      <Link to="/admin/instructors/new" className="button button-block">
        <Icon name="personAdd" size={18} />
        {t('admin.list.newInstructor')}
      </Link>

      <div className="chips" role="group" aria-label={t('admin.list.role')}>
        <span className="chips-label">{t('admin.list.role')}</span>
        <Chip selected={!role} onClick={() => setQuery({ role: undefined, page: undefined })}>
          {t('admin.list.all')}
        </Chip>
        {ROLES.map((value) => (
          <Chip key={value} selected={role === value} onClick={() => setQuery({ role: value, page: undefined })}>
            {t(`role.${value}`)}
          </Chip>
        ))}
      </div>
      <div className="chips" role="group" aria-label={t('admin.list.status')}>
        <span className="chips-label">{t('admin.list.status')}</span>
        <Chip selected={!status} onClick={() => setQuery({ status: undefined, page: undefined })}>
          {t('admin.list.all')}
        </Chip>
        {STATUSES.map((value) => (
          <Chip key={value} selected={status === value} onClick={() => setQuery({ status: value, page: undefined })}>
            {t(`account.status.${value}`)}
          </Chip>
        ))}
      </div>

      {accounts.error != null && (
        <Alert tone="error">
          {describeError(accounts.error, i18n)}{' '}
          <button type="button" className="link-button" onClick={accounts.reload}>
            {t('common.tryAgain')}
          </button>
        </Alert>
      )}

      {accounts.loading && !accounts.data && <PageLoader label={t('admin.list.loading')} />}

      {accounts.data && accounts.data.items.length === 0 && (
        <EmptyState icon="people" title={filtered ? t('admin.list.emptyFiltered') : t('admin.list.emptyNone')}>
          {accounts.data.totalCount > 0 && (
            <p>
              <button type="button" className="link-button" onClick={() => setQuery({ page: undefined })}>
                {t('admin.list.pastEnd')}
              </button>
            </p>
          )}
        </EmptyState>
      )}

      {accounts.data && accounts.data.items.length > 0 && (
        <>
          <div className="card-list">
            {accounts.data.items.map((account) => (
              <Link key={account.id} to={`/admin/accounts/${account.id}`} className="card item-card">
                <h2>
                  <bdi>{account.fullName}</bdi>
                </h2>
                <p dir="ltr" className="item-email">
                  {account.email}
                </p>
                <div className="badge-row">
                  <span className="badge badge-phase-upcoming">{t(`role.${account.role}`)}</span>
                  <AccountStatusBadge status={account.accountStatus} />
                  {account.isLockedOut && <span className="badge badge-phase-open">{t('admin.detail.lockedOut')}</span>}
                  {account.mustChangePassword && <span className="badge badge-phase-open">{t('admin.detail.mustChange')}</span>}
                </div>
              </Link>
            ))}
          </div>
          <Pagination
            page={accounts.data.page}
            pageSize={accounts.data.pageSize}
            totalCount={accounts.data.totalCount}
            label={t('admin.pagination.label')}
            noneText={t('admin.pagination.none')}
            onPageChange={(next) => setQuery({ page: String(next) })}
          />
        </>
      )}
    </div>
  );
}
