import { useAuth } from '../auth/AuthContext';
import { Alert } from '../components/Feedback';
import { useI18n } from '../i18n/LanguageContext';

// The student area exists as a route and a layout only. The backend has no student exam endpoints (exams for students,
// attempts, results), so nothing here is simulated: no exam list, no results, only a notice saying so.
export function StudentHomePage() {
  const { t } = useI18n();
  const { session } = useAuth();
  return (
    <div className="page">
      {session && (
        <div className="card">
          <h1>{t('home.welcome', { name: session.user.fullName })}</h1>
          <p className="muted">{t(`role.${session.user.role}`)}</p>
        </div>
      )}
      <Alert tone="info">{t('student.body')}</Alert>
    </div>
  );
}
