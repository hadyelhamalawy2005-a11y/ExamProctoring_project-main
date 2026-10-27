import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// The tone of a [StatusBadge].
enum StatusTone {
  /// Good news.
  success,

  /// Needs attention.
  warning,

  /// A problem.
  danger,

  /// Neutral information.
  info,
}

/// A status shown as a WORD with a colour behind it. Status is never carried by colour alone.
class StatusBadge extends StatelessWidget {
  /// Creates the badge.
  const StatusBadge({required this.label, required this.tone, super.key});

  /// The status in words.
  final String label;

  /// The colour family.
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (tone) {
      StatusTone.success => (AppColors.success, AppColors.successSurface),
      StatusTone.warning => (AppColors.warning, AppColors.warningSurface),
      StatusTone.danger => (AppColors.danger, AppColors.dangerSurface),
      StatusTone.info => (AppColors.info, AppColors.infoSurface),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: foreground),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(color: foreground, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
