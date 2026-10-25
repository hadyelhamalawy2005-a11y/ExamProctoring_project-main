import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { describeError } from '../api/errors';
import { Alert, PageLoader } from '../components/Feedback';
import { useI18n } from '../i18n/LanguageContext';
import { LanguageToggle } from '../i18n/LanguageToggle';
import { useAuth } from './AuthContext';

// The session could not be restored because the server could not answer (network error, 429 or 5xx). The stored session
// is kept: the user can try again or sign out.
function SessionUnavailable() {
  const i18n = useI18n();
  const { t } = i18n;
  const { restoreError, retryRestore, signOut } = useAuth();
  return (
    <main className="auth-page">
      <div className="card auth-card form">
        <div className="auth-toolbar">
          <LanguageToggle />
        </div>
        <h1>{t('session.unavailableTitle')}</h1>
        <p className="muted">{t('session.unavailableBody')}</p>
        <Alert tone="error">{describeError(restoreError, i18n)}</Alert>
        <button type="button" className="button button-block" onClick={retryRestore}>
          {t('common.tryAgain')}
        </button>
        <button type="button" className="link-button" onClick={() => void signOut()}>
          {t('common.signOut')}
        </button>
      </div>
    </main>
  );
}

// Pages for signed-in instructors. This only shapes the UI: the backend enforces the Instructor role, account status
// and ownership on every request, whatever the frontend shows.
export function RequireInstructor({ children }: { children: ReactNode }) {
  const { status, session, signOut } = useAuth();
  const { t } = useI18n();
  const location = useLocation();

  if (status === 'loading') return <PageLoader label={t('session.restoring')} />;
  if (status === 'unavailable') return <SessionUnavailable />;

  if (!session) {
    return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />;
  }

  if (session.mustChangePassword) return <Navigate to="/change-password" replace />;

  if (session.user.role !== 'Instructor') {
    return (
      <main className="auth-page">
        <div className="card auth-card">
          <div className="auth-toolbar">
            <LanguageToggle />
          </div>
          <h1>{t('access.title')}</h1>
          <p>
            {t('access.body', { email: '\u2066' + session.user.email + '\u2069', role: t(`role.${session.user.role}`) })}
          </p>
          {session.user.role === 'Student' && <p className="muted">{t('access.studentNote')}</p>}
          <button type="button" className="button" onClick={() => void signOut()}>
            {t('common.signOut')}
          </button>
        </div>
      </main>
    );
  }

  return <>{children}</>;
}

// Pages that need any signed-in account (the password change screen).
export function RequireSession({ children }: { children: ReactNode }) {
  const { status, session } = useAuth();
  const { t } = useI18n();
  if (status === 'loading') return <PageLoader label={t('session.restoring')} />;
  if (status === 'unavailable') return <SessionUnavailable />;
  if (!session) return <Navigate to="/login" replace />;
  return <>{children}</>;
}
