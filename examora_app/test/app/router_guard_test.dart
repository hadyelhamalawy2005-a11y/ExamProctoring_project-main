import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/router/router_guard.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Account account(UserRole role, {bool mustChange = false}) => Account(
  id: 'id-${role.name}',
  fullName: 'N',
  email: '${role.name}@examora.app',
  role: role,
  mustChangePassword: mustChange,
);

String? redirect(AuthState auth, String location) => resolveRedirect(auth: auth, location: Uri.parse(location));

void main() {
  const resolving = AuthResolving();
  const signedOut = AuthSignedOut();
  final student = AuthSignedIn(account(UserRole.student));
  final instructor = AuthSignedIn(account(UserRole.instructor));
  final admin = AuthSignedIn(account(UserRole.administrator));

  group('1. while the session is being resolved', () {
    test('the splash screen is held', () {
      expect(redirect(resolving, '/'), isNull);
    });

    test('any other location is sent to the splash, remembering where it was going', () {
      final target = redirect(resolving, '/student/exams/abc')!;
      final uri = Uri.parse(target);
      expect(uri.path, '/');
      expect(uri.queryParameters['from'], '/student/exams/abc');
    });

    test('even the login screen waits, so a signed-in user is never flashed it on launch', () {
      expect(Uri.parse(redirect(resolving, '/login')!).path, '/');
    });
  });

  group('2. signed out: only the auth routes', () {
    test('login and forgot-password are reachable', () {
      expect(redirect(signedOut, '/login'), isNull);
      expect(redirect(signedOut, '/forgot-password'), isNull);
    });

    test('the splash goes to login', () {
      expect(redirect(signedOut, '/'), '/login');
    });

    test('every protected area redirects to login, remembering the link', () {
      for (final path in [
        '/student/dashboard',
        '/student/attempts/a1',
        '/instructor/exams/e1/edit',
        '/admin/accounts',
        '/change-password',
        '/nowhere',
      ]) {
        final uri = Uri.parse(redirect(signedOut, path)!);
        expect(uri.path, '/login', reason: path);
        expect(uri.queryParameters['from'], path, reason: path);
      }
    });

    test('the splash keeps the remembered link for after sign-in', () {
      final uri = Uri.parse(redirect(signedOut, '/?from=%2Fstudent%2Fexams%2Fabc')!);
      expect(uri.path, '/login');
      expect(uri.queryParameters['from'], '/student/exams/abc');
    });

    test('an external or protocol-relative "from" is ignored', () {
      expect(redirect(signedOut, '/?from=https%3A%2F%2Fevil.example'), '/login');
      expect(redirect(signedOut, '/?from=%2F%2Fevil.example'), '/login');
    });
  });

  group('3. a pending password change outranks everything', () {
    final forced = {
      UserRole.student: AuthSignedIn(account(UserRole.student, mustChange: true)),
      UserRole.instructor: AuthSignedIn(account(UserRole.instructor, mustChange: true)),
      UserRole.administrator: AuthSignedIn(account(UserRole.administrator, mustChange: true)),
    };

    test('change-password is the only reachable screen for every role', () {
      for (final entry in forced.entries) {
        expect(redirect(entry.value, '/change-password'), isNull, reason: entry.key.name);
        for (final path in [
          '/',
          '/login',
          homeFor(entry.key),
          '/student/dashboard',
          '/admin/accounts',
          '/instructor/exams',
        ]) {
          expect(redirect(entry.value, path), '/change-password', reason: '${entry.key.name} $path');
        }
      }
    });
  });

  group('4. role separation', () {
    test('each role stays in its own area', () {
      expect(redirect(student, '/student/exams'), isNull);
      expect(redirect(student, '/student/attempts/a1/result'), isNull);
      expect(redirect(instructor, '/instructor/exams/e1/import'), isNull);
      expect(redirect(admin, '/admin/instructors/new'), isNull);
    });

    test('a role entering another area is sent to its OWN home, not a dead end', () {
      expect(redirect(student, '/instructor/dashboard'), RoutePaths.studentDashboard);
      expect(redirect(student, '/admin/accounts'), RoutePaths.studentDashboard);
      expect(redirect(instructor, '/student/exams'), RoutePaths.instructorDashboard);
      expect(redirect(instructor, '/admin/accounts'), RoutePaths.instructorDashboard);
      expect(redirect(admin, '/student/dashboard'), RoutePaths.adminAccounts);
      expect(redirect(admin, '/instructor/exams/new/method'), RoutePaths.adminAccounts);
    });

    test('a path that merely starts with the same letters is not inside the area', () {
      expect(redirect(student, '/students'), RoutePaths.studentDashboard);
      expect(redirect(admin, '/administrator'), RoutePaths.adminAccounts);
    });

    test('signed in, the auth screens go home', () {
      expect(redirect(student, '/login'), RoutePaths.studentDashboard);
      expect(redirect(instructor, '/forgot-password'), RoutePaths.instructorDashboard);
      expect(redirect(admin, '/login'), RoutePaths.adminAccounts);
    });

    test('the splash resumes the remembered link only when it belongs to the role', () {
      expect(redirect(student, '/?from=%2Fstudent%2Fexams%2Fabc'), '/student/exams/abc');
      expect(redirect(student, '/?from=%2Fadmin%2Faccounts'), RoutePaths.studentDashboard);
      expect(redirect(student, '/'), RoutePaths.studentDashboard);
      expect(redirect(student, '/?from=https%3A%2F%2Fevil.example'), RoutePaths.studentDashboard);
    });

    test('change-password is open to everyone who is signed in (voluntary change)', () {
      for (final auth in [student, instructor, admin]) {
        expect(redirect(auth, '/change-password'), isNull);
      }
    });

    test('an unknown path never strands a signed-in user', () {
      expect(redirect(student, '/nowhere'), RoutePaths.studentDashboard);
    });
  });

  test('the session-ended notice does not change where a signed-out user is sent', () {
    expect(redirect(const AuthSignedOut(notice: SessionExpiredFailure()), '/student/dashboard'), startsWith('/login'));
  });

  test('literal route paths never collide with their :id siblings', () {
    expect(RoutePaths.instructorNewExamMethod, '/instructor/exams/new/method');
    expect(RoutePaths.adminNewInstructor, '/admin/instructors/new');
    expect(RoutePaths.instructorExamEdit('new'), '/instructor/exams/new/edit');
  });
}
