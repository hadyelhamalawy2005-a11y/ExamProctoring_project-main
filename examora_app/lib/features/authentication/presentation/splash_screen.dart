import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:flutter/material.dart';

/// Shown while the stored session is read, so a signed-in user is never flashed the sign-in screen on launch.
class SplashScreen extends StatelessWidget {
  /// Creates the screen.
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: AppLoadingView(message: context.strings.restoringSession));
  }
}
