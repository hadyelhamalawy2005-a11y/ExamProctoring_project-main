import { useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { ApiError, describeError } from '../api/errors';
import { useAuth } from '../auth/AuthContext';
import { Alert } from '../components/Feedback';
import { FormField, describedBy } from '../components/FormField';
import { useI18n } from '../i18n/LanguageContext';
import { LanguageToggle } from '../i18n/LanguageToggle';
import { msg, serverFieldMsgs, type Msg } from '../i18n/serverMessages';
import { focusFirstInvalid } from '../utils/focus';

// POST /api/auth/change-password. Required after signing in with a temporary password; every other endpoint answers
// 403 password_change_required until it is done. The server returns a new token pair and ends earlier sessions.
export function ChangePasswordPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const { session, changePassword, signOut } = useAuth();
  const navigate = useNavigate();
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [fieldErrors, setFieldErrors] = useState<Record<string, Msg>>({});
  const [error, setError] = useState<{ cause: unknown } | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const required = session?.mustChangePassword ?? false;

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    setError(null);
    const found: Record<string, Msg> = {};
    if (!currentPassword) found.currentPassword = msg('val.currentRequired');
    if (!newPassword) found.newPassword = msg('val.newRequired');
    // The backend has no confirmation field; this check only protects against typing mistakes.
    if (newPassword !== confirmPassword) found.confirmPassword = msg('val.passwordsMismatch');
    setFieldErrors(found);
    if (Object.keys(found).length > 0) {
      focusFirstInvalid(form);
      return;
    }

    setSubmitting(true);
    try {
      await changePassword(currentPassword, newPassword);
      navigate('/exams', { replace: true });
    } catch (caught) {
      if (caught instanceof ApiError && caught.status === 400) {
        setFieldErrors(serverFieldMsgs(caught.fieldErrors, { all: true }));
        focusFirstInvalid(form);
      }
      setError({ cause: caught });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="auth-page">
      <form className="card auth-card form" onSubmit={(event) => void handleSubmit(event)} noValidate>
        <div className="auth-toolbar">
          <LanguageToggle />
        </div>
        <h1>{required ? t('cp.titleRequired') : t('cp.title')}</h1>
        {required && <p className="muted">{t('cp.temporaryNotice')}</p>}
        <p className="muted">{t('cp.policy')}</p>
        {error && <Alert tone="error">{describeError(error.cause, i18n)}</Alert>}
        <FormField id="cp-current" label={t('cp.current')} error={fieldErrors.currentPassword}>
          <input
            id="cp-current"
            type="password"
            dir="ltr"
            autoComplete="current-password"
            value={currentPassword}
            onChange={(event) => setCurrentPassword(event.target.value)}
            aria-invalid={Boolean(fieldErrors.currentPassword)}
            aria-describedby={describedBy('cp-current', fieldErrors.currentPassword)}
          />
        </FormField>
        <FormField id="cp-new" label={t('cp.new')} error={fieldErrors.newPassword}>
          <input
            id="cp-new"
            type="password"
            dir="ltr"
            autoComplete="new-password"
            value={newPassword}
            onChange={(event) => setNewPassword(event.target.value)}
            aria-invalid={Boolean(fieldErrors.newPassword)}
            aria-describedby={describedBy('cp-new', fieldErrors.newPassword)}
          />
        </FormField>
        <FormField id="cp-confirm" label={t('cp.repeat')} error={fieldErrors.confirmPassword}>
          <input
            id="cp-confirm"
            type="password"
            dir="ltr"
            autoComplete="new-password"
            value={confirmPassword}
            onChange={(event) => setConfirmPassword(event.target.value)}
            aria-invalid={Boolean(fieldErrors.confirmPassword)}
            aria-describedby={describedBy('cp-confirm', fieldErrors.confirmPassword)}
          />
        </FormField>
        <button type="submit" className="button button-block" disabled={submitting}>
          {submitting ? t('common.saving') : t('cp.submit')}
        </button>
        <button
          type="button"
          className="link-button"
          onClick={() => void signOut().then(() => navigate('/login', { replace: true }))}
        >
          {t('cp.signOutInstead')}
        </button>
      </form>
    </main>
  );
}
