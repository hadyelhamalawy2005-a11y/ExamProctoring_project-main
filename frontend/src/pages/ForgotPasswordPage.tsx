import { Link } from 'react-router-dom';
import { useI18n } from '../i18n/LanguageContext';
import { LanguageToggle } from '../i18n/LanguageToggle';

// There is no password-reset endpoint: an administrator issues a new temporary password
// (POST /api/admin/accounts/{id}/temporary-password), and the user chooses their own at the next sign-in. This screen says so.
export function ForgotPasswordPage() {
  const { t } = useI18n();
  return (
    <main className="login-page">
      <div className="login-column">
        <div className="login-toolbar">
          <LanguageToggle />
        </div>
        <svg className="login-logo" viewBox="0 0 24 24" width="48" height="48" aria-hidden="true" focusable="false">
          <path
            fill="currentColor"
            d="M12 3c-4.97 0-9 4.03-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42C8.27 19.99 10.51 21 13 21c4.97 0 9-4.03 9-9s-4.03-9-9-9zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z"
          />
        </svg>
        <h1 className="login-title">{t('forgot.title')}</h1>
        <p className="login-subtitle">{t('forgot.body')}</p>
        <Link className="login-submit" to="/login">
          {t('forgot.back')}
        </Link>
      </div>
    </main>
  );
}
