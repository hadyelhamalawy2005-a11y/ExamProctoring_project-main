import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/l10n/planned_feature.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:flutter/material.dart';

/// Tells the user, in plain words, that a feature has not been built yet.
///
/// A feature that cannot work must fail visibly, never quietly show something plausible.
class FeatureNotBuiltBody extends StatelessWidget {
  /// Creates the body.
  const FeatureNotBuiltBody({required this.feature, super.key});

  /// What is missing.
  final PlannedFeature feature;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return ResponsiveContent(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_outlined, size: AppIconSizes.lg, color: AppColors.warning),
            const SizedBox(height: AppSpacing.md),
            Text(strings.notBuiltTitle, style: AppTypography.heading),
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.notBuiltBody(strings.featureName(feature)),
              style: AppTypography.body,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A full screen with a way back that says a feature has not been built yet.
class FeatureNotBuiltScreen extends StatelessWidget {
  /// Creates the screen.
  const FeatureNotBuiltScreen({required this.feature, super.key});

  /// What is missing.
  final PlannedFeature feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackOrHomeButton(), title: Text(context.strings.featureName(feature))),
      body: FeatureNotBuiltBody(feature: feature),
    );
  }
}
