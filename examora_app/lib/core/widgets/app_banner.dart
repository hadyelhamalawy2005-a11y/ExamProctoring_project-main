import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:flutter/material.dart';

/// A message strip: an icon and text on a tinted background. Read out as soon as it appears.
class AppBanner extends StatelessWidget {
  /// Creates the banner.
  const AppBanner({required this.message, required this.tone, super.key});

  /// What to say.
  final String message;

  /// The colour family (the icon carries the meaning too, not colour alone).
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (foreground, background, icon) = switch (tone) {
      StatusTone.success => (AppColors.success, AppColors.successSurface, Icons.check_circle_outline),
      StatusTone.warning => (AppColors.warning, AppColors.warningSurface, Icons.warning_amber_outlined),
      StatusTone.danger => (AppColors.danger, AppColors.dangerSurface, Icons.error_outline),
      StatusTone.info => (AppColors.info, AppColors.infoSurface, Icons.info_outline),
    };
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: foreground),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground, size: AppIconSizes.md),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(message, style: AppTypography.body.copyWith(color: foreground)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
