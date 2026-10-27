import 'package:examora_app/app/router/app_router.dart';
import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/features/authentication/data/auth_providers.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stored_session.dart';
import '../support/test_harness.dart';

/// These tests build the REAL app - real router, real guard, real controllers, real screens. Only storage, the clock
/// and the hashing cost are replaced.
void main() {
  group('launch and the sign-in screen', () {
    testWidgets('holds on the splash while the stored session is read, then shows sign-in', (tester) async {
      final env = TestEnvironment();
      await pumpExamora(tester, env, settle: false);
      expect(find.text('Restoring your session…'), findsOneWidget);
      expect(find.text('Email'), findsNothing, reason: 'the sign-in screen must not flash before the session is known');

      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(routerOf(tester).location, startsWith(RoutePaths.login));
    });

    testWidgets('has no registration path and says who creates accounts', (tester) async {
      await pumpExamora(tester, TestEnvironment());

      expect(find.text('Accounts are created by your administrator.'), findsOneWidget);
      for (final forbidden in ['Create account', 'Sign up', 'Register', 'Create an account', 'Join']) {
        expect(find.textContaining(forbidden, findRichText: true), findsNothing, reason: forbidden);
      }
      expect(find.text('Forgot your password?'), findsOneWidget);
    });

    testWidgets('has no AI-generation or demo-mode wording anywhere on the sign-in screen', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      for (final forbidden in ['demo', 'Demo', 'AI', 'sample data', 'fake']) {
        expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
      }
    });

    testWidgets('blank fields are refused on screen, with a message under each field', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsNWidgets(2));
      expect(routerOf(tester).location, startsWith(RoutePaths.login));
    });

    testWidgets('the password is hidden until the reveal button is pressed', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      TextField password() => tester.widget<TextField>(find.widgetWithText(TextField, 'Password'));
      expect(password().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(password().obscureText, isFalse);
    });
  });

  group('the three seeded accounts sign in through the real screen and land on the right home', () {
    testWidgets('student', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      await signInThroughScreen(tester, email: 'student@examora.app', password: 'Examora#2026');

      expect(routerOf(tester).location, RoutePaths.studentDashboard);
      expect(find.text('Welcome, Malk Mostafa'), findsOneWidget);
      expect(find.text('Student'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Results'), findsOneWidget);
    });

    testWidgets('instructor', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      await signInThroughScreen(tester, email: 'instructor@examora.app', password: 'Examora#2026');

      expect(routerOf(tester).location, RoutePaths.instructorDashboard);
      expect(find.text('Welcome, Ahmed Zahran'), findsOneWidget);
      expect(find.text('Incidents'), findsWidgets);
    });

    testWidgets('administrator', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      await signInThroughScreen(tester, email: 'admin@examora.app', password: 'Examora#2026');

      expect(routerOf(tester).location, RoutePaths.adminAccounts);
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Accounts')), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing, reason: 'the admin area has no bottom navigation');
    });
  });

  group('failed sign-in', () {
    testWidgets('a wrong password and an unknown email show the SAME message', (tester) async {
      await pumpExamora(tester, TestEnvironment());

      await signInThroughScreen(tester, email: 'student@examora.app', password: 'wrong-password');
      final afterWrongPassword = tester.widgetList<Text>(find.text('Incorrect email or password.')).length;
      expect(find.text('Incorrect email or password.'), findsOneWidget);

      await signInThroughScreen(tester, email: 'nobody@examora.app', password: 'Examora#2026');
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      expect(afterWrongPassword, 1);
      expect(routerOf(tester).location, startsWith(RoutePaths.login));
    });

    testWidgets('the password field is cleared after a failure', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      await signInThroughScreen(tester, email: 'student@examora.app', password: 'wrong-password');
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Password')).controller!.text, isEmpty);
    });

    testWidgets('five wrong passwords lock the account and the screen says so', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      for (var i = 0; i < 5; i++) {
        await signInThroughScreen(tester, email: 'student@examora.app', password: 'wrong$i');
      }
      expect(find.textContaining('temporarily locked'), findsOneWidget);
    });
  });

  group('forgot password', () {
    testWidgets('explains there is no automatic reset and returns to sign-in', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      await tester.tap(find.text('Forgot your password?'));
      await tester.pumpAndSettle();

      expect(find.textContaining('no automatic password reset'), findsOneWidget);
      expect(find.textContaining('administrator'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Back to sign in'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('opened directly by a link it still has a way back to sign-in', (tester) async {
      await pumpExamora(tester, TestEnvironment(), initialLocation: RoutePaths.forgotPassword);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(routerOf(tester).location, RoutePaths.login);
    });
  });

  group('sessions', () {
    testWidgets('a stored session skips the sign-in screen entirely', (tester) async {
      final env = TestEnvironment();
      await startSignedIn(env, 'instructor@examora.app');

      await pumpExamora(tester, env);

      expect(find.text('Welcome, Ahmed Zahran'), findsOneWidget);
      expect(routerOf(tester).location, RoutePaths.instructorDashboard);
    });

    testWidgets('a session older than 12 hours does not restore', (tester) async {
      final env = TestEnvironment();
      await startSignedIn(env, 'student@examora.app');
      env.clock.advance(const Duration(hours: 12, seconds: 1));

      await pumpExamora(tester, env);

      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('signing out from the profile returns to sign-in and the stored session is gone', (tester) async {
      final env = TestEnvironment();
      await startSignedIn(env, 'student@examora.app');
      await pumpExamora(tester, env, initialLocation: RoutePaths.studentProfile);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign out'));

      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(env.secureStore.values, isEmpty);
      expect(containerOf(tester).read(authControllerProvider), isA<AuthSignedOut>());
    });

    testWidgets('after signing out, navigating to a protected screen is refused', (tester) async {
      final env = TestEnvironment();
      await startSignedIn(env, 'student@examora.app');
      await pumpExamora(tester, env, initialLocation: RoutePaths.studentProfile);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign out'));

      containerOf(tester).read(routerProvider).go(RoutePaths.studentDashboard);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
      expect(find.text('Welcome, Malk Mostafa'), findsNothing);
    });

    testWidgets('an account created by an administrator-style edit can sign in with the password it was given', (
      tester,
    ) async {
      // The end-to-end proof for the admin screen comes with that screen; this checks the underlying promise: a stored
      // account whose hash was made with the shared hasher signs in through the real screen.
      final env = TestEnvironment();
      await pumpExamora(tester, env);
      final container = containerOf(tester);
      final accounts = container.read(localAccountStoreProvider);
      final hash = await TestEnvironment.fastHasher.hash('Temp#Pass1');
      await accounts.mutate((list) {
        list.add(
          StoredAccount(
            id: 'new-1',
            fullName: 'New Student',
            email: 'new.student@example.edu',
            role: UserRole.student,
            passwordHash: hash,
            mustChangePassword: false,
            status: AccountStatus.active,
            createdAt: env.clock.now(),
          ),
        );
      });

      await signInThroughScreen(tester, email: 'new.student@example.edu', password: 'Temp#Pass1');

      expect(find.text('Welcome, New Student'), findsOneWidget);
    });
  });
}
