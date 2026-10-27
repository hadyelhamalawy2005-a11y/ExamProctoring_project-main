import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Refuses a change that adds a large block of text at once. Typing, even with word suggestions, adds a few characters at a
/// time; a paste, a drag-and-drop or a clipboard keyboard adds a lot in one go. The change is dropped and [onBlocked] is told
/// how many characters were attempted.
class BulkInsertionGuard extends TextInputFormatter {
  /// Creates the guard.
  BulkInsertionGuard({required this.onBlocked, this.maxInsertion = defaultMaxInsertion});

  /// The most characters one change may add. Predictive keyboards complete a word (rarely more than ~20 letters); anything
  /// beyond this is treated as a paste.
  static const int defaultMaxInsertion = 25;

  /// The limit in force.
  final int maxInsertion;

  /// Called when a change was refused, with the number of characters it would have added.
  final void Function(int characters) onBlocked;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final added = newValue.text.length - oldValue.text.length;
    if (added > maxInsertion) {
      onBlocked(added);
      return oldValue;
    }
    return newValue;
  }
}

/// A text box for an exam answer in which copying, cutting and pasting are blocked: the selection menu is removed, the
/// keyboard shortcuts do nothing, and a large insertion is refused. Every attempt calls [onBlocked].
///
/// This guards only this app's own box. It cannot stop a second device, notes on paper or someone beside the student; the
/// consent screen and the briefing say so.
class GuardedAnswerField extends StatefulWidget {
  /// Creates the field.
  const GuardedAnswerField({
    required this.controller,
    required this.onChanged,
    required this.onBlocked,
    this.enabled = true,
    super.key,
  });

  /// Holds the text (owned by the caller).
  final TextEditingController controller;

  /// Called with every accepted edit.
  final ValueChanged<String> onChanged;

  /// Called when a copy, cut, paste or large insertion was refused; the argument says which.
  final void Function(String what) onBlocked;

  /// Whether the field accepts input.
  final bool enabled;

  @override
  State<GuardedAnswerField> createState() => _GuardedAnswerFieldState();
}

class _GuardedAnswerFieldState extends State<GuardedAnswerField> {
  late final BulkInsertionGuard _guard = BulkInsertionGuard(onBlocked: (n) => widget.onBlocked('bulk:$n'));

  void _block(String what) => widget.onBlocked(what);

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final blocked = <ShortcutActivator, VoidCallback>{
      for (final key in [LogicalKeyboardKey.keyV, LogicalKeyboardKey.keyC, LogicalKeyboardKey.keyX]) ...{
        SingleActivator(key, control: true): () => _block('shortcut'),
        SingleActivator(key, meta: true): () => _block('shortcut'),
      },
      const SingleActivator(LogicalKeyboardKey.insert, shift: true): () => _block('shortcut'),
      const SingleActivator(LogicalKeyboardKey.insert, control: true): () => _block('shortcut'),
      const SingleActivator(LogicalKeyboardKey.delete, shift: true): () => _block('shortcut'),
    };
    return CallbackShortcuts(
      bindings: blocked,
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        minLines: 5,
        maxLines: 12,
        onChanged: widget.onChanged,
        inputFormatters: [_guard],
        // No cut / copy / paste menu: an empty builder removes the toolbar entirely.
        contextMenuBuilder: (context, editableTextState) => const SizedBox.shrink(),
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: strings.answerLabel,
          alignLabelWithHint: true,
          helperText: strings.typedAnswerHint,
        ),
      ),
    );
  }
}
