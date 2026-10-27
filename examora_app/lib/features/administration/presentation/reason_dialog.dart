import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:flutter/material.dart';

/// Asks for the reason behind deactivating or reactivating an account. Resolves to the trimmed reason (empty when it was
/// optional and left blank), or null when cancelled.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required bool reasonRequired,
  bool destructive = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _ReasonDialog(
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    reasonRequired: reasonRequired,
    destructive: destructive,
  ),
);

/// A StatefulWidget so the dialog owns, and disposes, its text controller.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.reasonRequired,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool reasonRequired;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    final problem = Validators.statusReason(_reason.text, required: widget.reasonRequired);
    if (problem != null) {
      setState(() => _error = context.strings.fieldProblemMessage(problem));
      return;
    }
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message, style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _reason,
              autofocus: true,
              maxLines: 3,
              minLines: 2,
              maxLength: Validators.statusReasonMaxLength,
              decoration: InputDecoration(
                labelText: widget.reasonRequired ? strings.reasonRequiredLabel : strings.reasonOptionalLabel,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(strings.cancel)),
        AppButton(
          label: widget.confirmLabel,
          expand: false,
          variant: widget.destructive ? AppButtonVariant.danger : AppButtonVariant.primary,
          onPressed: _confirm,
        ),
      ],
    );
  }
}
