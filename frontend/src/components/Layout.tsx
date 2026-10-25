import { Link, NavLink, Outlet, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { useI18n } from '../i18n/LanguageContext';
import { LanguageToggle } from '../i18n/LanguageToggle';

export function Layout() {
  const { session, signOut } = useAuth();
  const { t } = useI18n();
  const navigate = useNavigate();

  const handleSignOut = async () => {
    await signOut();
    navigate('/login', { replace: true });
  };

  return (
    <div className="app-shell">
      <header className="app-header">
        <Link to="/exams" className="brand">
          {t('app.name')} <span className="brand-sub">{t('app.instructor')}</span>
        </Link>
        <nav className="app-nav" aria-label={t('nav.main')}>
          <NavLink to="/exams" end>
            {t('nav.exams')}
          </NavLink>
          <NavLink to="/exams/new">{t('nav.newExam')}</NavLink>
          <NavLink to="/import">{t('nav.import')}</NavLink>
        </nav>
        <div className="app-user">
          <LanguageToggle />
          <span className="app-user-name" title={session?.user.email} dir="auto">
            {session?.user.fullName}
          </span>
          <button type="button" className="button button-secondary button-small" onClick={() => void handleSignOut()}>
            {t('common.signOut')}
          </button>
        </div>
      </header>
      <main className="app-main">
        <Outlet />
      </main>
    </div>
  );
}
