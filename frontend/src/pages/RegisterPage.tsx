import { useState, type FormEvent } from 'react';
import { Link, Navigate } from 'react-router-dom';
import { register } from '../api/auth';
import { ApiError, describeError } from '../api/errors';
import { useAuth } from '../auth/AuthContext';
import { Alert } from '../components/Feedback';
import { FormField, describedBy } from '../components/FormField';
import { useI18n } from '../i18n/LanguageContext';
import { LanguageToggle } from '../i18n/LanguageToggle';
import { msg, serverFieldMsgs, type Msg } from '../i18n/serverMessages';
import { focusFirstInvalid } from '../utils/focus';
import { LIMITS, validateRegisterForm, type RegisterFormValues } from '../utils/validation';

const EMPTY: RegisterFormValues = { fullName: '', email: '', password: '', confirmPassword: '' };
const FIELDS = ['fullName', 'email', 'password', 'confirmPassword'] as const;

// POST /api/auth/register: student sign-up with exactly four fields (no role, no university). The backend returns the new
// account without tokens, so the student is not signed in: the success panel links to the sign-in page.
export function RegisterPage() {
  const i18n = useI18n();
  const { t } = i18n;
  const { session } = useAuth();
  const [values, setValues] = useState<RegisterFormValues>(EMPTY);
  const [fieldErrors, setFieldErrors] = useState<Record<string, Msg>>({});
  const [error, setError] = useState<{ cause: unknown } | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [created, setCreated] = useState(false);

  if (session) return <Navigate to="/exams" replace />;

  const update = (field: keyof RegisterFormValues) => (value: string) => {
    setValues((previous) => ({ ...previous, [field]: value }));
    setFieldErrors((previous) => ({ ...previous, [field]: '' }));
  };

  const handleSubmit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = event.currentTarget;
    setError(null);
    const clientErrors = validateRegisterForm(values);
    setFieldErrors(clientErrors);
    if (Object.keys(clientErrors).length > 0) {
      focusFirstInvalid(form);
      return;
    }

    setSubmitting(true);
    try {
      // Name and email are trimmed (the backend validates them trimmed); passwords are sent exactly as typed.
      await register({ ...values, fullName: values.fullName.trim(), email: values.email.trim() });
      setValues(EMPTY); // both passwords are cleared; nothing from the response is kept
      setCreated(true);
    } catch (caught) {
      if (caught instanceof ApiError && caught.status === 400 && Object.keys(caught.fieldErrors).length > 0) {
        // Backend keys: fullName, email, password (possibly several policy messages), confirmPassword.
        setFieldErrors(serverFieldMsgs(caught.fieldErrors, { all: true }));
        focusFirstInvalid(form);
        if (!FIELDS.some((field) => caught.fieldErrors[field])) setError({ cause: caught });
      } else if (caught instanceof ApiError && caught.status === 409 && caught.code === 'duplicate_account') {
        setFieldErrors({ email: msg('val.duplicateAccount') });
        focusFirstInvalid(form);
      } else {
        // 429 (rate limit), network and server errors: a general message; server details are never shown.
        setError({ cause: caught });
      }
    } finally {
      setSubmitting(false);
    }
  };

  if (created) {
    return (
      <main className="auth-page">
        <div className="card auth-card success-panel">
          <div className="auth-toolbar">
            <LanguageToggle />
          </div>
          <h1>{t('reg.successTitle')}</h1>
          <Alert tone="success">{t('reg.successBody')}</Alert>
          <Link className="button button-block" to="/login">
            {t('reg.successSignIn')}
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="auth-page">
      <form className="card auth-card form" onSubmit={(event) => void handleSubmit(event)} noValidate>
        <div className="auth-toolbar">
          <LanguageToggle />
        </div>
        <h1>{t('reg.title')}</h1>
        <p className="muted">{t('reg.subtitle')}</p>
        {error && <Alert tone="error">{describeError(error.cause, i18n)}</Alert>}
        <FormField id="reg-name" label={t('reg.fullName')} error={fieldErrors.fullName}>
          <input
            id="reg-name"
            dir="auto"
            autoComplete="name"
            value={values.fullName}
            onChange={(event) => update('fullName')(event.target.value)}
            aria-invalid={Boolean(fieldErrors.fullName)}
            aria-describedby={describedBy('reg-name', fieldErrors.fullName)}
          />
        </FormField>
        <FormField id="reg-email" label={t('reg.email')} error={fieldErrors.email}>
          <input
            id="reg-email"
            type="email"
            dir="ltr"
            autoComplete="email"
            value={values.email}
            onChange={(event) => update('email')(event.target.value)}
            aria-invalid={Boolean(fieldErrors.email)}
            aria-describedby={describedBy('reg-email', fieldErrors.email)}
          />
        </FormField>
        <FormField id="reg-password" label={t('reg.password')} error={fieldErrors.password} hint={t('reg.passwordHint')}>
          <input
            id="reg-password"
            type="password"
            dir="ltr"
            autoComplete="new-password"
            minLength={LIMITS.passwordMin}
            value={values.password}
            onChange={(event) => update('password')(event.target.value)}
            aria-invalid={Boolean(fieldErrors.password)}
            aria-describedby={describedBy('reg-password', fieldErrors.password, true)}
          />
        </FormField>
        <FormField id="reg-confirm" label={t('reg.confirmPassword')} error={fieldErrors.confirmPassword}>
          <input
            id="reg-confirm"
            type="password"
            dir="ltr"
            autoComplete="new-password"
            value={values.confirmPassword}
            onChange={(event) => update('confirmPassword')(event.target.value)}
            aria-invalid={Boolean(fieldErrors.confirmPassword)}
            aria-describedby={describedBy('reg-confirm', fieldErrors.confirmPassword)}
          />
        </FormField>
        <button type="submit" className="button button-block" disabled={submitting} aria-busy={submitting}>
          {submitting ? t('reg.submitting') : t('reg.submit')}
        </button>
        <p className="muted">
          {t('reg.haveAccount')} <Link to="/login">{t('reg.signIn')}</Link>
        </p>
      </form>
    </main>
  );
}
