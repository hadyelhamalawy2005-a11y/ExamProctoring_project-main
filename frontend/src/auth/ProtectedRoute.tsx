import type { ReactNode } from 'react';
import { Link, Navigate, useLocation } from 'react-router-dom';
import { describeError } from '../api/errors';
import { Alert, PageLoader } from '../components/Feedback';
import { useI18n } from '../i18n/LanguageContext';
import type { Role } from '../types/api';
import { useAuth } from './AuthContext';
import { homeFor } from './roles';
import { AuthShell } from '../components/AuthShell';

// The session could not be restored because the server could not answer (network error, 429 or 5xx). The stored session
// is kept: the user can try again or sign out.
function SessionUnavailable() {
  const i18n = useI18n();
  const { t } = i18n;
  const { restoreError, retryRestore, signOut } = useAuth();
  return (
    <AuthShell>
      <div className="auth-card form">
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
    </AuthShell>
  );
}

// Pages for signed-in users of the given role(s). This only shapes the UI: the backend enforces the role, the account
// status and ownership on every request, whatever the frontend shows. The role comes from the signed-in session, which
// is filled from the backend's token response (never from anything the browser stored), so it cannot be edited in the
// browser to see another role's pages.
export function RequireRole({ roles, children }: { roles: readonly Role[]; children: ReactNode }) {
  const { status, session, signOut } = useAuth();
  const { t } = useI18n();
  const location = useLocation();

  if (status === 'loading') return <PageLoader label={t('session.restoring')} />;
  if (status === 'unavailable') return <SessionUnavailable />;

  if (!session) {
    return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />;
  }

  if (session.mustChangePassword) return <Navigate to="/change-password" replace />;

  const role = session.user.role;
  if (!roles.includes(role)) {
    const area = roles[0];
    const email = '\u2066' + session.user.email + '\u2069';
    return (
      <AuthShell>
        <div className="auth-card">
          <h1>{t(area === 'Admin' ? 'access.adminTitle' : area === 'Student' ? 'access.studentTitle' : 'access.title')}</h1>
          <p>
            {area === 'Instructor'
              ? t('access.body', { email, role: t(`role.${role}`) })
              : t('access.bodyOther', { email, role: t(`role.${role}`) })}
          </p>
          {area === 'Instructor' && role === 'Student' && <p className="muted">{t('access.studentNote')}</p>}
          <div className="button-row">
            <Link className="button" to={homeFor(role)}>
              {t('access.goHome')}
            </Link>
            <button type="button" className="button button-secondary" onClick={() => void signOut()}>
              {t('common.signOut')}
            </button>
          </div>
        </div>
      </AuthShell>
    );
  }

  return <>{children}</>;
}

// Kept for the instructor pages and their tests.
export function RequireInstructor({ children }: { children: ReactNode }) {
  return <RequireRole roles={['Instructor']}>{children}</RequireRole>;
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
