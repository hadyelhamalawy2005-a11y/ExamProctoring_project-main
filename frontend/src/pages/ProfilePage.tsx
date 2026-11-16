import { Link, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { Icon } from '../components/Icon';
import { useI18n } from '../i18n/LanguageContext';
import { LanguageToggle } from '../i18n/LanguageToggle';

function Line({ label, value, ltr }: { label: string; value: string; ltr?: boolean }) {
  return (
    <div className="profile-line">
      <span className="profile-label">{label}</span>
      <span dir={ltr ? 'ltr' : 'auto'}>{value}</span>
    </div>
  );
}

// The profile every role has: who is signed in (from the session the backend issued), the language, change password and
// sign out. Nothing here is stored locally.
export function ProfilePage() {
  const { t } = useI18n();
  const { session, signOut } = useAuth();
  const navigate = useNavigate();

  const handleSignOut = async () => {
    await signOut();
    navigate('/login', { replace: true });
  };

  return (
    <div className="page">
      <h2 className="section-title">{t('profile.identity')}</h2>
      <div className="card profile-card">
        {session && (
          <>
            <Line label={t('profile.name')} value={session.user.fullName} />
            <Line label={t('reg.email')} value={session.user.email} ltr />
            <Line label={t('profile.role')} value={t(`role.${session.user.role}`)} />
          </>
        )}
      </div>

      <h2 className="section-title">{t('lang.label')}</h2>
      <div className="profile-language">
        <LanguageToggle />
      </div>

      <div className="profile-actions">
        <Link className="button button-secondary button-block" to="/change-password">
          <Icon name="lock" size={18} />
          {t('cp.title')}
        </Link>
        <button type="button" className="button button-danger button-block" onClick={() => void handleSignOut()}>
          <Icon name="logout" size={18} />
          {t('common.signOut')}
        </button>
      </div>
    </div>
  );
}
