import { Link, NavLink, Outlet, matchPath, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { homeFor } from '../auth/roles';
import { useI18n } from '../i18n/LanguageContext';
import type { TranslationKey } from '../i18n/en';
import type { Role } from '../types/api';
import { Icon, type IconName } from './Icon';

// The application shell, laid out like the mobile app: a navy AppBar with the screen's title, and (for instructors and
// students) a bottom navigation bar on the main screens. Administrators have no bottom bar: their AppBar has a profile
// button and every screen below the list is opened on top of it with a back arrow.

interface Tab {
  to: string;
  label: TranslationKey;
  icon: IconName;
  selectedIcon: IconName;
}

const TABS: Record<Role, Tab[]> = {
  Instructor: [
    { to: '/instructor', label: 'nav.home', icon: 'homeOutline', selectedIcon: 'home' },
    { to: '/exams', label: 'nav.exams', icon: 'assignmentOutline', selectedIcon: 'assignment' },
    { to: '/incidents', label: 'nav.incidents', icon: 'error', selectedIcon: 'report' },
    { to: '/profile', label: 'nav.profile', icon: 'personOutline', selectedIcon: 'person' },
  ],
  Student: [
    { to: '/student', label: 'nav.home', icon: 'homeOutline', selectedIcon: 'home' },
    { to: '/student/exams', label: 'nav.exams', icon: 'assignmentOutline', selectedIcon: 'assignment' },
    { to: '/student/results', label: 'nav.results', icon: 'assignment', selectedIcon: 'assignment' },
    { to: '/profile', label: 'nav.profile', icon: 'personOutline', selectedIcon: 'person' },
  ],
  Admin: [],
};

// Screen title per route. null = the app name (the home screens of the mobile app show it).
const TITLES: Array<[pattern: string, title: TranslationKey | null]> = [
  ['/instructor', null],
  ['/exams', 'list.title'],
  ['/exams/new/method', 'title.newExam'],
  ['/exams/:examId/attempts', 'title.attempts'],
  ['/incidents', 'nav.incidents'],
  ['/incidents/:incidentId', 'title.incident'],
  ['/exams/new', 'editor.newTitle'],
  ['/exams/:examId', 'title.exam'],
  ['/exams/:examId/edit', 'editor.editTitle'],
  ['/exams/:examId/preview', 'title.preview'],
  ['/import', 'nav.import'],
  ['/profile', 'nav.profile'],
  ['/student', null],
  ['/student/exams', 'nav.exams'],
  ['/student/results', 'nav.results'],
  ['/student/exams/:examId', 'title.studentExam'],
  ['/student/exams/:examId/consent', 'title.studentExam'],
  ['/student/exams/:examId/system-check', 'title.studentExam'],
  ['/student/attempts/:attemptId', 'title.attempt'],
  ['/student/attempts/:attemptId/result', 'nav.results'],
  ['/admin/accounts', 'admin.list.title'],
  ['/admin/accounts/:accountId', 'title.account'],
  ['/admin/instructors/new', 'admin.create.title'],
];

const titleFor = (pathname: string): TranslationKey | null | undefined =>
  TITLES.find(([pattern]) => matchPath({ path: pattern, end: true }, pathname))?.[1];

export function AppShell({ role }: { role: Role }) {
  const { t } = useI18n();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const tabs = TABS[role];
  const isTabRoot = tabs.some((tab) => pathname === tab.to);
  const isAdminRoot = role === 'Admin' && pathname === '/admin/accounts';
  const isRoot = isTabRoot || isAdminRoot;
  const title = titleFor(pathname);

  // Back goes to the screen before this one when the user came from inside the app, otherwise to the role's home.
  const goBack = () => {
    const cameFromApp = (window.history.state as { idx?: number } | null)?.idx;
    if (cameFromApp && cameFromApp > 0) navigate(-1);
    else navigate(homeFor(role), { replace: true });
  };

  return (
    <div className={`app-shell ${tabs.length > 0 && isTabRoot ? 'app-shell-tabs' : ''}`}>
      <header className="app-bar">
        {!isRoot && (
          <button type="button" className="app-bar-button app-bar-back" onClick={goBack} aria-label={t('common.back')}>
            <Icon name="arrowBack" className="icon-flip" />
          </button>
        )}
        <h1 className="app-bar-title">{title ? t(title) : 'Examora'}</h1>
        {isAdminRoot && (
          <Link to="/profile" className="app-bar-button" aria-label={t('nav.profile')}>
            <Icon name="personOutline" />
          </Link>
        )}
      </header>
      <main className="app-main">
        <Outlet />
      </main>
      {tabs.length > 0 && isTabRoot && (
        <nav className="bottom-nav" aria-label={t('nav.main')}>
          {tabs.map((tab) => (
            <NavLink key={tab.to} to={tab.to} end>
              {({ isActive }) => (
                <>
                  <span className="nav-pill">
                    <Icon name={isActive ? tab.selectedIcon : tab.icon} />
                  </span>
                  <span>{t(tab.label)}</span>
                </>
              )}
            </NavLink>
          ))}
        </nav>
      )}
    </div>
  );
}

export const InstructorLayout = () => <AppShell role="Instructor" />;
export const AdminLayout = () => <AppShell role="Admin" />;
export const StudentLayout = () => <AppShell role="Student" />;

// Whatever the role, /profile uses that role's own shell.
export function ProfileLayout() {
  const { session } = useAuth();
  return session ? <AppShell role={session.user.role} /> : null;
}
