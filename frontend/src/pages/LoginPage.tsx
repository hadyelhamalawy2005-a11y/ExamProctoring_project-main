import { useState, type FormEvent } from 'react';
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { ApiError, describeError } from '../api/errors';
import { landingFor } from '../auth/roles';
import { useAuth } from '../auth/AuthContext';
import { tokenStore } from '../auth/tokenStore';
import { Alert } from '../components/Feedback';
import { FloatingField } from '../components/FloatingField';
import { useI18n } from '../i18n/LanguageContext';
import { msg, serverFieldMsgs, type Msg } from '../i18n/serverMessages';
import { focusFirstInvalid } from '../utils/focus';
import { AuthShell } from '../components/AuthShell';

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
    <AuthShell>
      <form className="auth-card" onSubmit={(event) => void handleSubmit(event)} noValidate>
        <h1 className="auth-title">{t('login.title')}</h1>
        <p className="auth-subtitle">{t('login.subtitle')}</p>
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
        <button type="submit" className="button button-block" disabled={submitting}>
          {submitting && <span className="button-spinner" aria-hidden="true" />}
          {submitting ? t('login.submitting') : t('login.submit')}
        </button>
        <div className="auth-links">
          <Link className="auth-link" to="/forgot-password">
            {t('login.forgot')}
          </Link>
        </div>
        <p className="auth-note">{t('login.accountsByAdmin')}</p>
      </form>
    </AuthShell>
  );
}
