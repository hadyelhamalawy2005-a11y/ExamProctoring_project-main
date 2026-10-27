import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/language_switcher.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Explains that there is no automatic password reset and to ask an administrator.
class ForgotPasswordScreen extends StatelessWidget {
  /// Creates the screen.
  const ForgotPasswordScreen({super.key});

  void _backToSignIn(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: strings.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _backToSignIn(context),
        ),
        title: Text(strings.forgotPasswordTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: AlignmentDirectional.centerEnd, child: LanguageSwitcher()),
                const SizedBox(height: AppSpacing.xl),
                const Icon(Icons.lock_reset_outlined, size: AppIconSizes.lg, color: AppColors.navy),
                const SizedBox(height: AppSpacing.lg),
                Text(strings.forgotPasswordBody, style: AppTypography.body),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: strings.backToSignIn, onPressed: () => _backToSignIn(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
