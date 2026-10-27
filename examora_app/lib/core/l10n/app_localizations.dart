import 'package:examora_app/core/l10n/app_strings.dart';
import 'package:examora_app/core/l10n/strings_ar.dart';
import 'package:examora_app/core/l10n/strings_en.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The languages the app speaks, Arabic first because it is right-to-left.
const List<Locale> supportedAppLocales = [Locale('ar'), Locale('en')];

/// Loads [AppStrings] for the active [Locale].
final class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  /// Creates the delegate.
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ar' || locale.languageCode == 'en';

  @override
  Future<AppStrings> load(Locale locale) =>
      SynchronousFuture<AppStrings>(locale.languageCode == 'ar' ? const ArabicStrings() : const EnglishStrings());

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}

/// `context.strings` - the texts for the current language.
extension AppStringsContext on BuildContext {
  /// The texts for the current language.
  AppStrings get strings => Localizations.of<AppStrings>(this, AppStrings)!;
}
