import 'dart:ui' as ui;

import 'package:examora_app/app/app.dart';
import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/core/l10n/locale_controller.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Starts Examora on the device's own storage. No server is needed or assumed.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final store = SharedPreferencesKeyValueStore(preferences);
  final chosen = await store.read(languagePreferenceKey);

  runApp(
    ProviderScope(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        initialLanguageCodeProvider.overrideWithValue(chosen),
        deviceLanguageCodeProvider.overrideWithValue(ui.PlatformDispatcher.instance.locale.languageCode),
      ],
      child: const ExamoraApp(),
    ),
  );
}
