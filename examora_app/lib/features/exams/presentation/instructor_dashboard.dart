import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_section_header.dart';
import 'package:examora_app/core/widgets/async_result_view.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:examora_app/features/exam_session/data/exam_session_providers.dart';
import 'package:examora_app/features/exam_session/domain/instructor_attempt.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_repository.dart';
import 'package:examora_app/features/incident_review/presentation/incident_queue_screen.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// How many exams the instructor has in each status.
final examCountsProvider = FutureProvider.autoDispose<Result<Map<ExamStatus, int>>>((ref) async {
  final repository = ref.watch(examRepositoryProvider);
  final counts = <ExamStatus, int>{};
  for (final status in ExamStatus.values) {
    final page = await repository.listExams(status: status, pageSize: 1);
    switch (page) {
      case Err<ExamPage>(:final failure):
        return Err(failure);
      case Ok<ExamPage>(:final value):
        counts[status] = value.totalCount;
    }
  }
  return Ok(counts);
});

/// How many typed answers across the instructor's published exams are waiting to be marked.
final pendingMarkingProvider = FutureProvider.autoDispose<Result<int>>((ref) async {
  final exams = await ref.watch(examRepositoryProvider).listExams(pageSize: ExamRepository.maxPageSize);
  switch (exams) {
    case Err<ExamPage>(:final failure):
      return Err(failure);
    case Ok<ExamPage>(:final value):
      var pending = 0;
      for (final exam in value.items) {
        if (exam.status == ExamStatus.draft) continue;
        final attempts = await ref.watch(instructorAttemptRepositoryProvider).listForExam(exam.id);
        switch (attempts) {
          case Err<List<AttemptSummary>>(:final failure):
            return Err(failure);
          case Ok<List<AttemptSummary>>(:final value):
            for (final attempt in value) {
              pending += attempt.result?.pendingManualCount ?? 0;
            }
        }
      }
      return Ok(pending);
  }
});

/// The instructor's home: how many exams are in each status, what is waiting for them (typed answers to mark, incidents to
/// decide) and a way to create an exam. Every number comes from the stored data; a failed load is shown as a failure.
class InstructorDashboard extends ConsumerWidget {
  /// Creates the dashboard.
  const InstructorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final auth = ref.watch(authControllerProvider);

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
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: strings.createExamButton,
                  icon: Icons.add,
                  onPressed: () => context.push(RoutePaths.instructorNewExamMethod),
                ),
                AppSectionHeader(strings.dashboardExamsHeading),
                AsyncResultView<Map<ExamStatus, int>>(
                  value: ref.watch(examCountsProvider),
                  onRetry: () => ref.invalidate(examCountsProvider),
                  builder: (counts) => Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final status in ExamStatus.values)
                        Text(
                          strings.dashboardStatusCount(strings.examStatusName(status), counts[status] ?? 0),
                          key: Key('count-${status.name}'),
                          style: AppTypography.body,
                        ),
                    ],
                  ),
                ),
                AppSectionHeader(strings.attemptsTitle),
                AsyncResultView<int>(
                  value: ref.watch(pendingMarkingProvider),
                  onRetry: () => ref.invalidate(pendingMarkingProvider),
                  builder: (pending) => Text(
                    pending == 0 ? strings.dashboardNothingToMark : strings.dashboardNeedsMarking(pending),
                    key: const Key('dashboard-marking'),
                    style: AppTypography.body,
                  ),
                ),
                AppSectionHeader(strings.incidentsTitle),
                AsyncResultView<List<IncidentSummary>>(
                  value: ref.watch(incidentQueueProvider(false)),
                  onRetry: () => ref.invalidate(incidentQueueProvider),
                  builder: (waiting) => Text(
                    waiting.isEmpty
                        ? strings.dashboardNoIncidentsWaiting
                        : strings.dashboardIncidentsWaiting(waiting.length),
                    key: const Key('dashboard-incidents'),
                    style: AppTypography.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
