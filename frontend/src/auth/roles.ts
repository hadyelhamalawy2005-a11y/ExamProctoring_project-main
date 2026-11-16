import type { Role } from '../types/api';

// Where each role lands after signing in, and which part of the URL space belongs to which role.
// Instructor pages keep their original URLs (/exams, /import) so existing links and bookmarks keep working; /instructor
// is accepted as an entry point. The backend enforces the role on every request: this only shapes the interface.

export const ROLE_HOME: Record<Role, string> = {
  Admin: '/admin/accounts',
  Instructor: '/instructor',
  Student: '/student',
};

export const homeFor = (role: Role): string => ROLE_HOME[role];

const underPrefix = (path: string, prefix: string) => path === prefix || path.startsWith(`${prefix}/`);

// The role whose area a path belongs to. Anything that is not under /admin or /student is instructor space.
export function roleForPath(path: string): Role | null {
  const pathname = path.split(/[?#]/)[0];
  if (underPrefix(pathname, '/admin')) return 'Admin';
  if (underPrefix(pathname, '/student')) return 'Student';
  if (
    underPrefix(pathname, '/instructor') ||
    underPrefix(pathname, '/exams') ||
    underPrefix(pathname, '/import') ||
    underPrefix(pathname, '/incidents')
  ) {
    return 'Instructor';
  }
  return null;
}

// A remembered "come back to" address is followed only when it belongs to the signed-in role; otherwise the role's own
// home is used, so signing in never lands anybody on a page they cannot open.
export function landingFor(role: Role, from: string | undefined): string {
  if (from && from.startsWith('/') && !from.startsWith('//') && roleForPath(from) === role) return from;
  return homeFor(role);
}
