import 'package:examora_app/app/router/app_router.dart';
import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stored_session.dart';
import '../support/test_harness.dart';

void main() {
  group('deep links cannot bypass sign-in', () {
    for (final link in [
      RoutePaths.studentDashboard,
      '/student/exams/abc',
      '/student/attempts/a1',
      '/student/attempts/a1/result',
      RoutePaths.instructorDashboard,
      '/instructor/exams/new/method',
      '/instructor/exams/e1/edit',
      '/instructor/incidents/i1',
      RoutePaths.adminAccounts,
      '/admin/accounts/acc-1',
      RoutePaths.adminNewInstructor,
      RoutePaths.changePassword,
    ]) {
      testWidgets('signed out: $link shows sign-in and nothing of the protected screen', (tester) async {
        await pumpExamora(tester, TestEnvironment(), initialLocation: link);

        expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
        expect(find.text('Not built yet'), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
      });
    }

    testWidgets('after signing in, the remembered link is followed when it belongs to the role', (tester) async {
      await pumpExamora(tester, TestEnvironment(), initialLocation: '/student/exams/abc');
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

      await signInThroughScreen(tester, email: 'student@examora.app', password: 'Examora#2026');

      expect(routerOf(tester).location, '/student/exams/abc');
      expect(find.text('The requested item was not found.'), findsWidgets);
    });

    testWidgets('a remembered link from ANOTHER role is dropped: the user lands on their own home', (tester) async {
      await pumpExamora(tester, TestEnvironment(), initialLocation: '/admin/accounts');
      await signInThroughScreen(tester, email: 'student@examora.app', password: 'Examora#2026');
      expect(routerOf(tester).location, RoutePaths.studentDashboard);
    });
  });

  group('roles cannot cross', () {
    const crossings = <(String, String, String)>[
      ('student@examora.app', '/instructor/dashboard', RoutePaths.studentDashboard),
      ('student@examora.app', '/instructor/exams/e1/import', RoutePaths.studentDashboard),
      ('student@examora.app', '/admin/accounts', RoutePaths.studentDashboard),
      ('student@examora.app', '/admin/instructors/new', RoutePaths.studentDashboard),
      ('instructor@examora.app', '/student/exams', RoutePaths.instructorDashboard),
      ('instructor@examora.app', '/student/attempts/a1', RoutePaths.instructorDashboard),
      ('instructor@examora.app', '/admin/accounts', RoutePaths.instructorDashboard),
      ('admin@examora.app', '/student/dashboard', RoutePaths.adminAccounts),
      ('admin@examora.app', '/instructor/incidents', RoutePaths.adminAccounts),
      ('admin@examora.app', '/instructor/exams/new/method', RoutePaths.adminAccounts),
    ];
    for (final (email, link, home) in crossings) {
      testWidgets('$email opening $link ends on $home', (tester) async {
        final env = TestEnvironment();
        await startSignedIn(env, email);
        await pumpExamora(tester, env, initialLocation: link);
        expect(routerOf(tester).location, home);
      });
    }

    testWidgets('a signed-in user cannot go back to sign-in', (tester) async {
      final env = TestEnvironment();
      await startSignedIn(env, 'student@examora.app');
      await pumpExamora(tester, env, initialLocation: RoutePaths.login);
      expect(routerOf(tester).location, RoutePaths.studentDashboard);
    });

    testWidgets('an unknown path never strands a signed-in user', (tester) async {
      final env = TestEnvironment();
      await startSignedIn(env, 'instructor@examora.app');
      await pumpExamora(tester, env, initialLocation: '/does/not/exist');
      expect(routerOf(tester).location, RoutePaths.instructorDashboard);
    });

    testWidgets('a stored session resumes the deep link it was opened with', (tester) async {
      final env = TestEnvironment();
      await startSignedIn(env, 'student@examora.app');
      await pumpExamora(tester, env, initialLocation: '/student/attempts/a1/result');
      expect(routerOf(tester).location, '/student/attempts/a1/result');
      expect(find.text('The requested item was not found.'), findsWidgets);
    });
  });

  group('the forced password change gate', () {
    Future<TestEnvironment> forcedStudent() async {
      final env = TestEnvironment();
      await editStoredAccount(
        env,
        'student@examora.app',
        (account) => account.copyWith(
          mustChangePassword: true,
          temporaryPasswordExpiresAt: Nullable(env.clock.now().add(const Duration(hours: 72))),
        ),
      );
      return env;
    }

    testWidgets('signing in with a temporary password lands on change-password, with the reason and a sign-out', (
      tester,
    ) async {
      final env = await forcedStudent();
      await pumpExamora(tester, env);

      await signInThroughScreen(tester, email: 'student@examora.app', password: 'Examora#2026');

      expect(routerOf(tester).location, RoutePaths.changePassword);
      expect(find.text('Choose a new password'), findsWidgets);
      expect(find.textContaining('temporary password'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sign out instead'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    for (final link in [
      '/student/dashboard',
      '/student/exams/x',
      '/instructor/dashboard',
      '/admin/accounts',
      '/login',
      '/',
    ]) {
      testWidgets('no deep link escapes it: $link', (tester) async {
        final env = await forcedStudent();
        await startSignedIn(env, 'student@examora.app');
        await pumpExamora(tester, env, initialLocation: link);
        expect(routerOf(tester).location, RoutePaths.changePassword);
      });
    }

    testWidgets('a forced screen is restored after a restart (the gate survives killing the app)', (tester) async {
      final env = await forcedStudent();
      await startSignedIn(env, 'student@examora.app');
      await pumpExamora(tester, env);
      expect(routerOf(tester).location, RoutePaths.changePassword);
    });

    testWidgets('choosing a new password releases the gate and goes to the role home', (tester) async {
      final env = await forcedStudent();
      await pumpExamora(tester, env);
      await signInThroughScreen(tester, email: 'student@examora.app', password: 'Examora#2026');

      await enterField(tester, 'Current password', 'Examora#2026');
      await enterField(tester, 'New password', 'Brand#New2027');
      await enterField(tester, 'Repeat the new password', 'Brand#New2027');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).location, RoutePaths.studentDashboard);
      expect(find.text('Welcome, Malk Mostafa'), findsOneWidget);
    });

    testWidgets('a mismatched confirmation, a weak password and a wrong current password are each refused on screen', (
      tester,
    ) async {
      final env = await forcedStudent();
      await pumpExamora(tester, env);
      await signInThroughScreen(tester, email: 'student@examora.app', password: 'Examora#2026');

      await enterField(tester, 'Current password', 'Examora#2026');
      await enterField(tester, 'New password', 'Brand#New2027');
      await enterField(tester, 'Repeat the new password', 'Different#2027');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();
      expect(find.text('The passwords do not match.'), findsOneWidget);

      await enterField(tester, 'New password', 'weak');
      await enterField(tester, 'Repeat the new password', 'weak');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 8 characters'), findsWidgets);

      await enterField(tester, 'Current password', 'wrong-current');
      await enterField(tester, 'New password', 'Brand#New2027');
      await enterField(tester, 'Repeat the new password', 'Brand#New2027');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();
      expect(find.text('The current password is incorrect.'), findsOneWidget);
      expect(routerOf(tester).location, RoutePaths.changePassword);
    });

    testWidgets('the user can sign out from the forced screen', (tester) async {
      final env = await forcedStudent();
      await pumpExamora(tester, env);
      await signInThroughScreen(tester, email: 'student@examora.app', password: 'Examora#2026');

      await tester.tap(find.widgetWithText(TextButton, 'Sign out instead'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });
  });

  group('voluntary password change', () {
    testWidgets('opens from the profile, has a way back, and returns to the profile after success', (tester) async {
      final env = TestEnvironment();
      await startSignedIn(env, 'student@examora.app');
      await pumpExamora(tester, env, initialLocation: RoutePaths.studentProfile);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Change password'));
      expect(routerOf(tester).location, RoutePaths.changePassword);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(routerOf(tester).location, RoutePaths.studentProfile);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Change password'));
      await enterField(tester, 'Current password', 'Examora#2026');
      await enterField(tester, 'New password', 'Brand#New2027');
      await enterField(tester, 'Repeat the new password', 'Brand#New2027');
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).location, RoutePaths.studentProfile);
      expect(find.text('Your password was changed.'), findsOneWidget);
    });
  });

  group('every screen has a way back out', () {
    Future<void> openAs(WidgetTester tester, String email, String link) async {
      final env = TestEnvironment();
      await startSignedIn(env, email);
      await pumpExamora(tester, env, initialLocation: link);
    }

    final fullScreens = <(String, String)>[
      ('student@examora.app', '/student/exams/abc'),
      ('student@examora.app', '/student/exams/abc/consent'),
      ('student@examora.app', '/student/exams/abc/system-check'),
      ('student@examora.app', '/student/attempts/a1'),
      ('student@examora.app', '/student/attempts/a1/result'),
      ('instructor@examora.app', '/instructor/exams/new/method'),
      ('instructor@examora.app', '/instructor/exams/e1/edit'),
      ('instructor@examora.app', '/instructor/exams/e1/import'),
      ('instructor@examora.app', '/instructor/exams/e1/attempts'),
      ('instructor@examora.app', '/instructor/incidents/i1'),
      ('admin@examora.app', '/admin/accounts/acc-1'),
      ('admin@examora.app', '/admin/instructors/new'),
      ('admin@examora.app', '/admin/profile'),
    ];
    for (final (email, link) in fullScreens) {
      testWidgets('$link opened by a link: the leading button always leads out, to the role home', (tester) async {
        await openAs(tester, email, link);
        expect(routerOf(tester).location, link);
        const homes = [RoutePaths.studentDashboard, RoutePaths.instructorDashboard, RoutePaths.adminAccounts];

        // A nested route (consent, result, account detail) first goes back to its parent screen, which has its own button.
        for (var step = 0; step < 3 && !homes.contains(routerOf(tester).location); step++) {
          expect(find.byType(BackOrHomeButton), findsOneWidget, reason: 'step $step on ${routerOf(tester).location}');
          await tester.tap(find.byType(BackOrHomeButton));
          await tester.pumpAndSettle();
        }

        expect(homes, contains(routerOf(tester).location));
      });
    }

    testWidgets('every administrator screen is PUSHED, so the back button returns to the account list', (tester) async {
      await openAs(tester, 'admin@examora.app', RoutePaths.adminAccounts);

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Profile')), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget, reason: 'a pushed screen offers back, not just home');
      expect(find.byIcon(Icons.home_outlined), findsNothing);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(routerOf(tester).location, RoutePaths.adminAccounts);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Accounts')), findsOneWidget);
    });

    testWidgets('the student and instructor tabs switch without losing the shell', (tester) async {
      await openAs(tester, 'student@examora.app', RoutePaths.studentDashboard);
      await tester.tap(find.text('Results'));
      await tester.pumpAndSettle();
      expect(routerOf(tester).location, RoutePaths.studentResults);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(routerOf(tester).location, RoutePaths.studentProfile);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  testWidgets('literal routes are matched before :id siblings ("new" is never read as an id)', (tester) async {
    final env = TestEnvironment();
    await startSignedIn(env, 'instructor@examora.app');
    await pumpExamora(tester, env, initialLocation: RoutePaths.instructorNewExamMethod);
    expect(find.text('How do you want to create the exam?'), findsOneWidget);
    expect(find.textContaining('Step 1 of 5'), findsNothing, reason: '"new/method" must not be read as exam id "new"');

    containerOf(tester).read(routerProvider).go(RoutePaths.adminNewInstructor);
    await tester.pumpAndSettle();
    expect(
      routerOf(tester).location,
      RoutePaths.instructorDashboard,
      reason: 'an instructor must not reach an admin route',
    );
  });
}
