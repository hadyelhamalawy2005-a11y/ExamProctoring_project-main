import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// A heading that opens a group of content. Marked as a header for screen readers.
class AppSectionHeader extends StatelessWidget {
  /// Creates the header.
  const AppSectionHeader(this.title, {this.trailing, super.key});

  /// The heading text.
  final String title;

  /// Something at the end of the line, such as a button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: AppTypography.heading)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
