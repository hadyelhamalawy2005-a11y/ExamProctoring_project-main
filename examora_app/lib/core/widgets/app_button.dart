import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// How prominent a button is.
enum AppButtonVariant {
  /// The main action on a screen.
  primary,

  /// A secondary action.
  secondary,

  /// A destructive action.
  danger,
}

/// A full-width-capable button with a busy state: while [busy] it is disabled and shows a spinner, so a double tap can
/// never send the same request twice.
class AppButton extends StatelessWidget {
  /// Creates a button.
  const AppButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.expand = true,
    super.key,
  });

  /// The text.
  final String label;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// True while the action runs.
  final bool busy;

  /// How prominent it is.
  final AppButtonVariant variant;

  /// An optional leading icon.
  final IconData? icon;

  /// Whether it stretches to the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          const SizedBox(
            width: AppIconSizes.sm,
            height: AppIconSizes.sm,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: AppIconSizes.sm),
        if (busy || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(label, textAlign: TextAlign.center, style: AppTypography.button),
        ),
      ],
    );
    final size = Size(expand ? double.infinity : AppDimensions.minTouchTarget, AppDimensions.buttonHeight);

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: size,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          minimumSize: size,
        ),
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger,
          foregroundColor: AppColors.onPrimary,
          minimumSize: size,
        ),
        child: child,
      ),
    };

    return Semantics(button: true, enabled: enabled, label: label, excludeSemantics: true, child: button);
  }
}
