import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// "How do you want to create the exam?" Exactly two ways: by hand, or from a Word file. There is deliberately no third
/// option: nothing generates exams from other material, so nothing offers it.
///
/// Both go to the wizard first, so the exam has a title before anything is saved or imported.
class ExamMethodScreen extends StatelessWidget {
  /// Creates the screen.
  const ExamMethodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.createExamButton),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(header: true, child: Text(strings.examMethodTitle, style: AppTypography.title)),
                const SizedBox(height: AppSpacing.sm),
                Text(strings.examMethodDetailsFirst, style: AppTypography.body),
                const SizedBox(height: AppSpacing.lg),
                _MethodCard(
                  key: const Key('method-manual'),
                  icon: Icons.edit_note_outlined,
                  title: strings.examMethodManual,
                  body: strings.examMethodManualBody,
                  onTap: () => context.push(RoutePaths.instructorNewExam(RoutePaths.methodManual)),
                ),
                const SizedBox(height: AppSpacing.md),
                _MethodCard(
                  key: const Key('method-word'),
                  icon: Icons.description_outlined,
                  title: strings.examMethodWord,
                  body: strings.examMethodWordBody,
                  onTap: () => context.push(RoutePaths.instructorNewExam(RoutePaths.methodWord)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.icon, required this.title, required this.body, required this.onTap, super.key});

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: AppCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppIconSizes.md, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.heading),
                  const SizedBox(height: AppSpacing.xs),
                  Text(body, style: AppTypography.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
