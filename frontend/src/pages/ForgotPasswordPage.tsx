import { Link } from 'react-router-dom';
import { AuthShell } from '../components/AuthShell';
import { Icon } from '../components/Icon';
import { useI18n } from '../i18n/LanguageContext';

// There is no password-reset endpoint: an administrator issues a new temporary password
// (POST /api/admin/accounts/{id}/temporary-password), and the user chooses their own at the next sign-in. This screen says so.
export function ForgotPasswordPage() {
  const { t } = useI18n();
  return (
    <AuthShell>
      <div className="auth-card">
        <span className="feature-tile" aria-hidden="true">
          <Icon name="key" size={22} />
        </span>
        <h1 className="auth-title">{t('forgot.title')}</h1>
        <p className="auth-subtitle">{t('forgot.body')}</p>
        <Link className="button button-block" to="/login">
          {t('forgot.back')}
        </Link>
      </div>
    </AuthShell>
  );
}
