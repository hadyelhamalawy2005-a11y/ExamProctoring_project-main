import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:examora_app/core/widgets/app_section_header.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/word_import/domain/import_review.dart';
import 'package:examora_app/features/word_import/presentation/import_question_card.dart';
import 'package:examora_app/features/word_import/presentation/import_session.dart';
import 'package:examora_app/features/word_import/presentation/template_help_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Imports questions from a Word file into an exam that already exists (and already has a title).
///
/// Nothing is added until the whole review is confirmed: every question can be edited or left out, each shows a status
/// word, and the exam only receives the questions that pass the same validation as manual authoring.
class WordImportScreen extends ConsumerStatefulWidget {
  /// Creates the screen for the exam [examId].
  const WordImportScreen({required this.examId, super.key});

  /// The exam the questions are added to.
  final String examId;

  @override
  ConsumerState<WordImportScreen> createState() => _WordImportScreenState();
}

class _WordImportScreenState extends ConsumerState<WordImportScreen> {
  bool _busy = false;
  AppFailure? _failure;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final count = ImportReview.build(ref.read(importSessionProvider).drafts).length;
    final result = await ref.read(importSessionProvider.notifier).confirm(widget.examId);
    if (!mounted) return;
    switch (result) {
      case Ok<Exam>():
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(content: Text(context.strings.importAdded(count))));
        setState(() => _busy = false);
        if (context.canPop()) {
          context.pop();
        } else {
          // Opened by a link, so there is nothing to go back to: continue in the wizard for this exam.
          context.go(RoutePaths.instructorExamEdit(widget.examId));
        }
      case Err<Exam>(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final session = ref.watch(importSessionProvider);
    final controller = ref.read(importSessionProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.importTitle),
        actions: [
          IconButton(
            tooltip: strings.importTemplateHelp,
            icon: const Icon(Icons.help_outline),
            onPressed: () => unawaited(showTemplateHelp(context)),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (session.phase) {
          ImportPhase.reading => AppLoadingView(message: strings.importReading(session.fileName)),
          ImportPhase.idle ||
          ImportPhase.failed => _Start(failure: session.failure, onChoose: () => unawaited(controller.chooseFile())),
          ImportPhase.reviewing => _Review(
            session: session,
            busy: _busy,
            failure: _failure,
            onChooseAnother: () => unawaited(controller.chooseFile()),
            onConfirm: () => unawaited(_confirm()),
          ),
        },
      ),
    );
  }
}

class _Start extends StatelessWidget {
  const _Start({required this.failure, required this.onChoose});

  final AppFailure? failure;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final problem = failure;
    return SingleChildScrollView(
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.importIntro, style: AppTypography.body),
            const SizedBox(height: AppSpacing.lg),
            if (problem != null) ...[
              AppBanner(message: strings.failureMessage(problem), tone: StatusTone.danger),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppButton(label: strings.importChooseFile, icon: Icons.upload_file_outlined, onPressed: onChoose),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: () => unawaited(showTemplateHelp(context)),
              icon: const Icon(Icons.help_outline),
              label: Text(strings.importTemplateHelp),
            ),
          ],
        ),
      ),
    );
  }
}

class _Review extends ConsumerWidget {
  const _Review({
    required this.session,
    required this.busy,
    required this.failure,
    required this.onChooseAnother,
    required this.onConfirm,
  });

  final ImportSessionState session;
  final bool busy;
  final AppFailure? failure;
  final VoidCallback onChooseAnother;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final controller = ref.read(importSessionProvider.notifier);
    final drafts = session.drafts;
    final summary = ImportReview.summarize(drafts);
    final block = ImportReview.blockOf(drafts);
    final shown = session.onlyAttention
        ? [
            for (final draft in drafts)
              if (ImportReview.statusOf(draft) == ImportStatus.needsAttention) draft,
          ]
        : drafts;
    final problem = failure;

    return SingleChildScrollView(
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.importFileLabel(session.fileName), style: AppTypography.caption),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              liveRegion: true,
              child: Text(
                strings.importSummary(summary.found, summary.ready, summary.attention, summary.notImported),
                key: const Key('import-summary'),
                style: AppTypography.heading,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (drafts.isEmpty)
              AppBanner(message: strings.importNoQuestionsFound, tone: StatusTone.warning)
            else
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(strings.importOnlyAttention),
                value: session.onlyAttention,
                onChanged: (value) => controller.setOnlyAttention(value: value),
              ),
            if (problem != null) ...[
              AppBanner(message: strings.failureMessage(problem), tone: StatusTone.danger),
              const SizedBox(height: AppSpacing.md),
            ],
            if (drafts.isNotEmpty && shown.isEmpty) Text(strings.importNothingToShow, style: AppTypography.body),
            for (final draft in shown) ...[
              ImportQuestionCard(key: ValueKey(draft.id), draft: draft, onChanged: controller.update),
              const SizedBox(height: AppSpacing.md),
            ],
            if (session.unattached.isNotEmpty) ...[
              AppSectionHeader(strings.importUnattachedTitle),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.importUnattachedBody, style: AppTypography.caption),
                    const SizedBox(height: AppSpacing.sm),
                    for (final line in session.unattached)
                      Text(strings.importLine(line.number, line.text), style: AppTypography.body),
                  ],
                ),
              ),
            ],
            if (session.skipped.isNotEmpty) ...[
              AppSectionHeader(strings.importSkippedTitle),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in session.skipped) ...[
                      Text(
                        strings.importSkippedItem(strings.importSkippedKindName(item.kind), item.afterLine),
                        style: AppTypography.body,
                      ),
                      if (item.preview.isNotEmpty) Text(strings.isolate(item.preview), style: AppTypography.caption),
                    ],
                  ],
                ),
              ),
            ],
            if (session.ignored.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(strings.importIgnoredNote(session.ignored.length), style: AppTypography.caption),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (block == ImportBlock.nothingKept) Text(strings.importContinueNone, style: AppTypography.caption),
            if (block == ImportBlock.invalidQuestions)
              Text(strings.importContinueBlocked, style: AppTypography.caption),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: strings.importContinue(ImportReview.build(drafts).length),
              busy: busy,
              onPressed: block == null ? onConfirm : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: strings.importChooseAnother,
              variant: AppButtonVariant.secondary,
              onPressed: onChooseAnother,
            ),
          ],
        ),
      ),
    );
  }
}
