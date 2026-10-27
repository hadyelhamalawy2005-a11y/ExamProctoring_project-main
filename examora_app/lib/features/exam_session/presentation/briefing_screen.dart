import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_section_header.dart';
import 'package:examora_app/core/widgets/async_result_view.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exam_session/presentation/student_queries.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/presentation/exam_status_badge.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Everything a student may know about an exam before starting it, and the way on: consent, then the system check.
class BriefingScreen extends ConsumerWidget {
  /// Creates the screen.
  const BriefingScreen({required this.examId, super.key});

  /// The exam.
  final String examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.briefingTitle),
      ),
      body: SafeArea(
        child: AsyncResultView<StudentExamInfo>(
          value: ref.watch(studentExamInfoProvider(examId)),
          onRetry: () => ref.invalidate(studentExamInfoProvider(examId)),
          builder: (info) => SingleChildScrollView(
            child: ResponsiveContent(child: _Body(info: info)),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.info});

  final StudentExamInfo info;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final opens = info.opensAt;
    final closes = info.closesAt;

    final Widget action;
    switch (info.attemptState) {
      case AttemptState.submitted:
        action = AppButton(
          label: strings.briefingViewResult,
          onPressed: () => context.push(RoutePaths.studentAttemptResult(info.attemptId!)),
        );
      case AttemptState.inProgress:
        action = AppButton(
          label: strings.briefingResume,
          onPressed: () => context.push(RoutePaths.studentAttempt(info.attemptId!)),
        );
      case AttemptState.notStarted:
        if (info.status == ExamStatus.scheduled) {
          action = AppBanner(
            message: strings.briefingNotOpenYet(opens == null ? '' : DateFormatting.dateTime(context, opens)),
            tone: StatusTone.info,
          );
        } else if (info.status == ExamStatus.ongoing) {
          action = AppButton(
            label: strings.briefingContinue,
            onPressed: () => context.push(RoutePaths.studentConsent(info.id)),
          );
        } else {
          action = AppBanner(message: strings.briefingClosed, tone: StatusTone.warning);
        }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.isolate(info.title), style: AppTypography.title),
        const SizedBox(height: AppSpacing.xs),
        Text(strings.isolate(info.courseName), style: AppTypography.body),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExamStatusBadge(status: info.status),
        ),
        if (info.instructions.isNotEmpty) ...[
          AppSectionHeader(strings.briefingInstructionsHeading),
          AppCard(child: Text(strings.isolate(info.instructions), style: AppTypography.body)),
        ],
        AppSectionHeader(strings.briefingDetailsHeading),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.briefingDuration(info.durationMinutes), style: AppTypography.body),
              Text(strings.briefingQuestions(info.questionCount), style: AppTypography.body),
              Text(strings.briefingTotalMarks(formatNumber(info.totalMarks)), style: AppTypography.body),
              if (opens != null && closes != null)
                Text(
                  strings.briefingWindowLine(
                    DateFormatting.dateTime(context, opens),
                    DateFormatting.dateTime(context, closes),
                  ),
                  style: AppTypography.body,
                ),
              if (opens != null) Text(strings.timeZoneNote(DateFormatting.zone(opens)), style: AppTypography.caption),
            ],
          ),
        ),
        AppSectionHeader(strings.briefingRulesHeading),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.ruleCalculator(info.calculatorEnabled), style: AppTypography.body),
              Text(strings.ruleBackward(info.allowBackwardNavigation), style: AppTypography.body),
              Text(strings.ruleShuffled(info.randomizeQuestions, info.randomizeOptions), style: AppTypography.body),
              Text(strings.ruleAutosave, style: AppTypography.body),
            ],
          ),
        ),
        AppSectionHeader(strings.briefingMonitoringHeading),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (info.activeRules.isEmpty)
                Text(strings.monitoringNoneActive, style: AppTypography.body)
              else ...[
                Text(strings.monitoringIntro, style: AppTypography.body),
                for (final rule in info.activeRules)
                  Text('• ${strings.incidentCategoryName(rule)}', style: AppTypography.body),
              ],
              if (info.inactiveRules.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(strings.monitoringInactiveHeading, style: AppTypography.caption),
                for (final rule in info.inactiveRules)
                  Text('• ${strings.incidentCategoryName(rule)}', style: AppTypography.caption),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        action,
      ],
    );
  }
}
