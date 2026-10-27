import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/locale_controller.dart';
import 'package:examora_app/core/l10n/planned_feature.dart';
import 'package:examora_app/core/l10n/strings_ar.dart';
import 'package:examora_app/core/l10n/strings_en.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/stored_session.dart';
import '../support/test_harness.dart';

void main() {
  const english = EnglishStrings();
  const arabic = ArabicStrings();

  group('the two languages say the same things', () {
    final failures = <AppFailure>[
      const ValidationFailure(),
      const ValidationFailure(fields: {'email': KnownFieldProblem(FieldReason.invalidEmail)}),
      const InvalidCredentialsFailure(),
      const AccountLockedFailure(),
      const AccountDeactivatedFailure(),
      const TemporaryPasswordExpiredFailure(),
      const SessionExpiredFailure(),
      const PasswordChangeRequiredFailure(),
      const ForbiddenFailure(),
      const NotFoundFailure(),
      const ConflictFailure(),
      const ConflictFailure(serverDetail: 'The exam has no questions.'),
      const NetworkFailure(),
      const TimeoutFailure(),
      const RateLimitedFailure(),
      const ServerFailure(statusCode: 500),
      const StorageFailure(),
      const ParseFailure(field: 'user.role', problem: 'is missing'),
      const EndpointMissingFailure(endpoint: 'POST /api/attempts'),
      const UnavailableFailure(capability: 'The video buffer', because: 'no plugin supports it'),
    ];

    test('every failure has a non-empty text in both languages, and Arabic differs from English', () {
      for (final failure in failures) {
        final en = english.failureMessage(failure);
        final ar = arabic.failureMessage(failure);
        expect(en, isNotEmpty, reason: failure.toString());
        expect(ar, isNotEmpty, reason: failure.toString());
        if (failure is! ConflictFailure || failure.serverDetail == null) {
          expect(ar, isNot(en), reason: failure.toString());
        }
      }
    });

    test('every role and every planned feature is named in both languages', () {
      for (final role in UserRole.values) {
        expect(english.roleName(role), isNotEmpty);
        expect(arabic.roleName(role), isNotEmpty);
        expect(arabic.roleName(role), isNot(english.roleName(role)));
      }
      for (final feature in PlannedFeature.values) {
        expect(english.featureName(feature), isNotEmpty);
        expect(arabic.featureName(feature), isNotEmpty);
      }
    });

    test('every field problem is translated', () {
      for (final reason in FieldReason.values) {
        final problem = KnownFieldProblem(reason);
        expect(english.fieldProblemMessage(problem), isNotEmpty);
        expect(arabic.fieldProblemMessage(problem), isNot(english.fieldProblemMessage(problem)));
      }
    });

    test('server text (English) is shown as sent in English and isolated in Arabic so it keeps its direction', () {
      const problem = ServerFieldProblem('Title is required.');
      expect(english.fieldProblemMessage(problem), 'Title is required.');
      expect(arabic.fieldProblemMessage(problem), '\u2066Title is required.\u2069');
    });

    test('the endpoint is named in the message so nobody mistakes "not built" for "broken"', () {
      const failure = EndpointMissingFailure(endpoint: 'POST /api/attempts');
      expect(english.failureMessage(failure), contains('POST /api/attempts'));
      expect(arabic.failureMessage(failure), contains('POST /api/attempts'));
    });

    test('the sign-in failure text is exactly the one the specification requires', () {
      expect(english.failureInvalidCredentials, 'Incorrect email or password.');
      expect(english.accountsCreatedByAdmin, 'Accounts are created by your administrator.');
    });
  });

  group('language choice', () {
    testWidgets('English starts left-to-right', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.ltr);
      expect(find.text('Sign in'), findsWidgets);
    });

    testWidgets('Arabic starts right-to-left with Arabic texts', (tester) async {
      await pumpExamora(tester, TestEnvironment(language: 'ar'));
      expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.rtl);
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('يُنشئ مدير النظام الحسابات.'), findsOneWidget);
    });

    testWidgets('switching language is immediate, without restarting, and flips the layout direction', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      expect(find.text('Email'), findsOneWidget);

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsNothing);
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.rtl);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
      expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.ltr);
    });

    testWidgets('only the language code is remembered, and nothing else is stored by the switch', (tester) async {
      final env = TestEnvironment();
      await pumpExamora(tester, env);
      env.keyValueStore.values.clear();

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(env.keyValueStore.values[languagePreferenceKey], 'ar');
      expect(env.keyValueStore.values.keys.where((k) => k.startsWith('preferences.')), [languagePreferenceKey]);
      expect(env.secureStore.values.keys.any((k) => k.contains('language')), isFalse);
    });

    testWidgets('switching keeps what was typed and the current screen', (tester) async {
      await pumpExamora(tester, TestEnvironment());
      await enterField(tester, 'Email', 'student@examora.app');

      await tester.tap(find.text('العربية'));
      await tester.pumpAndSettle();

      expect(find.text('student@examora.app'), findsOneWidget);
      expect(routerOf(tester).location, startsWith(RoutePaths.login));
    });

    testWidgets('the language switch is on the profile too, and sign-in works in Arabic', (tester) async {
      final env = TestEnvironment(language: 'ar');
      await pumpExamora(tester, env);
      await signInThroughScreen(
        tester,
        email: 'student@examora.app',
        password: 'Examora#2026',
        emailLabel: 'البريد الإلكتروني',
        passwordLabel: 'كلمة المرور',
        buttonLabel: 'تسجيل الدخول',
      );
      expect(find.textContaining('مرحباً'), findsOneWidget);

      await tester.tap(find.text('الملف الشخصي'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('the wrong-password message is translated, and still the same for unknown emails', (tester) async {
      await pumpExamora(tester, TestEnvironment(language: 'ar'));
      await signInThroughScreen(
        tester,
        email: 'student@examora.app',
        password: 'nope',
        emailLabel: 'البريد الإلكتروني',
        passwordLabel: 'كلمة المرور',
        buttonLabel: 'تسجيل الدخول',
      );
      expect(find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة.'), findsOneWidget);
    });

    test('with nothing chosen the app follows the device language (Arabic device -> Arabic, others -> English)', () {
      expect(
        TestEnvironment(language: null, deviceLanguage: 'ar').container().read(localeControllerProvider).languageCode,
        'ar',
      );
      expect(
        TestEnvironment(language: null, deviceLanguage: 'fr').container().read(localeControllerProvider).languageCode,
        'en',
      );
      expect(
        TestEnvironment(language: null, deviceLanguage: 'en').container().read(localeControllerProvider).languageCode,
        'en',
      );
    });

    test('a stored choice beats the device language', () {
      expect(
        TestEnvironment(language: 'en', deviceLanguage: 'ar').container().read(localeControllerProvider).languageCode,
        'en',
      );
      expect(
        TestEnvironment(language: 'ar', deviceLanguage: 'en').container().read(localeControllerProvider).languageCode,
        'ar',
      );
    });

    testWidgets('an unsupported language code is ignored', (tester) async {
      final container = TestEnvironment().container();
      await container.read(localeControllerProvider.notifier).setLanguage('fr');
      expect(container.read(localeControllerProvider).languageCode, 'en');
    });
  });

  group('text scaling', () {
    testWidgets('is capped at 1.6 so the layout cannot break at the largest accessibility sizes', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpExamora(tester, TestEnvironment());

      final scaler = MediaQuery.of(tester.element(find.byType(Scaffold).first)).textScaler;
      expect(scaler.scale(10), closeTo(16, 0.001));
    });

    testWidgets('a smaller scale is left alone', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpExamora(tester, TestEnvironment());

      final scaler = MediaQuery.of(tester.element(find.byType(Scaffold).first)).textScaler;
      expect(scaler.scale(10), closeTo(12, 0.001));
    });

    testWidgets('the sign-in screen does not overflow at the capped scale on a phone, in Arabic', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpExamora(tester, TestEnvironment(language: 'ar'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the profile screen does not overflow at the capped scale on a phone', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 3.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final env = TestEnvironment();
      await startSignedIn(env, 'student@examora.app');
      await pumpExamora(tester, env, initialLocation: RoutePaths.studentProfile);
      expect(tester.takeException(), isNull);
    });
  });
}
