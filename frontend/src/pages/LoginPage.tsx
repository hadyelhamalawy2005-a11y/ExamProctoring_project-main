import { useState, type FormEvent } from 'react';
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { ApiError, describeError } from '../api/errors';
import { landingFor } from '../auth/roles';
import { useAuth } from '../auth/AuthContext';
import { tokenStore } from '../auth/tokenStore';
import { Alert } from '../components/Feedback';
import { FloatingField } from '../components/FloatingField';
import { useI18n } from '../i18n/LanguageContext';
import { LanguageToggle } from '../i18n/LanguageToggle';
import { msg, serverFieldMsgs, type Msg } from '../i18n/serverMessages';
import { focusFirstInvalid } from '../utils/focus';

// POST /api/auth/login. Instructor accounts are created by an admin with a temporary password, which must be changed
// at first sign-in (the backend then answers mustChangePassword: true).
export function LoginPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const { session, signIn } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const from = (location.state as { from?: string } | null)?.from;

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fieldErrors, setFieldErrors] = useState<Record<string, Msg>>({});
  const [error, setError] = useState<{ cause: unknown } | null>(null);
  // Shown when the server ended the session (the refresh token was rejected), not for temporary failures.
  const [sessionEnded, setSessionEnded] = useState(() => tokenStore.getEndReason() === 'sessionEnded');
  const [submitting, setSubmitting] = useState(false);

  if (session) return <Navigate to={session.mustChangePassword ? '/change-password' : landingFor(session.user.role, from)} replace />;

  const dismissSessionEnded = () => {
    tokenStore.dismissEndReason();
    setSessionEnded(false);
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    setError(null);
    const missing: Record<string, Msg> = {};
    if (!email.trim()) missing.email = msg('val.emailRequired');
    if (!password) missing.password = msg('val.passwordRequired');
    setFieldErrors(missing);
    if (Object.keys(missing).length > 0) {
      focusFirstInvalid(form);
      return;
    }

    setSubmitting(true);
    try {
      const signedIn = await signIn(email.trim(), password);
      navigate(signedIn.mustChangePassword ? '/change-password' : landingFor(signedIn.user.role, from), { replace: true });
    } catch (caught) {
      if (caught instanceof ApiError && caught.status === 400) {
        setFieldErrors(serverFieldMsgs(caught.fieldErrors));
        focusFirstInvalid(form);
      }
      // invalid_credentials, account_locked, account_deactivated and temporary_password_expired carry a readable
      // detail message from the backend (translated when known).
      setError({ cause: caught });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main className="login-page">
      <form className="login-column" onSubmit={(event) => void handleSubmit(event)} noValidate>
        <div className="login-toolbar">
          <LanguageToggle />
        </div>
        <svg className="login-logo" viewBox="0 0 24 24" width="48" height="48" aria-hidden="true" focusable="false">
          <path
            fill="currentColor"
            d="M5 13.18v4L12 21l7-3.82v-4L12 17l-7-3.82zM12 3L1 9l11 6 9-4.91V17h2V9L12 3zm6.82 6L12 12.72 5.18 9 12 5.28 18.82 9z"
          />
        </svg>
        <p className="login-brand">Examora</p>
        <h1 className="login-title">{t('login.title')}</h1>
        <p className="login-subtitle">{t('login.subtitle')}</p>
        {sessionEnded && (
          <Alert tone="info" onDismiss={dismissSessionEnded}>
            {t('login.sessionEnded')}
          </Alert>
        )}
        {error && <Alert tone="error">{describeError(error.cause, i18n)}</Alert>}
        <FloatingField
          id="login-email"
          type="email"
          ltr
          autoComplete="username"
          label={t('login.email')}
          value={email}
          onChange={setEmail}
          error={fieldErrors.email}
          disabled={submitting}
        />
        <FloatingField
          id="login-password"
          type="password"
          ltr
          autoComplete="current-password"
          label={t('login.password')}
          value={password}
          onChange={setPassword}
          error={fieldErrors.password}
          disabled={submitting}
        />
        <button type="submit" className="login-submit" disabled={submitting}>
          {submitting && <span className="login-spinner" aria-hidden="true" />}
          {submitting ? t('login.submitting') : t('login.submit')}
        </button>
        <Link className="login-link" to="/forgot-password">
          {t('login.forgot')}
        </Link>
        <Link className="login-link" to="/register">
          {t('login.createAccount')}
        </Link>
        <p className="login-note">{t('login.accountsByAdmin')}</p>
      </form>
    </main>
  );
}
