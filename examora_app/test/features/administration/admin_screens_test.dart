import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/administration/data/local_admin_repository.dart';
import 'package:examora_app/features/administration/presentation/admin_providers_ui.dart';
import 'package:examora_app/features/authentication/data/auth_providers.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/stored_session.dart';
import '../../support/test_harness.dart';

/// These build the REAL app and drive the administrator's screens like a person would.
void main() {
  late TestEnvironment env;
  final launched = <Uri>[];
  String? clipboard;

  setUp(() {
    env = TestEnvironment();
    launched.clear();
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  Future<void> openAsAdmin(WidgetTester tester, {bool launcherWorks = true}) async {
    await startSignedIn(env, 'admin@examora.app');
    await pumpExamora(
      tester,
      env,
      extra: [
        uriLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return launcherWorks;
        }),
      ],
    );
  }

  Future<void> createAccountThroughScreen(
    WidgetTester tester, {
    required String name,
    required String email,
    String? type,
  }) async {
    await tester.tap(find.text('Add account'));
    await tester.pumpAndSettle();
    if (type != null) {
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
    }
    await enterField(tester, 'Name', name);
    await enterField(tester, 'Email', email);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));
  }

  String shownPassword(WidgetTester tester) =>
      tester.widget<SelectableText>(find.byKey(const Key('temporary-password'))).data!;

  group('the account list', () {
    testWidgets('is the administrator home, lists students and instructors and never the administrator', (
      tester,
    ) async {
      await openAsAdmin(tester);
      expect(routerOf(tester).location, RoutePaths.adminAccounts);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Malk Mostafa'), findsOneWidget);
      expect(find.text('Ahmed Zahran'), findsOneWidget);
      expect(find.text('Mohamed Hatem'), findsNothing);
      expect(find.text('admin@examora.app'), findsNothing);
      expect(find.text('Showing 2 of 2'), findsOneWidget);
    });

    testWidgets('filters by role and by status, and says so when nothing matches', (tester) async {
      await openAsAdmin(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Instructor'));
      await tester.pumpAndSettle();
      expect(find.text('Ahmed Zahran'), findsOneWidget);
      expect(find.text('Malk Mostafa'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Deactivated'));
      await tester.pumpAndSettle();
      expect(find.text('No account matches these filters.'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'All').first);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All').last);
      await tester.pumpAndSettle();
      expect(find.text('Showing 2 of 2'), findsOneWidget);
    });

    testWidgets('the filter bar wraps instead of overflowing on a narrow window with large text', (tester) async {
      await openAsAdmin(tester);
      usePhoneWindow(tester, width: 320, height: 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.widgetWithText(ChoiceChip, 'Deactivated'), findsOneWidget);
    });

    testWidgets('shows must-change-password and locked badges in words', (tester) async {
      await openAsAdmin(tester);
      await createAccountThroughScreen(tester, name: 'Fresh Person', email: 'fresh@x.co', type: 'Student');
      await tester.tap(find.text('I have saved it'));
      await tester.pumpAndSettle();
      expect(find.text('Must change password'), findsOneWidget);
    });

    testWidgets('pages through more accounts than fit on one page', (tester) async {
      await startSignedIn(env, 'admin@examora.app');
      final repository = LocalAdminRepository(
        accounts: LocalAccountStore(store: env.keyValueStore, hasher: TestEnvironment.fastHasher, clock: env.clock),
        sessions: LocalSessionStore(env.secureStore),
        hasher: TestEnvironment.fastHasher,
        clock: env.clock,
      );
      for (var i = 0; i < 21; i++) {
        env.clock.advance(const Duration(minutes: 1));
        await repository.createAccount(role: UserRole.student, fullName: 'Person $i', email: 'p$i@x.co');
      }
      await pumpExamora(tester, env);

      expect(find.text('Showing 20 of 23'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Previous')).onPressed, isNull);
      await tapVisible(tester, find.widgetWithText(TextButton, 'Next'));
      expect(find.text('Showing 3 of 23'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Malk Mostafa'), findsOneWidget, reason: 'oldest accounts are last');
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Next')).onPressed, isNull);

      // Changing a filter returns to page 1.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Instructor'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1'), findsOneWidget);
    });
  });

  group('the account detail', () {
    testWidgets('shows every field, times in the device zone with the zone named, and pushes (so Back works)', (
      tester,
    ) async {
      await openAsAdmin(tester);
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).location, startsWith('/admin/accounts/'));
      for (final label in ['Email', 'Role', 'Account status', 'Sign-in lock', 'Created', 'Last sign-in']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('student@examora.app'), findsOneWidget);
      expect(find.text('Never'), findsOneWidget);
      expect(find.textContaining("Times are shown in this device's time zone: UTC"), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(routerOf(tester).location, RoutePaths.adminAccounts);
    });

    testWidgets('deactivating needs a reason, records it, and the person can no longer sign in', (tester) async {
      await openAsAdmin(tester);
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Deactivate account'));
      expect(find.text('Deactivate this account?'), findsOneWidget);

      // Blank reason: refused on the dialog, nothing changed.
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Deactivate account'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Left the course',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Deactivate account'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account deactivated.'), findsOneWidget);
      expect(find.text('Left the course'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reactivate account'), findsOneWidget);
      expect(
        (await containerOf(tester).read(localAccountStoreProvider).findByEmail('student@examora.app'))!.status,
        AccountStatus.deactivated,
      );
    });

    testWidgets('a deactivated account can be reactivated with no reason', (tester) async {
      await openAsAdmin(tester);
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Deactivate account'));
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'x');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Deactivate account'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Reactivate account'));
      expect(find.text('Reactivate this account?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Reactivate account'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account reactivated.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Deactivate account'), findsOneWidget);
    });

    testWidgets('cancelling a dialog changes nothing', (tester) async {
      await openAsAdmin(tester);
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Deactivate account'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Deactivate account'), findsOneWidget);
      expect(find.text('Account deactivated.'), findsNothing);
    });

    testWidgets('a status change that no longer applies is reported as a conflict, and the screen shows the truth', (
      tester,
    ) async {
      await openAsAdmin(tester);
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();
      // Somebody else deactivates the account while this screen still shows it as active.
      final accounts = containerOf(tester).read(localAccountStoreProvider);
      final stored = (await accounts.findByEmail('student@examora.app'))!;
      await accounts.replace(stored.copyWith(status: AccountStatus.deactivated));

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Deactivate account'));
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'x');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Deactivate account'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('The account is already deactivated.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reactivate account'), findsOneWidget);
    });

    testWidgets('issuing a temporary password asks first, shows it once, and the person must then change it', (
      tester,
    ) async {
      await openAsAdmin(tester);
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Issue temporary password'));
      expect(find.text('Issue a temporary password?'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Issue temporary password'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Temporary password'), findsOneWidget);
      final password = shownPassword(tester);
      expect(Validators.newPassword(password), isNull);
      await tester.tap(find.text('I have saved it'));
      await tester.pumpAndSettle();

      // The password is gone from the screen and cannot be reopened.
      expect(find.text(password), findsNothing);
      expect(find.text('Must change password'), findsWidgets);

      // The old password stopped working.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      await signInThroughScreen(tester, email: 'student@examora.app', password: 'Examora#2026');
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      await signInThroughScreen(tester, email: 'student@examora.app', password: password);
      expect(find.text('Choose a new password'), findsOneWidget);
    });
  });

  group('creating an account', () {
    testWidgets('is one screen with a segmented control, defaulting to Instructor', (tester) async {
      await openAsAdmin(tester);
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      expect(routerOf(tester).location, RoutePaths.adminNewInstructor);
      final control = tester.widget<SegmentedButton<UserRole>>(find.byType(SegmentedButton<UserRole>));
      expect(control.selected, {UserRole.instructor});
      expect(control.segments.map((s) => s.value), [UserRole.instructor, UserRole.student]);
    });

    testWidgets('refuses blank and malformed input on screen', (tester) async {
      await openAsAdmin(tester);
      await tester.tap(find.text('Add account'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));
      expect(find.text('This field is required.'), findsNWidgets(2));
      await enterField(tester, 'Name', 'Dr. Sara');
      await enterField(tester, 'Email', 'not-an-email');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Create account'));
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('a duplicate email is a clear conflict and keeps what was typed', (tester) async {
      await openAsAdmin(tester);
      await createAccountThroughScreen(tester, name: 'Copy Cat', email: 'STUDENT@examora.app');
      expect(find.text('An account with this email already exists.'), findsOneWidget);
      expect(find.text('Temporary password'), findsNothing);
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Name')).controller!.text, 'Copy Cat');
    });

    testWidgets('END TO END: the instructor created here signs in with the password shown, then must change it', (
      tester,
    ) async {
      await openAsAdmin(tester);
      await createAccountThroughScreen(tester, name: 'Dr. Sara Nabil', email: 'Sara@Uni.edu');

      // The one-time sheet.
      expect(find.text('Temporary password'), findsOneWidget);
      expect(find.textContaining('shown only once'), findsOneWidget);
      expect(find.text('For Dr. Sara Nabil (sara@uni.edu)'), findsOneWidget);
      final password = shownPassword(tester);
      expect(password.length, 16);

      // It cannot be dismissed by tapping outside it or going back.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Temporary password'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Temporary password'), findsOneWidget);

      // Copy.
      await tester.tap(find.text('Copy password'));
      await tester.pumpAndSettle();
      expect(clipboard, password);
      expect(find.text('Password copied.'), findsOneWidget);

      // Send by email: a mailto: link carrying the address, a subject and the password.
      await tester.tap(find.text('Send by email'));
      await tester.pumpAndSettle();
      final mail = launched.single;
      expect(mail.scheme, 'mailto');
      expect(Uri.decodeComponent(mail.path), 'sara@uni.edu');
      expect(mail.queryParameters['subject'], 'Your Examora temporary password');
      expect(mail.queryParameters['body'], contains(password));
      expect(mail.query.contains('+'), isFalse, reason: 'spaces must be %20, not +');

      await tester.tap(find.text('I have saved it'));
      await tester.pumpAndSettle();

      // Back on the list, with the new account on top; the password is gone.
      expect(routerOf(tester).location, RoutePaths.adminAccounts);
      expect(find.text(password), findsNothing);
      expect(find.text('Dr. Sara Nabil'), findsOneWidget);
      expect(find.text('Showing 3 of 3'), findsOneWidget);

      // Sign out and sign in as the new instructor through the real sign-in screen.
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign out'));
      await signInThroughScreen(tester, email: 'sara@uni.edu', password: password);
      expect(find.text('Choose a new password'), findsOneWidget);

      await enterField(tester, 'Current password', password);
      await enterField(tester, 'New password', 'Brand#New2026');
      await enterField(tester, 'Repeat the new password', 'Brand#New2026');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Change password'));
      expect(routerOf(tester).location, RoutePaths.instructorDashboard);

      // The temporary password never worked twice: after the change only the new one does.
      await tester.pump(const Duration(seconds: 6)); // let the "password changed" message go
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign out'));
      await signInThroughScreen(tester, email: 'sara@uni.edu', password: password);
      expect(find.text('Incorrect email or password.'), findsOneWidget);
      await signInThroughScreen(tester, email: 'sara@uni.edu', password: 'Brand#New2026');
      // Signing back in resumes the page that was open when the session ended (here the profile), inside the instructor area.
      expect(routerOf(tester).location, RoutePaths.instructorProfile);
    });

    testWidgets('END TO END: a student created here lands on the student home after changing the password', (
      tester,
    ) async {
      await openAsAdmin(tester);
      await createAccountThroughScreen(tester, name: 'Omar Ali', email: 'omar@uni.edu', type: 'Student');
      final password = shownPassword(tester);
      await tester.tap(find.text('I have saved it'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Sign out'));
      await signInThroughScreen(tester, email: 'omar@uni.edu', password: password);
      await enterField(tester, 'Current password', password);
      await enterField(tester, 'New password', 'Brand#New2026');
      await enterField(tester, 'Repeat the new password', 'Brand#New2026');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Change password'));
      expect(routerOf(tester).location, RoutePaths.studentDashboard);
    });

    testWidgets('when no email app exists, says so and the password is still on screen to copy', (tester) async {
      await openAsAdmin(tester, launcherWorks: false);
      await createAccountThroughScreen(tester, name: 'Dr. Sara Nabil', email: 'sara@uni.edu');
      await tester.tap(find.text('Send by email'));
      await tester.pumpAndSettle();
      expect(find.text('No email app could be opened on this device. Copy the password instead.'), findsOneWidget);
      expect(find.byKey(const Key('temporary-password')), findsOneWidget);
    });

    testWidgets('the password is never written to the stored data', (tester) async {
      await openAsAdmin(tester);
      await createAccountThroughScreen(tester, name: 'Dr. Sara Nabil', email: 'sara@uni.edu');
      final password = shownPassword(tester);
      await tester.tap(find.text('I have saved it'));
      await tester.pumpAndSettle();
      expect(env.keyValueStore.values.values.any((v) => v.contains(password)), isFalse);
      expect(env.secureStore.values.values.any((v) => v.contains(password)), isFalse);
    });
  });

  group('Arabic', () {
    testWidgets('the list, detail and create screens are Arabic and right-to-left', (tester) async {
      env = TestEnvironment(language: 'ar');
      await startSignedIn(env, 'admin@examora.app');
      await pumpExamora(tester, env);
      expect(find.text('الحسابات'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('الحسابات'))), TextDirection.rtl);
      expect(find.text('إضافة حساب'), findsOneWidget);
      expect(find.text('طالب'), findsWidgets);

      await tester.tap(find.text('إضافة حساب'));
      await tester.pumpAndSettle();
      expect(find.text('إنشاء حساب'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('who can reach the administrator screens', () {
    for (final entry in {
      'student@examora.app': RoutePaths.studentDashboard,
      'instructor@examora.app': RoutePaths.instructorDashboard,
    }.entries) {
      testWidgets('${entry.key} is turned away from /admin/accounts', (tester) async {
        await startSignedIn(env, entry.key);
        await pumpExamora(tester, env, initialLocation: RoutePaths.adminAccounts);
        expect(routerOf(tester).location, entry.value);
        expect(find.text('Add account'), findsNothing);
      });
    }

    testWidgets('a signed-out visitor is sent to sign-in', (tester) async {
      await pumpExamora(tester, env, initialLocation: RoutePaths.adminNewInstructor);
      expect(routerOf(tester).location, startsWith(RoutePaths.login));
    });
  });
}
