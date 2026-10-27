import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// "This did not load", with a retry button.
///
/// When the failure says a server endpoint does not exist yet, it says exactly that and names the endpoint: "this has not
/// been built yet" is a different conversation from "it broke".
class AppErrorView extends StatelessWidget {
  /// Creates the view.
  const AppErrorView({required this.failure, this.onRetry, super.key});

  /// What went wrong.
  final AppFailure failure;

  /// Called by the retry button; null hides the button (a missing endpoint cannot be retried into existence).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final failure = this.failure;
    final isMissing = failure is EndpointMissingFailure;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMissing ? Icons.construction_outlined : Icons.error_outline,
              size: AppIconSizes.lg,
              color: isMissing ? AppColors.warning : AppColors.danger,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(isMissing ? strings.notBuiltTitle : strings.errorTitle, style: AppTypography.heading),
            const SizedBox(height: AppSpacing.sm),
            Text(strings.failureMessage(failure), style: AppTypography.body, textAlign: TextAlign.center),
            if (failure is EndpointMissingFailure) ...[
              const SizedBox(height: AppSpacing.md),
              Text(strings.missingEndpointLabel, style: AppTypography.caption),
              SelectableText(
                failure.endpoint,
                textDirection: TextDirection.ltr,
                style: AppTypography.body.copyWith(fontFamily: 'monospace'),
              ),
            ],
            if (onRetry != null && !isMissing) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(label: strings.retry, onPressed: onRetry, expand: false, variant: AppButtonVariant.secondary),
            ],
          ],
        ),
      ),
    );
  }
}
