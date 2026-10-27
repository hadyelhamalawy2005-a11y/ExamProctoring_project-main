import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// "There is nothing here" - for a list that loaded successfully and is empty.
///
/// Never use it where a failure belongs: "you have no exams" and "the exams did not load" are different statements
/// (use `AppErrorView` for the second).
class AppEmptyView extends StatelessWidget {
  /// Creates the view.
  const AppEmptyView({required this.title, this.message, this.icon = Icons.inbox_outlined, this.action, super.key});

  /// What is empty.
  final String title;

  /// More explanation.
  final String? message;

  /// The picture.
  final IconData icon;

  /// An optional call to action.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSizes.lg, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTypography.heading, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(message!, style: AppTypography.body, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}
