import 'package:examora_app/app/app.dart';
import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/router/app_router.dart';
import 'package:examora_app/core/l10n/locale_controller.dart';
import 'package:examora_app/core/security/password_hasher.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/features/authentication/data/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_clock.dart';

/// Everything a test replaces: storage, the clock and the cost of hashing. Nothing else - the router, the guard, the
/// controllers and every screen are the real ones.
final class TestEnvironment {
  /// Creates an environment with empty storage and the language set to [language].
  TestEnvironment({DateTime? now, this.language = 'en', this.deviceLanguage})
    : clock = FakeClock(now),
      keyValueStore = InMemoryKeyValueStore(),
      secureStore = InMemorySecureStore();

  /// The fake clock.
  final FakeClock clock;

  /// Local data.
  final InMemoryKeyValueStore keyValueStore;

  /// Session material.
  final InMemorySecureStore secureStore;

  /// The language chosen on a "previous run" (`en` or `ar`), or null when nothing was chosen.
  final String? language;

  /// The device's own language, when a test needs to set it.
  final String? deviceLanguage;

  /// A cheap hasher: a few iterations and no isolate, so tests do not wait for real password hashing.
  static const PasswordHasher fastHasher = PasswordHasher(iterations: 2, useIsolate: false);

  /// The provider overrides that build this environment.
  List<Override> overrides({String? initialLocation, List<Override> extra = const []}) => [
    keyValueStoreProvider.overrideWithValue(keyValueStore),
    secureStoreProvider.overrideWithValue(secureStore),
    clockProvider.overrideWithValue(clock),
    passwordHasherProvider.overrideWithValue(fastHasher),
    if (language != null) initialLanguageCodeProvider.overrideWithValue(language),
    if (deviceLanguage != null) deviceLanguageCodeProvider.overrideWithValue(deviceLanguage!),
    if (initialLocation != null) initialLocationProvider.overrideWithValue(initialLocation),
    ...extra,
  ];

  /// A container over this environment, for tests without widgets.
  ProviderContainer container({List<Override> extra = const []}) {
    final container = ProviderContainer(overrides: overrides(extra: extra));
    addTearDown(container.dispose);
    return container;
  }
}

/// A phone-sized window (420 x 900 logical pixels), the size the specification designs for.
void usePhoneWindow(WidgetTester tester, {double width = 420, double height = 900}) {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
}

/// Builds the REAL app (real router, guard, controllers and screens) over [env] and settles.
Future<void> pumpExamora(
  WidgetTester tester,
  TestEnvironment env, {
  String? initialLocation,
  List<Override> extra = const [],
  bool settle = true,
}) async {
  usePhoneWindow(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: env.overrides(initialLocation: initialLocation, extra: extra),
      child: const ExamoraApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Types into the field with the given label.
Future<void> enterField(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
}

/// Signs in through the real sign-in screen.
Future<void> signInThroughScreen(
  WidgetTester tester, {
  required String email,
  required String password,
  String emailLabel = 'Email',
  String passwordLabel = 'Password',
  String buttonLabel = 'Sign in',
}) async {
  await enterField(tester, emailLabel, email);
  await enterField(tester, passwordLabel, password);
  await tester.tap(find.widgetWithText(FilledButton, buttonLabel));
  await tester.pumpAndSettle();
}

/// The router the running app uses, read from the app's own container.
GoRouterReader routerOf(WidgetTester tester) => GoRouterReader(tester);

/// Reads the current location of the real router.
final class GoRouterReader {
  /// Creates the reader.
  GoRouterReader(this._tester);

  final WidgetTester _tester;

  /// The router's current location.
  String get location {
    final container = ProviderScope.containerOf(_tester.element(find.byType(ExamoraApp)));
    final router = container.read(routerProvider);
    // A screen opened with push is not part of the reported URI, so ask for the top match itself.
    final configuration = router.routerDelegate.currentConfiguration;
    final top = configuration.matches.last;
    return top is ImperativeRouteMatch ? top.matchedLocation : configuration.uri.toString();
  }
}

/// The container of the running app, for reading state in assertions.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ExamoraApp)));

/// The seeded accounts' repository access, for tests that need to prepare storage.
Future<void> seedLocalAccounts(ProviderContainer container) => container.read(localAccountStoreProvider).ensureSeeded();

/// Taps [finder] after scrolling it into view (phone screens are shorter than some of the app's screens).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
