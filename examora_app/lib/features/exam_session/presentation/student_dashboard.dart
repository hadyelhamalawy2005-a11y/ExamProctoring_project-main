import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_error_view.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:examora_app/core/widgets/app_section_header.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exam_session/presentation/student_exam_list_screen.dart';
import 'package:examora_app/features/exam_session/presentation/student_queries.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The student's home: a welcome, the exams that are open or coming up, and the latest result. Each part loads on its own,
/// so a failure in one is shown as a failure (with a retry), never as "nothing here".
class StudentDashboard extends ConsumerWidget {
  /// Creates the dashboard.
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final auth = ref.watch(authControllerProvider);
    final exams = ref.watch(studentExamListProvider);
    final results = ref.watch(studentResultsProvider);

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(strings.appName)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth is AuthSignedIn)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(strings.welcomeUser(auth.account.fullName), style: AppTypography.title),
                        Text(strings.roleName(auth.account.role), style: AppTypography.body),
                      ],
                    ),
                  ),
                AppSectionHeader(strings.studentExamsTitle),
                exams.when(
                  loading: () => const SizedBox(height: 120, child: AppLoadingView()),
                  error: (e, s) => const SizedBox.shrink(),
                  data: (outcome) => switch (outcome) {
                    Err<List<StudentExamSummary>>(:final failure) => SizedBox(
                      height: 240,
                      child: AppErrorView(failure: failure, onRetry: () => ref.invalidate(studentExamListProvider)),
                    ),
                    Ok<List<StudentExamSummary>>(:final value) => _upcoming(context, value),
                  },
                ),
                AppSectionHeader(strings.studentResultsTitle),
                results.when(
                  loading: () => const SizedBox(height: 120, child: AppLoadingView()),
                  error: (e, s) => const SizedBox.shrink(),
                  data: (outcome) => switch (outcome) {
                    Err<List<StudentResult>>(:final failure) => SizedBox(
                      height: 240,
                      child: AppErrorView(failure: failure, onRetry: () => ref.invalidate(studentResultsProvider)),
                    ),
                    Ok<List<StudentResult>>(:final value) => _latest(context, value),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _upcoming(BuildContext context, List<StudentExamSummary> exams) {
    final strings = context.strings;
    // Open now first, then coming up, then finished; at most three.
    final order = {ExamStatus.ongoing: 0, ExamStatus.scheduled: 1, ExamStatus.completed: 2};
    final shown = [...exams]..sort((a, b) => (order[a.status] ?? 3).compareTo(order[b.status] ?? 3));
    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(strings.studentExamsEmptyTitle, key: const Key('dashboard-no-exams'), style: AppTypography.body),
      );
    }
    return Column(
      children: [
        for (final exam in shown.take(3)) ...[
          StudentExamCard(exam: exam, onTap: () => context.push(RoutePaths.studentExam(exam.id))),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _latest(BuildContext context, List<StudentResult> results) {
    final strings = context.strings;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          strings.studentResultsEmptyTitle,
          key: const Key('dashboard-no-results'),
          style: AppTypography.body,
        ),
      );
    }
    final latest = results.first;
    final marks = latest.result;
    return AppCard(
      onTap: () => context.push(RoutePaths.studentAttemptResult(latest.attemptId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.isolate(latest.examTitle), style: AppTypography.heading),
          Text(
            marks == null
                ? strings.resultHeldBack(
                    latest.releaseAt == null ? '' : DateFormatting.dateTime(context, latest.releaseAt!),
                  )
                : strings.resultScore(formatNumber(marks.awardedMarks), formatNumber(marks.totalMarks)),
            style: AppTypography.body,
          ),
        ],
      ),
    );
  }
}
