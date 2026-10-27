import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// Ready-made dialogs.
abstract final class AppDialogs {
  /// Asks the user to confirm an action. Resolves to true only when they confirm.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.strings.cancel),
          ),
          AppButton(
            label: confirmLabel,
            expand: false,
            variant: destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
