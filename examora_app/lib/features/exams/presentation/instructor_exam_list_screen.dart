import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_empty_view.dart';
import 'package:examora_app/core/widgets/app_error_view.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/presentation/exam_queries.dart';
import 'package:examora_app/features/exams/presentation/exam_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The instructor's own exams: filter by status, newest first, a page at a time. Loading, empty and failed are three
/// different screens: "you have no exams" is never shown where "this did not load" belongs.
class InstructorExamListScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const InstructorExamListScreen({super.key});

  @override
  ConsumerState<InstructorExamListScreen> createState() => _InstructorExamListScreenState();
}

class _InstructorExamListScreenState extends ConsumerState<InstructorExamListScreen> {
  ExamStatus? _status;
  int _page = 1;

  ExamQuery get _query => (status: _status, page: _page);

  Future<void> _open(String path) async {
    await context.push<void>(path);
    if (mounted) ref.invalidate(examListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final result = ref.watch(examListProvider(_query));

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(strings.examsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: strings.createExamButton,
                  icon: Icons.add,
                  onPressed: () => unawaited(_open(RoutePaths.instructorNewExamMethod)),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ChoiceChip(
                      label: Text(strings.filterAll),
                      selected: _status == null,
                      onSelected: (_) => setState(() {
                        _status = null;
                        _page = 1;
                      }),
                    ),
                    for (final status in ExamStatus.values)
                      ChoiceChip(
                        label: Text(strings.examStatusName(status)),
                        selected: _status == status,
                        onSelected: (_) => setState(() {
                          _status = status;
                          _page = 1;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                result.when(
                  loading: () => const SizedBox(height: 240, child: AppLoadingView()),
                  error: (error, stack) => SizedBox(
                    height: 280,
                    child: AppErrorView(
                      failure: const ServerFailure(),
                      onRetry: () => ref.invalidate(examListProvider),
                    ),
                  ),
                  data: (outcome) => switch (outcome) {
                    Err<ExamPage>(:final failure) => SizedBox(
                      height: 280,
                      child: AppErrorView(failure: failure, onRetry: () => ref.invalidate(examListProvider)),
                    ),
                    Ok<ExamPage>(:final value) => _Page(
                      page: value,
                      filtered: _status != null,
                      onOpen: (exam) => unawaited(_open(RoutePaths.instructorExamEdit(exam.id))),
                      onCreate: () => unawaited(_open(RoutePaths.instructorNewExamMethod)),
                      onPage: (page) => setState(() => _page = page),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({
    required this.page,
    required this.filtered,
    required this.onOpen,
    required this.onCreate,
    required this.onPage,
  });

  final ExamPage page;
  final bool filtered;
  final ValueChanged<ExamSummary> onOpen;
  final VoidCallback onCreate;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    if (page.items.isEmpty) {
      return SizedBox(
        height: 280,
        child: AppEmptyView(
          icon: Icons.assignment_outlined,
          title: filtered ? strings.examsEmptyFiltered : strings.examsEmptyTitle,
          message: filtered ? null : strings.examsEmptyBody,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final exam in page.items) ...[
          ExamSummaryCard(exam: exam, onTap: () => onOpen(exam)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(strings.examsShowing(page.items.length, page.totalCount), style: AppTypography.caption),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: page.hasPrevious ? () => onPage(page.page - 1) : null,
              child: Text(strings.previousPage),
            ),
            Text(strings.pageNumber(page.page), style: AppTypography.caption),
            TextButton(onPressed: page.hasNext ? () => onPage(page.page + 1) : null, child: Text(strings.nextPage)),
          ],
        ),
      ],
    );
  }
}

/// One exam in a list: title, a line about it, and its status in words.
class ExamSummaryCard extends StatelessWidget {
  /// Creates the card.
  const ExamSummaryCard({required this.exam, required this.onTap, super.key});

  /// The exam.
  final ExamSummary exam;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final count = exam.questionCount;
    final course = exam.courseName;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.isolate(exam.title), style: AppTypography.heading),
          const SizedBox(height: AppSpacing.xs),
          if (course != null && count != null)
            Text(strings.examSummary(course, exam.durationMinutes, count), style: AppTypography.body),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ExamStatusBadge(status: exam.status),
              Text(strings.examVersionLabel(exam.version)),
            ],
          ),
        ],
      ),
    );
  }
}
