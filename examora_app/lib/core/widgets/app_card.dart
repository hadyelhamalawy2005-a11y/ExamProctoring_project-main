import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// A bordered surface that groups related content.
class AppCard extends StatelessWidget {
  /// Creates a card.
  const AppCard({required this.child, this.padding = const EdgeInsets.all(AppSpacing.lg), this.onTap, super.key});

  /// The content.
  final Widget child;

  /// Space around the content.
  final EdgeInsetsGeometry padding;

  /// Makes the whole card tappable when set.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
