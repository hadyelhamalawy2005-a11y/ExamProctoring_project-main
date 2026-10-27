import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_section_header.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/language_switcher.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The profile every role has: identity, where data lives, a privacy summary, the language, change password and sign out.
class ProfileScreen extends ConsumerWidget {
  /// Creates the screen. [showBackButton] is true when the screen is pushed rather than a tab.
  const ProfileScreen({this.showBackButton = false, super.key});

  /// Whether the app bar shows a back/home button (the administrator has no bottom navigation).
  final bool showBackButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: showBackButton ? const BackOrHomeButton() : null,
        title: Text(strings.profileTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionHeader(strings.identitySection),
                AppCard(
                  child: auth is AuthSignedIn
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Line(label: strings.fullNameLabel, value: strings.isolate(auth.account.fullName)),
                            const SizedBox(height: AppSpacing.md),
                            _Line(label: strings.emailLabel, value: auth.account.email, ltr: true),
                            const SizedBox(height: AppSpacing.md),
                            _Line(label: strings.roleLabel, value: strings.roleName(auth.account.role)),
                          ],
                        )
                      : Text(strings.loading),
                ),
                AppSectionHeader(strings.dataLocationSection),
                AppCard(child: Text(strings.dataLocationBody, style: AppTypography.body)),
                AppSectionHeader(strings.privacySection),
                AppCard(child: Text(strings.privacyBody, style: AppTypography.body)),
                AppSectionHeader(strings.languageSection),
                const Align(alignment: AlignmentDirectional.centerStart, child: LanguageSwitcher()),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: strings.changePasswordTitle,
                  variant: AppButtonVariant.secondary,
                  icon: Icons.lock_outline,
                  onPressed: () => unawaited(context.push<void>(RoutePaths.changePassword)),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: strings.signOut,
                  variant: AppButtonVariant.danger,
                  icon: Icons.logout,
                  onPressed: () => unawaited(ref.read(authControllerProvider.notifier).signOut()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        Text(value, style: AppTypography.body, textDirection: ltr ? TextDirection.ltr : null),
      ],
    );
  }
}
