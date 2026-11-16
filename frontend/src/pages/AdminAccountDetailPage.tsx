import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { deactivateAccount, getAccount, issueTemporaryPassword, reactivateAccount } from '../api/admin';
import { ApiError, describeError } from '../api/errors';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { Icon } from '../components/Icon';
import { Alert, Spinner } from '../components/Feedback';
import { TemporaryPasswordPanel } from '../components/TemporaryPasswordPanel';
import { useLoader } from '../hooks/useLoader';
import { useI18n } from '../i18n/LanguageContext';
import { resolveMsg, type Msg } from '../i18n/serverMessages';
import type { TemporaryPasswordResponse } from '../types/api';
import { validateReason } from '../utils/validation';
import { AccountStatusBadge } from './AdminAccountsPage';

type Action = 'password' | 'deactivate' | 'reactivate';

// GET /api/admin/accounts/{id} with the actions the backend offers: temporary password, deactivate (reason required),
// reactivate (reason optional). Admins cannot be looked up here, so an administrator can never act on themselves.
export function AdminAccountDetailPage() {
  const i18n = useI18n();
  const { t, formatDateTime } = i18n;
  const { accountId = '' } = useParams();
  const account = useLoader((signal) => getAccount(accountId, signal), [accountId]);

  const [action, setAction] = useState<Action | null>(null);
  const [reason, setReason] = useState('');
  const [reasonError, setReasonError] = useState<Msg | null>(null);
  const [busy, setBusy] = useState(false);
  const [failure, setFailure] = useState<unknown>(null);
  const [notice, setNotice] = useState<string | null>(null);
  // Held in memory only, until the admin closes the panel or leaves the page.
  const [issued, setIssued] = useState<TemporaryPasswordResponse | null>(null);

  if (account.loading && !account.data) return <Spinner label={t('admin.detail.loading')} />;

  if (!account.data) {
    return (
      <div className="page">
        <Alert tone="error">{describeError(account.error, i18n)}</Alert>
        <Link to="/admin/accounts">{t('admin.detail.back')}</Link>
      </div>
    );
  }

  const data = account.data;
  const none = t('admin.detail.none');

  const open = (next: Action) => {
    setAction(next);
    setReason('');
    setReasonError(null);
    setFailure(null);
    setNotice(null);
  };
  const close = () => {
    if (!busy) setAction(null);
  };

  const confirm = async () => {
    if (!action || busy) return;
    if (action !== 'password') {
      const problem = validateReason(reason, action === 'deactivate');
      setReasonError(problem);
      if (problem) return;
    }
    setBusy(true);
    setFailure(null);
    try {
      if (action === 'password') {
        setIssued(await issueTemporaryPassword(data.id));
      } else if (action === 'deactivate') {
        await deactivateAccount(data.id, reason.trim());
        setNotice(t('admin.deactivate.done'));
      } else {
        await reactivateAccount(data.id, reason.trim() || undefined);
        setNotice(t('admin.reactivate.done'));
      }
      setAction(null);
      account.reload(); // show the server's state, whatever the action
    } catch (error) {
      setFailure(error);
      setAction(null);
      // 404 / 409 mean the account changed under us: show what the server has now.
      if (error instanceof ApiError && (error.status === 404 || error.status === 409)) account.reload();
    } finally {
      setBusy(false);
    }
  };

  const rows: Array<[string, string]> = [
    [t('admin.detail.email'), data.email],
    [t('admin.detail.role'), t(`role.${data.role}`)],
    [t('admin.detail.created'), formatDateTime(data.createdAt)],
    [t('admin.detail.lastLogin'), data.lastLoginAt ? formatDateTime(data.lastLoginAt) : t('admin.list.never')],
    [t('admin.detail.statusChanged'), data.statusChangedAt ? formatDateTime(data.statusChangedAt) : none],
    [t('admin.detail.reason'), data.statusReason ?? none],
    [t('admin.detail.mustChange'), data.mustChangePassword ? t('common.yes') : t('common.no')],
    [t('admin.detail.tempExpires'), data.temporaryPasswordExpiresAt ? formatDateTime(data.temporaryPasswordExpiresAt) : none],
    [t('admin.detail.lockedOut'), data.isLockedOut ? t('common.yes') : t('common.no')],
  ];

  return (
    <div className="page">
      {notice && (
        <Alert tone="success" onDismiss={() => setNotice(null)}>
          {notice}
        </Alert>
      )}
      {failure != null && <Alert tone="error">{describeError(failure, i18n)}</Alert>}
      {account.error != null && <Alert tone="error">{describeError(account.error, i18n)}</Alert>}

      <section className="card" aria-labelledby="account-heading">
        <div className="section-header">
          <div>
            <h1 id="account-heading">
              <bdi>{data.fullName}</bdi>
            </h1>
            <div className="badge-row">
              <span className="badge badge-phase-upcoming">{t(`role.${data.role}`)}</span>
              <AccountStatusBadge status={data.accountStatus} />
              {data.isLockedOut && <span className="badge badge-phase-open">{t('admin.detail.lockedOut')}</span>}
              {data.mustChangePassword && <span className="badge badge-phase-open">{t('admin.detail.mustChange')}</span>}
              {account.loading && <Spinner label={t('common.loading')} />}
            </div>
          </div>
        </div>

        <dl className="details-grid">
          {rows.map(([label, value]) => (
            <div key={label}>
              <dt>{label}</dt>
              <dd dir="auto">{value}</dd>
            </div>
          ))}
        </dl>
      </section>

      <div className="profile-actions">
        <button type="button" className="button button-secondary button-block" onClick={() => open('password')}>
          <Icon name="key" size={18} />
          {t('admin.tp.button')}
        </button>
        {data.accountStatus === 'Active' ? (
          <button type="button" className="button button-danger button-block" onClick={() => open('deactivate')}>
            <Icon name="block" size={18} />
            {t('admin.deactivate.button')}
          </button>
        ) : (
          <button type="button" className="button button-block" onClick={() => open('reactivate')}>
            {t('admin.reactivate.button')}
          </button>
        )}
      </div>

      {issued && <TemporaryPasswordPanel password={issued.temporaryPassword} expiresAt={issued.temporaryPasswordExpiresAt} onDone={() => setIssued(null)} />}

      <ConfirmDialog
        open={action === 'password'}
        title={t('admin.tp.confirmTitle')}
        confirmLabel={t('admin.tp.confirm')}
        busy={busy}
        onConfirm={() => void confirm()}
        onCancel={close}
      >
        <p>{t('admin.tp.confirmBody')}</p>
      </ConfirmDialog>

      <ConfirmDialog
        open={action === 'deactivate' || action === 'reactivate'}
        title={action === 'deactivate' ? t('admin.deactivate.title') : t('admin.reactivate.title')}
        confirmLabel={action === 'deactivate' ? t('admin.deactivate.confirm') : t('admin.reactivate.confirm')}
        tone={action === 'deactivate' ? 'danger' : 'primary'}
        busy={busy}
        onConfirm={() => void confirm()}
        onCancel={close}
      >
        <p>{action === 'deactivate' ? t('admin.deactivate.body') : t('admin.reactivate.body')}</p>
        <div className={`field ${reasonError ? 'field-invalid' : ''}`}>
          <label htmlFor="status-reason">{action === 'deactivate' ? t('admin.deactivate.reason') : t('admin.reactivate.reason')}</label>
          <textarea
            id="status-reason"
            dir="auto"
            rows={3}
            value={reason}
            onChange={(event) => setReason(event.target.value)}
            aria-invalid={Boolean(reasonError)}
            aria-describedby={reasonError ? 'status-reason-error' : undefined}
          />
          {reasonError && (
            <p className="field-error" id="status-reason-error">
              {resolveMsg(reasonError, i18n)}
            </p>
          )}
        </div>
      </ConfirmDialog>
    </div>
  );
}
