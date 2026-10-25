import { useState, type FormEvent } from 'react';
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom';
import { ApiError, describeError } from '../api/errors';
import { useAuth } from '../auth/AuthContext';
import { tokenStore } from '../auth/tokenStore';
import { Alert } from '../components/Feedback';
import { FormField, describedBy } from '../components/FormField';
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
  const from = (location.state as { from?: string } | null)?.from ?? '/exams';

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fieldErrors, setFieldErrors] = useState<Record<string, Msg>>({});
  const [error, setError] = useState<{ cause: unknown } | null>(null);
  // Shown when the server ended the session (the refresh token was rejected), not for temporary failures.
  const [sessionEnded, setSessionEnded] = useState(() => tokenStore.getEndReason() === 'sessionEnded');
  const [submitting, setSubmitting] = useState(false);

  if (session) return <Navigate to={session.mustChangePassword ? '/change-password' : from} replace />;

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
      navigate(signedIn.mustChangePassword ? '/change-password' : from, { replace: true });
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
    <main className="auth-page">
      <form className="card auth-card form" onSubmit={(event) => void handleSubmit(event)} noValidate>
        <div className="auth-toolbar">
          <LanguageToggle />
        </div>
        <h1>{t('login.title')}</h1>
        <p className="muted">{t('login.subtitle')}</p>
        {sessionEnded && (
          <Alert tone="info" onDismiss={dismissSessionEnded}>
            {t('login.sessionEnded')}
          </Alert>
        )}
        {error && <Alert tone="error">{describeError(error.cause, i18n)}</Alert>}
        <FormField id="login-email" label={t('login.email')} error={fieldErrors.email}>
          <input
            id="login-email"
            type="email"
            dir="ltr"
            autoComplete="username"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            aria-invalid={Boolean(fieldErrors.email)}
            aria-describedby={describedBy('login-email', fieldErrors.email)}
          />
        </FormField>
        <FormField id="login-password" label={t('login.password')} error={fieldErrors.password}>
          <input
            id="login-password"
            type="password"
            dir="ltr"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            aria-invalid={Boolean(fieldErrors.password)}
            aria-describedby={describedBy('login-password', fieldErrors.password)}
          />
        </FormField>
        <button type="submit" className="button button-block" disabled={submitting}>
          {submitting ? t('login.submitting') : t('login.submit')}
        </button>
        <p className="muted">
          <Link to="/register">{t('login.createAccount')}</Link>
        </p>
      </form>
    </main>
  );
}
