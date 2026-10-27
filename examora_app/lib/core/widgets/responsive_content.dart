import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:flutter/material.dart';

/// Centres content in a column no wider than [AppDimensions.maxContentWidth], so a phone layout stays readable on a
/// tablet or a desktop window.
class ResponsiveContent extends StatelessWidget {
  /// Creates the container.
  const ResponsiveContent({required this.child, this.padding = const EdgeInsets.all(AppSpacing.lg), super.key});

  /// The content.
  final Widget child;

  /// Space around the content.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppDimensions.maxContentWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
