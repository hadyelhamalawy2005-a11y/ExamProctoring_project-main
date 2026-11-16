import { Link, NavLink, Outlet, matchPath, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';
import { homeFor } from '../auth/roles';
import { useMediaQuery, WIDE_QUERY } from '../hooks/useMediaQuery';
import { useI18n } from '../i18n/LanguageContext';
import type { TranslationKey } from '../i18n/en';
import { LanguageToggle } from '../i18n/LanguageToggle';
import type { Role } from '../types/api';
import { initialsOf } from '../utils/names';
import { Icon, type IconName } from './Icon';
import { Logo } from './Logo';

// The application shell, one design for every role. On a wide window it is the brand's sidebar layout: the logo, the
// role's navigation and the signed-in person at the foot of a sidebar, with a title bar above the page. On a phone or a
// tablet the same navigation becomes a bottom bar under a compact title bar. The navigation items are the same in both,
// so a role sees the same destinations whatever the window size.

interface NavItem {
  to: string;
  label: TranslationKey;
  // The label under the icon in the bottom bar, where space is short.
  shortLabel?: TranslationKey;
  icon: IconName;
  isActive(pathname: string): boolean;
}

const under = (base: string) => (pathname: string) => pathname === base || pathname.startsWith(`${base}/`);
const exactly = (base: string) => (pathname: string) => pathname === base;

const PROFILE: NavItem = { to: '/profile', label: 'nav.profile', icon: 'person', isActive: exactly('/profile') };

const NAV: Record<Role, NavItem[]> = {
  Instructor: [
    { to: '/instructor', label: 'nav.home', icon: 'home', isActive: exactly('/instructor') },
    { to: '/exams', label: 'nav.exams', icon: 'examSheet', isActive: (p) => under('/exams')(p) },
    { to: '/import', label: 'nav.import', shortLabel: 'nav.importShort', icon: 'upload', isActive: exactly('/import') },
    { to: '/incidents', label: 'nav.incidents', icon: 'flag', isActive: under('/incidents') },
    PROFILE,
  ],
  Student: [
    { to: '/student', label: 'nav.home', icon: 'home', isActive: exactly('/student') },
    { to: '/student/exams', label: 'nav.exams', icon: 'examSheet', isActive: under('/student/exams') },
    { to: '/student/results', label: 'nav.results', icon: 'award', isActive: under('/student/results') },
    PROFILE,
  ],
  Admin: [
    { to: '/admin/accounts', label: 'nav.accounts', icon: 'users', isActive: under('/admin/accounts') },
    { to: '/admin/instructors/new', label: 'nav.newInstructor', shortLabel: 'nav.newInstructorShort', icon: 'userPlus', isActive: exactly('/admin/instructors/new') },
    PROFILE,
  ],
};

// Screen title per route. null = the home screens, which show the logo instead of a title.
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

function SidebarNav({ role }: { role: Role }) {
  const { t } = useI18n();
  const { pathname } = useLocation();
  // Profile is reached from the person at the foot of the sidebar, so it is not repeated in the list.
  const items = NAV[role].filter((item) => item !== PROFILE);
  return (
    <nav className="sidebar-nav" aria-label={t('nav.main')}>
      {items.map((item) => (
        <NavLink key={item.to} to={item.to} end className={`sidebar-link ${item.isActive(pathname) ? 'is-active' : ''}`} aria-current={item.isActive(pathname) ? 'page' : undefined}>
          <Icon name={item.icon} size={22} />
          <span>{t(item.label)}</span>
        </NavLink>
      ))}
    </nav>
  );
}

function Sidebar({ role }: { role: Role }) {
  const { t } = useI18n();
  const { session } = useAuth();
  const { pathname } = useLocation();
  const name = session?.user.fullName ?? '';
  return (
    <aside className="sidebar">
      <Link to={homeFor(role)} className="sidebar-logo" aria-label="Examora">
        <Logo height={32} />
      </Link>
      <SidebarNav role={role} />
      <Link to="/profile" className={`sidebar-user ${pathname === '/profile' ? 'is-active' : ''}`} aria-label={t('nav.profile')}>
        <span className="avatar" aria-hidden="true">
          {initialsOf(name)}
        </span>
        <span className="sidebar-user-text">
          <span className="sidebar-user-name" dir="auto">
            {name}
          </span>
          <span className="sidebar-user-role">{t(`role.${role}`)}</span>
        </span>
      </Link>
    </aside>
  );
}

function BottomNav({ role }: { role: Role }) {
  const { t } = useI18n();
  const { pathname } = useLocation();
  return (
    <nav className="bottom-nav" aria-label={t('nav.main')}>
      {NAV[role].map((item) => {
        const active = item.isActive(pathname);
        return (
          <NavLink key={item.to} to={item.to} end className={active ? 'is-active' : ''} aria-current={active ? 'page' : undefined}>
            <span className="nav-pill">
              <Icon name={item.icon} size={22} />
            </span>
            <span>{t(item.shortLabel ?? item.label)}</span>
          </NavLink>
        );
      })}
    </nav>
  );
}

export function AppShell({ role }: { role: Role }) {
  const { t } = useI18n();
  const { pathname } = useLocation();
  const navigate = useNavigate();
  const wide = useMediaQuery(WIDE_QUERY);
  const items = NAV[role];
  const isRoot = items.some((item) => item.to === pathname);
  const title = titleFor(pathname);

  // Back goes to the screen before this one when the user came from inside the app, otherwise to the role's home.
  const goBack = () => {
    const cameFromApp = (window.history.state as { idx?: number } | null)?.idx;
    if (cameFromApp && cameFromApp > 0) navigate(-1);
    else navigate(homeFor(role), { replace: true });
  };

  return (
    <div className={`app-shell ${wide ? 'app-shell-wide' : `app-shell-compact ${isRoot ? 'app-shell-tabs' : ''}`}`}>
      <a className="skip-link" href="#main">
        {t('nav.skip')}
      </a>
      {wide && <Sidebar role={role} />}
      <div className="app-body">
        <header className="topbar">
          {!isRoot && (
            <button type="button" className="topbar-button topbar-back" onClick={goBack} aria-label={t('common.back')}>
              <Icon name="arrowBack" className="icon-flip" />
            </button>
          )}
          {/* On a phone the home screens show the logo where other screens show their title; on a wide window the
              sidebar already carries it. */}
          {title ? (
            <h1 className="topbar-title">{t(title)}</h1>
          ) : (
            !wide && (
              <h1 className="topbar-title topbar-title-logo">
                <Logo height={28} label="Examora" />
              </h1>
            )
          )}
          {wide && (
            <div className="topbar-end">
              <LanguageToggle />
            </div>
          )}
        </header>
        <main className="app-main" id="main" tabIndex={-1}>
          <div className="app-content">
            <Outlet />
          </div>
        </main>
      </div>
      {!wide && isRoot && <BottomNav role={role} />}
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
