import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/utilities/number_parsing.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_empty_view.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/async_result_view.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/data/exam_session_providers.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exam_session/domain/instructor_attempt.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The attempts at one exam.
final attemptsForExamProvider = FutureProvider.autoDispose.family<Result<List<AttemptSummary>>, String>(
  (ref, examId) => ref.watch(instructorAttemptRepositoryProvider).listForExam(examId),
);

/// One attempt, for review.
final attemptReviewProvider = FutureProvider.autoDispose.family<Result<AttemptReview>, String>(
  (ref, attemptId) => ref.watch(instructorAttemptRepositoryProvider).getReview(attemptId),
);

/// The attempts at an exam the instructor owns, newest first, with the marks so far and how many incidents each has.
class InstructorAttemptsScreen extends ConsumerWidget {
  /// Creates the screen.
  const InstructorAttemptsScreen({required this.examId, super.key});

  /// The exam.
  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.attemptsTitle),
      ),
      body: SafeArea(
        child: AsyncResultView<List<AttemptSummary>>(
          value: ref.watch(attemptsForExamProvider(examId)),
          onRetry: () => ref.invalidate(attemptsForExamProvider(examId)),
          builder: (attempts) {
            if (attempts.isEmpty) {
              return AppEmptyView(
                icon: Icons.fact_check_outlined,
                title: strings.attemptsEmptyTitle,
                message: strings.attemptsEmptyBody,
              );
            }
            return ListView(
              children: [
                ResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final attempt in attempts) ...[
                        _AttemptCard(
                          attempt: attempt,
                          onTap: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => AttemptReviewScreen(attemptId: attempt.attemptId),
                              ),
                            );
                            ref.invalidate(attemptsForExamProvider(examId));
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AttemptCard extends StatelessWidget {
  const _AttemptCard({required this.attempt, required this.onTap});

  final AttemptSummary attempt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final result = attempt.result;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.isolate(attempt.studentName), style: AppTypography.heading),
          Text(DateFormatting.dateTime(context, attempt.startedAt), style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(
                label: strings.attemptStatusName(attempt.status),
                tone: attempt.status == AttemptStatus.submitted ? StatusTone.success : StatusTone.info,
              ),
              if (result != null)
                Text(strings.attemptMarks(formatNumber(result.awardedMarks), formatNumber(result.totalMarks))),
              if (result != null && result.pendingManualCount > 0)
                StatusBadge(label: strings.attemptPending(result.pendingManualCount), tone: StatusTone.warning),
              if (attempt.incidentCount > 0)
                StatusBadge(label: strings.attemptIncidents(attempt.incidentCount), tone: StatusTone.warning),
            ],
          ),
        ],
      ),
    );
  }
}

/// One attempt with every answer and its marks. Typed answers are marked here, by the instructor; the app never marks them.
class AttemptReviewScreen extends ConsumerWidget {
  /// Creates the screen.
  const AttemptReviewScreen({required this.attemptId, super.key});

