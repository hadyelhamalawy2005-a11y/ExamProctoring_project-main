import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A labelled text field with an inline error, optional password reveal and consistent spacing.
class AppTextField extends StatefulWidget {
  /// Creates a field.
  const AppTextField({
    required this.controller,
    required this.label,
    this.errorText,
    this.helperText,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.maxLines = 1,
    this.maxLength,
    this.ltr = false,
    this.focusNode,
    super.key,
  });

  /// Holds the text. Owned by the caller, who must dispose it.
  final TextEditingController controller;

  /// The label above the text.
  final String label;

  /// An error to show under the field; null shows none.
  final String? errorText;

  /// Help shown under the field when there is no error.
  final String? helperText;

  /// Hides the text and adds a reveal button.
  final bool obscure;

  /// The keyboard to show.
  final TextInputType? keyboardType;

  /// The keyboard's action button.
  final TextInputAction? textInputAction;

  /// Hints for the platform's autofill.
  final Iterable<String>? autofillHints;

  /// Called when the keyboard's action button is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Whether the field accepts input.
  final bool enabled;

  /// Lines of text (1 for a single-line field).
  final int maxLines;

  /// The most characters accepted.
  final int? maxLength;

  /// Forces left-to-right text, for emails and passwords inside right-to-left layouts.
  final bool ltr;

  /// Focus control, when the caller needs it.
  final FocusNode? focusNode;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final hidden = widget.obscure && !_revealed;
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      maxLines: hidden ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      textDirection: widget.ltr ? TextDirection.ltr : null,
      textAlign: widget.ltr ? TextAlign.left : TextAlign.start,
      inputFormatters: widget.maxLength == null ? null : [LengthLimitingTextInputFormatter(widget.maxLength)],
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        errorMaxLines: 3,
        helperText: widget.errorText == null ? widget.helperText : null,
        helperMaxLines: 3,
        counterText: '',
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _revealed ? strings.hidePassword : strings.showPassword,
                icon: Icon(_revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _revealed = !_revealed),
              )
            : null,
      ),
    );
  }
}
