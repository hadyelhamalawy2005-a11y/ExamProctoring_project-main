import 'package:examora_app/app/router/app_router.dart';
import 'package:examora_app/app/theme/app_theme.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/l10n/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The root widget: theme, language, router and the text-scale cap.
class ExamoraApp extends ConsumerWidget {
  /// Creates the app.
  const ExamoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeControllerProvider);
    return MaterialApp.router(
      title: 'Examora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppStringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: AppDimensions.maxTextScale,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
