import 'dart:async';

import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_dialogs.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_validation.dart';
import 'package:examora_app/features/exams/presentation/exam_status_badge.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Step 5: a summary, everything that stands in the way of publishing (all of it, not just the first problem), and the
/// publish, return-to-draft, archive and delete actions.
class ReviewStep extends ConsumerStatefulWidget {
  /// Creates the step.
  const ReviewStep({required this.exam, required this.onChanged, required this.onGoToStep, super.key});

  /// The exam being reviewed.
  final Exam exam;

  /// Called after the exam changed (published, archived, ...), so the screen reloads it.
  final VoidCallback onChanged;

  /// Jumps to another step, used by the "fix" shortcuts.
  final ValueChanged<int> onGoToStep;

  @override
  ConsumerState<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<ReviewStep> {
  bool _busy = false;
  AppFailure? _failure;
  List<PublishProblem>? _refused;

  Future<void> _run(Future<Result<Object?>> Function() action, {String? successNotice, bool leave = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
      _refused = null;
    });
    final result = await action();
    if (!mounted) return;
    switch (result) {
      case Ok<Object?>():
        setState(() => _busy = false);
        widget.onChanged();
        if (successNotice != null) {
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(SnackBar(content: Text(successNotice)));
        }
        if (leave && context.canPop()) context.pop();
      case Err<Object?>(:final failure):
        setState(() {
          _busy = false;
          if (failure is ExamNotPublishableFailure) {
            _refused = failure.problems;
          } else {
            _failure = failure;
          }
        });
        widget.onChanged();
    }
  }

  Future<void> _publish() async {
    final strings = context.strings;
    final confirmed = await AppDialogs.confirm(
      context,
      title: strings.publishConfirmTitle,
      message: strings.publishConfirmBody,
      confirmLabel: strings.publishExam,
    );
    if (!confirmed || !mounted) return;
    await _run(() => ref.read(examRepositoryProvider).publish(widget.exam.id), successNotice: strings.publishedNotice);
  }

  Future<void> _archive() async {
    final strings = context.strings;
    final confirmed = await AppDialogs.confirm(
      context,
      title: strings.archiveConfirmTitle,
      message: strings.archiveConfirmBody,
      confirmLabel: strings.archiveExam,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => ref.read(examRepositoryProvider).archive(widget.exam.id));
  }

  Future<void> _deleteDraft() async {
    final strings = context.strings;
    final confirmed = await AppDialogs.confirm(
      context,
      title: strings.deleteDraftTitle,
      message: strings.deleteDraftBody,
      confirmLabel: strings.deleteDraft,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => ref.read(examRepositoryProvider).deleteDraft(widget.exam.id), leave: true);
  }

  int _stepFor(PublishProblem problem) => switch (problem) {
    DetailsIncompleteProblem() => 0,
    NoQuestionsProblem() || QuestionPublishProblem() => 1,
    ScheduleMissingProblem() || WindowTooShortProblem() || StartTimePassedProblem() => 3,
  };

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final exam = widget.exam;
    final now = ref.watch(clockProvider).now();
    final status = exam.statusAt(now);
    final problems = _refused ?? ExamValidation.publishing(exam, now);
    final failure = _failure;
    final isDraft = exam.lifecycle == ExamLifecycle.draft;
    final canReturnToDraft = status == ExamStatus.scheduled;
    final passMark = exam.passMarkPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.isolate(exam.title), style: AppTypography.title),
              const SizedBox(height: AppSpacing.xs),
              Text(strings.isolate(exam.courseName), style: AppTypography.body),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ExamStatusBadge(status: status),
                  Text(strings.examVersionLabel(exam.version)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text('${strings.examDurationLabel}: ${exam.durationMinutes}', style: AppTypography.body),
              if (passMark != null)
                Text('${strings.examPassMarkLabel}: ${formatNumber(passMark)}', style: AppTypography.body),
              Text(
                strings.questionsSummary(exam.questions.length, formatNumber(exam.totalMarks)),
                style: AppTypography.body,
              ),
              if (exam.opensAt != null)
                Text(
                  '${strings.scheduleOpensLabel}: ${DateFormatting.dateTime(context, exam.opensAt!)}',
                  style: AppTypography.body,
                ),
              if (exam.closesAt != null)
                Text(
                  '${strings.scheduleClosesLabel}: ${DateFormatting.dateTime(context, exam.closesAt!)}',
                  style: AppTypography.body,
                ),
              if (exam.opensAt != null || exam.closesAt != null)
                Text(
                  strings.timeZoneNote(DateFormatting.zone(exam.opensAt ?? exam.closesAt!)),
                  style: AppTypography.caption,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isDraft) ...[
          if (problems.isEmpty)
            AppBanner(message: strings.reviewReady, tone: StatusTone.success)
          else ...[
            AppBanner(message: strings.reviewBlocked(problems.length), tone: StatusTone.warning),
            const SizedBox(height: AppSpacing.sm),
            for (final problem in problems)
              ListTile(
                key: ValueKey(problem),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.error_outline, color: AppColors.warning),
                title: Text(strings.publishProblemMessage(problem)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onGoToStep(_stepFor(problem)),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: strings.publishExam,
            icon: Icons.publish_outlined,
            busy: _busy,
            onPressed: () => unawaited(_publish()),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: strings.deleteDraft,
            icon: Icons.delete_outline,
            variant: AppButtonVariant.danger,
            onPressed: _busy ? null : () => unawaited(_deleteDraft()),
          ),
        ] else ...[
          AppButton(
            label: strings.attemptsButton,
            icon: Icons.fact_check_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(RoutePaths.instructorExamAttempts(exam.id)),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (canReturnToDraft)
            AppButton(
              label: strings.unpublishExam,
              variant: AppButtonVariant.secondary,
              busy: _busy,
              onPressed: () => unawaited(_run(() => ref.read(examRepositoryProvider).unpublish(exam.id))),
            ),
          if (exam.lifecycle == ExamLifecycle.published) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: strings.archiveExam,
              icon: Icons.archive_outlined,
              variant: AppButtonVariant.danger,
              onPressed: _busy ? null : () => unawaited(_archive()),
            ),
          ],
        ],
      ],
    );
  }
}
