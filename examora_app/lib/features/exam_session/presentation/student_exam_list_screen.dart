import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_empty_view.dart';
import 'package:examora_app/core/widgets/async_result_view.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exam_session/presentation/student_queries.dart';
import 'package:examora_app/features/exams/presentation/exam_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// One exam in the student's list.
class StudentExamCard extends StatelessWidget {
  /// Creates the card.
  const StudentExamCard({required this.exam, required this.onTap, super.key});

  /// The exam.
  final StudentExamSummary exam;

  /// Called when tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final opens = exam.opensAt;
    final closes = exam.closesAt;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.isolate(exam.title), style: AppTypography.heading),
          const SizedBox(height: AppSpacing.xs),
          Text(
            strings.examSummary(exam.courseName, exam.durationMinutes, exam.questionCount),
            style: AppTypography.body,
          ),
          if (opens != null && closes != null)
            Text(
              strings.examWindow(DateFormatting.dateTime(context, opens), DateFormatting.dateTime(context, closes)),
              style: AppTypography.caption,
            ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ExamStatusBadge(status: exam.status),
              StatusBadge(
                label: strings.attemptStateName(exam.attemptState),
                tone: exam.attemptState == AttemptState.submitted ? StatusTone.success : StatusTone.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The student's exams.
class StudentExamListScreen extends ConsumerWidget {
  /// Creates the screen.
  const StudentExamListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(strings.studentExamsTitle)),
      body: SafeArea(
        child: AsyncResultView<List<StudentExamSummary>>(
          value: ref.watch(studentExamListProvider),
          onRetry: () => ref.invalidate(studentExamListProvider),
          builder: (exams) {
            if (exams.isEmpty) {
              return AppEmptyView(
                icon: Icons.assignment_outlined,
                title: strings.studentExamsEmptyTitle,
                message: strings.studentExamsEmptyBody,
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(studentExamListProvider),
              child: ListView(
                children: [
                  ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final exam in exams) ...[
                          StudentExamCard(
                            exam: exam,
                            onTap: () => unawaited(_open(context, ref, RoutePaths.studentExam(exam.id))),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, String path) async {
    await context.push<void>(path);
    ref.invalidate(studentExamListProvider);
  }
}
