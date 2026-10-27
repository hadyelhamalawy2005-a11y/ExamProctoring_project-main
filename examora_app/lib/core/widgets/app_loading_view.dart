import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// A centred spinner with a caption, for a list or screen that is loading.
class AppLoadingView extends StatelessWidget {
  /// Creates the view. [message] defaults to the generic loading text.
  const AppLoadingView({this.message, super.key});

  /// What is loading.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message ?? context.strings.loading;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: text,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            ExcludeSemantics(child: Text(text, style: AppTypography.body)),
          ],
        ),
      ),
    );
  }
}