  /// The attempt.
  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: strings.back,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(strings.attemptReviewTitle),
      ),
      body: SafeArea(
        child: AsyncResultView<AttemptReview>(
          value: ref.watch(attemptReviewProvider(attemptId)),
          onRetry: () => ref.invalidate(attemptReviewProvider(attemptId)),
          builder: (review) => SingleChildScrollView(
            child: ResponsiveContent(child: _ReviewBody(review: review)),
          ),
        ),
      ),
    );
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.review});

  final AttemptReview review;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final result = review.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.isolate(review.studentName), style: AppTypography.title),
        Text(strings.isolate(review.examTitle), style: AppTypography.body),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(
              label: strings.attemptStatusName(review.status),
              tone: review.status == AttemptStatus.submitted ? StatusTone.success : StatusTone.info,
            ),
            Text(
              strings.attemptMarks(formatNumber(result.awardedMarks), formatNumber(result.totalMarks)),
              key: const Key('review-marks'),
              style: AppTypography.heading,
            ),
            if (review.incidentCount > 0)
              StatusBadge(label: strings.attemptIncidents(review.incidentCount), tone: StatusTone.warning),
          ],
        ),
        if (review.submittedAt != null)
          Text(
            strings.resultSubmittedAt(DateFormatting.dateTime(context, review.submittedAt!)),
            style: AppTypography.caption,
          ),
        if (review.submissionKind == SubmissionKind.auto) ...[
          const SizedBox(height: AppSpacing.sm),
          AppBanner(message: strings.resultAutoSubmitted, tone: StatusTone.info),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (var index = 0; index < review.questions.length; index++) ...[
          _QuestionReview(
            key: ValueKey(review.questions[index].question.id),
            attemptId: review.attemptId,
            number: index + 1,
            item: review.questions[index],
            canMark: review.status == AttemptStatus.submitted,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _QuestionReview extends ConsumerStatefulWidget {
  const _QuestionReview({
    required this.attemptId,
    required this.number,
    required this.item,
    required this.canMark,
    super.key,
  });

  final String attemptId;
  final int number;
  final ReviewedQuestion item;
  final bool canMark;

  @override
  ConsumerState<_QuestionReview> createState() => _QuestionReviewState();
}

class _QuestionReviewState extends ConsumerState<_QuestionReview> {
  late final TextEditingController _marks = TextEditingController(
    text: widget.item.result.marksAwarded == null ? '' : formatNumber(widget.item.result.marksAwarded!),
  );
  bool _busy = false;
  AppFailure? _failure;
  String? _notice;

  @override
  void dispose() {
    _marks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final parsed = NumberParsing.parseDecimal(_marks.text);
    if (parsed == null) {
      setState(() => _failure = const ValidationFailure(fields: {'marks': KnownFieldProblem(FieldReason.outOfRange)}));
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
      _notice = null;
    });
    final result = await ref
        .read(instructorAttemptRepositoryProvider)
        .markShortAnswer(widget.attemptId, widget.item.question.id, parsed);
    if (!mounted) return;
    switch (result) {
      case Ok<AttemptReview>(:final value):
        final saved =
            value.questions.firstWhere((q) => q.question.id == widget.item.question.id).result.marksAwarded ?? 0;
        _marks.text = formatNumber(saved);
        final strings = context.strings;
        setState(() {
          _busy = false;
          _notice = saved != parsed
              ? strings.marksClamped(formatNumber(saved))
              : strings.marksSaved(formatNumber(saved));
        });
        ref.invalidate(attemptReviewProvider(widget.attemptId));
      case Err<AttemptReview>(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final question = widget.item.question;
    final answer = widget.item.answer;
    final result = widget.item.result;
    final awarded = result.marksAwarded;
    final failure = _failure;
    final tone = switch (result.outcome) {
      QuestionOutcome.correct || QuestionOutcome.markedManually => StatusTone.success,
      QuestionOutcome.incorrect => StatusTone.danger,
      QuestionOutcome.unanswered => StatusTone.warning,
      QuestionOutcome.pendingManual => StatusTone.info,
    };
    final chosen = answer is ChoiceAnswer ? answer.optionIds : const <String>{};

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.questionNumber(widget.number), style: AppTypography.caption),
          Text(strings.isolate(question.text), style: AppTypography.heading),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusBadge(label: strings.questionTypeName(question.type), tone: StatusTone.info),
              StatusBadge(label: strings.outcomeName(result.outcome), tone: tone),
              if (awarded != null) Text(strings.questionMarksOf(formatNumber(awarded), formatNumber(question.marks))),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (question.type.hasOptions)
            for (final option in question.options)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      chosen.contains(option.id) ? Icons.check_box : Icons.check_box_outline_blank,
                      size: AppIconSizes.sm,
                      semanticLabel: chosen.contains(option.id) ? strings.chosenMarker : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${strings.isolate(option.text)}${option.isCorrect ? '  ✓ ${strings.correctMarker}' : ''}',
                        style: option.isCorrect
                            ? AppTypography.body.copyWith(fontWeight: FontWeight.w700)
                            : AppTypography.body,
                      ),
                    ),
                  ],
                ),
              )
          else ...[
            Text(strings.studentAnswerLabel, style: AppTypography.caption),
            Text(
              answer is TextAnswer && answer.text.trim().isNotEmpty ? strings.isolate(answer.text) : strings.noAnswer,
              key: Key('typed-answer-${question.id}'),
              style: AppTypography.body,
            ),
            if (question.modelAnswer != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(strings.modelAnswerLabel, style: AppTypography.caption),
              Text(strings.isolate(question.modelAnswer!), style: AppTypography.body),
            ],
            if (widget.canMark && answer is TextAnswer && answer.text.trim().isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              if (failure != null) ...[
                AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_notice != null) ...[
                AppBanner(message: _notice!, tone: StatusTone.success),
                const SizedBox(height: AppSpacing.sm),
              ],
              AppTextField(
                controller: _marks,
                label: strings.marksOutOf(formatNumber(question.marks)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ltr: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: strings.saveMarks,
                busy: _busy,
                variant: AppButtonVariant.secondary,
                onPressed: () => unawaited(_save()),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
