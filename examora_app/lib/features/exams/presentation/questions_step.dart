import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_dialogs.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:examora_app/features/exams/presentation/question_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Step 2: the questions. Add, edit, reorder and delete by hand, or import them from a Word file.
class QuestionsStep extends ConsumerStatefulWidget {
  /// Creates the step.
  const QuestionsStep({
    required this.exam,
    required this.editable,
    required this.onChanged,
    required this.onNext,
    super.key,
  });

  /// The exam being edited.
  final Exam exam;

  /// False when the exam can no longer be changed.
  final bool editable;

  /// Called after the questions changed, so the screen reloads the exam.
  final VoidCallback onChanged;

  /// Moves on to the settings step.
  final VoidCallback onNext;

  @override
  ConsumerState<QuestionsStep> createState() => _QuestionsStepState();
}

class _QuestionsStepState extends ConsumerState<QuestionsStep> {
  bool _busy = false;
  AppFailure? _failure;

  Future<void> _edit(Question? question) async {
    final saved = await openQuestionEditor(context, examId: widget.exam.id, question: question);
    if (saved ?? false) widget.onChanged();
  }

  Future<void> _import() async {
    await context.push<void>(RoutePaths.instructorExamImport(widget.exam.id));
    if (mounted) widget.onChanged();
  }

  Future<void> _run(Future<Result<Exam>> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = result.failureOrNull;
    });
    widget.onChanged();
  }

  Future<void> _delete(Question question) async {
    final strings = context.strings;
    final confirmed = await AppDialogs.confirm(
      context,
      title: strings.deleteQuestionTitle,
      message: strings.deleteQuestionBody,
      confirmLabel: strings.deleteQuestion,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() => ref.read(examRepositoryProvider).deleteQuestion(widget.exam.id, question.id));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final exam = widget.exam;
    final failure = _failure;
    final enabled = widget.editable && !_busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
          const SizedBox(height: AppSpacing.lg),
        ],
        Text(
          strings.questionsSummary(exam.questions.length, formatNumber(exam.totalMarks)),
          style: AppTypography.heading,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: strings.addQuestion,
          icon: Icons.add,
          onPressed: enabled ? () => unawaited(_edit(null)) : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: strings.examMethodWord,
          icon: Icons.description_outlined,
          variant: AppButtonVariant.secondary,
          onPressed: enabled ? () => unawaited(_import()) : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (exam.questions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Text(strings.questionsEmpty, textAlign: TextAlign.center, style: AppTypography.body),
          )
        else
          for (var index = 0; index < exam.questions.length; index++) ...[
            _QuestionCard(
              number: index + 1,
              question: exam.questions[index],
              enabled: enabled,
              canMoveUp: index > 0,
              canMoveDown: index < exam.questions.length - 1,
              onEdit: () => unawaited(_edit(exam.questions[index])),
              onDelete: () => unawaited(_delete(exam.questions[index])),
              onMoveUp: () => unawaited(
                _run(() => ref.read(examRepositoryProvider).moveQuestion(exam.id, exam.questions[index].id, index - 1)),
              ),
              onMoveDown: () => unawaited(
                _run(() => ref.read(examRepositoryProvider).moveQuestion(exam.id, exam.questions[index].id, index + 1)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(label: strings.nextStep, onPressed: widget.onNext),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.number,
    required this.question,
    required this.enabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onEdit,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int number;
  final Question question;
  final bool enabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppCard(
      onTap: enabled ? onEdit : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.questionNumber(number), style: AppTypography.caption),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.isolate(question.text),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.heading,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusBadge(label: strings.questionTypeName(question.type), tone: StatusTone.info),
              StatusBadge(label: strings.marksValue(formatNumber(question.marks)), tone: StatusTone.info),
              if (question.source == QuestionSource.wordImport)
                StatusBadge(label: strings.wordBadge, tone: StatusTone.info),
              if (question.needsReview) StatusBadge(label: strings.needsReviewBadge, tone: StatusTone.warning),
              if (question.answerKeyStale && question.type.hasOptions)
                StatusBadge(label: strings.answerKeyStaleBadge, tone: StatusTone.warning),
            ],
          ),
          Wrap(
            children: [
              TextButton.icon(
                onPressed: enabled ? onEdit : null,
                icon: const Icon(Icons.edit_outlined),
                label: Text(strings.editQuestion),
              ),
              IconButton(
                tooltip: strings.moveUp,
                icon: const Icon(Icons.arrow_upward),
                onPressed: enabled && canMoveUp ? onMoveUp : null,
              ),
              IconButton(
                tooltip: strings.moveDown,
                icon: const Icon(Icons.arrow_downward),
                onPressed: enabled && canMoveDown ? onMoveDown : null,
              ),
              IconButton(
                tooltip: strings.deleteQuestion,
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: enabled ? onDelete : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
