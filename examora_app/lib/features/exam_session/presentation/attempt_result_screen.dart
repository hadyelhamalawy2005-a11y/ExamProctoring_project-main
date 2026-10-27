import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_empty_view.dart';
import 'package:examora_app/core/widgets/app_section_header.dart';
import 'package:examora_app/core/widgets/async_result_view.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/presentation/student_queries.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The marks of one attempt, as the student may see them. It never shows which option was correct.
class AttemptResultScreen extends ConsumerWidget {
  /// Creates the screen.
  const AttemptResultScreen({required this.attemptId, super.key});

  /// The attempt.
  final String attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.resultTitle),
      ),
      body: SafeArea(
        child: AsyncResultView<StudentResult>(
          value: ref.watch(studentResultProvider(attemptId)),
          onRetry: () => ref.invalidate(studentResultProvider(attemptId)),
          builder: (result) => SingleChildScrollView(
            child: ResponsiveContent(child: ResultBody(result: result)),
          ),
        ),
      ),
    );
  }
}

/// The content of a result.
class ResultBody extends StatelessWidget {
  /// Creates the body.
  const ResultBody({required this.result, super.key});

  /// The result.
  final StudentResult result;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final marks = result.result;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.isolate(result.examTitle), style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(
          strings.resultSubmittedAt(DateFormatting.dateTime(context, result.submittedAt)),
          style: AppTypography.caption,
        ),
        if (result.submissionKind == SubmissionKind.auto) ...[
          const SizedBox(height: AppSpacing.sm),
          AppBanner(message: strings.resultAutoSubmitted, tone: StatusTone.info),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (marks == null)
          AppBanner(
            message: strings.resultHeldBack(
              result.releaseAt == null ? '' : DateFormatting.dateTime(context, result.releaseAt!),
            ),
            tone: StatusTone.info,
          )
        else ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.resultScore(formatNumber(marks.awardedMarks), formatNumber(marks.totalMarks)),
                  key: const Key('result-score'),
                  style: AppTypography.title,
                ),
                Text(strings.resultPercent(marks.percentage.toStringAsFixed(1)), style: AppTypography.heading),
                const SizedBox(height: AppSpacing.sm),
                if (marks.passed != null)
                  StatusBadge(
                    label: marks.passed! ? strings.resultPassed : strings.resultFailed,
                    tone: marks.passed! ? StatusTone.success : StatusTone.danger,
                  )
                else if (marks.isFinal && marks.passMarkPercent == null)
                  Text(strings.resultNoPassMark, style: AppTypography.caption),
              ],
            ),
          ),
          if (!marks.isFinal) ...[
            const SizedBox(height: AppSpacing.md),
            AppBanner(message: strings.resultPending(marks.pendingManualCount), tone: StatusTone.warning),
          ],
          AppSectionHeader(strings.resultAnswersHeading),
          for (var index = 0; index < marks.questions.length; index++) ...[
            _QuestionRow(
              number: index + 1,
              result: marks.questions[index],
              text: result.questionTexts,
              explanations: result.explanations,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(strings.resultsNoKeyNote, style: AppTypography.caption),
        ],
      ],
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({required this.number, required this.result, required this.text, required this.explanations});

  final int number;
  final QuestionResult result;
  final Map<String, String> text;
  final Map<String, String> explanations;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final awarded = result.marksAwarded;
    final tone = switch (result.outcome) {
      QuestionOutcome.correct => StatusTone.success,
      QuestionOutcome.incorrect => StatusTone.danger,
      QuestionOutcome.unanswered => StatusTone.warning,
      QuestionOutcome.pendingManual => StatusTone.info,
      QuestionOutcome.markedManually => StatusTone.success,
    };
    final explanation = explanations[result.questionId];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.questionNumber(number), style: AppTypography.caption),
          Text(strings.isolate(text[result.questionId] ?? ''), style: AppTypography.body),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusBadge(label: strings.outcomeName(result.outcome), tone: tone),
              if (awarded != null) Text(strings.questionMarksOf(formatNumber(awarded), formatNumber(result.maxMarks))),
            ],
          ),
          if (explanation != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('${strings.explanationLabelShort}: ${strings.isolate(explanation)}', style: AppTypography.caption),
          ],
        ],
      ),
    );
  }
}

/// The student's results.
class StudentResultsScreen extends ConsumerWidget {
  /// Creates the screen.
  const StudentResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(strings.studentResultsTitle)),
      body: SafeArea(
        child: AsyncResultView<List<StudentResult>>(
          value: ref.watch(studentResultsProvider),
          onRetry: () => ref.invalidate(studentResultsProvider),
          builder: (results) {
            if (results.isEmpty) {
              return AppEmptyView(
                icon: Icons.grading_outlined,
                title: strings.studentResultsEmptyTitle,
                message: strings.studentResultsEmptyBody,
              );
            }
            return ListView(
              children: [
                ResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final result in results) ...[
                        AppCard(
                          onTap: () => context.push(RoutePaths.studentAttemptResult(result.attemptId)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(strings.isolate(result.examTitle), style: AppTypography.heading),
                              Text(DateFormatting.dateTime(context, result.submittedAt), style: AppTypography.caption),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                result.result == null
                                    ? strings.resultHeldBack(
                                        result.releaseAt == null
                                            ? ''
                                            : DateFormatting.dateTime(context, result.releaseAt!),
                                      )
                                    : strings.resultScore(
                                        formatNumber(result.result!.awardedMarks),
                                        formatNumber(result.result!.totalMarks),
                                      ),
                                style: AppTypography.body,
                              ),
                            ],
                          ),
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
