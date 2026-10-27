import 'dart:async';

import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The key under which the chosen language code (and nothing else) is stored.
const String languagePreferenceKey = 'preferences.language';

/// The language chosen on a previous run (`ar` or `en`), read before the app starts. Null when none was chosen.
final initialLanguageCodeProvider = Provider<String?>((ref) => null);

/// The device's own language, used when nothing was chosen. Overridden at start-up.
final deviceLanguageCodeProvider = Provider<String>((ref) => 'en');

/// Holds the active [Locale] and remembers a change. Only the language code is stored, never anything personal.
final localeControllerProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// Chooses between Arabic and English.
class LocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    final stored = ref.watch(initialLanguageCodeProvider);
    final device = ref.watch(deviceLanguageCodeProvider);
    final code = (stored == 'ar' || stored == 'en') ? stored! : (device == 'ar' ? 'ar' : 'en');
    return Locale(code);
  }

  /// Switches the language immediately and stores the choice. A storage failure only means the choice is not
  /// remembered; the switch itself still happens.
  Future<void> setLanguage(String code) async {
    if (code != 'ar' && code != 'en') return;
    state = Locale(code);
    try {
      await ref.read(keyValueStoreProvider).write(languagePreferenceKey, code);
    } on Object {
      // Not remembered after a restart; nothing else to do.
    }
  }
}

/// Starts [LocaleController.setLanguage] without waiting, for callbacks that cannot await.
void switchLanguage(WidgetRef ref, String code) {
  unawaited(ref.read(localeControllerProvider.notifier).setLanguage(code));
}
