import 'dart:async';

import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_error_view.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/presentation/details_step.dart';
import 'package:examora_app/features/exams/presentation/exam_queries.dart';
import 'package:examora_app/features/exams/presentation/questions_step.dart';
import 'package:examora_app/features/exams/presentation/review_step.dart';
import 'package:examora_app/features/exams/presentation/schedule_step.dart';
import 'package:examora_app/features/exams/presentation/settings_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The authoring wizard: details, questions, settings, schedule, review and publish.
///
/// Both ways of creating an exam start here, so the exam always has a title before anything is saved or imported. Every
/// step saves on its own: leaving halfway loses nothing that was saved, and nothing is saved that was not asked for.
class ExamWizardScreen extends ConsumerStatefulWidget {
  /// Creates the wizard for [examId], or for a brand-new exam when it is [RoutePaths.newExamId].
  const ExamWizardScreen({required this.examId, this.method, super.key});

  /// The exam being edited, or [RoutePaths.newExamId].
  final String examId;

  /// For a new exam: [RoutePaths.methodManual] or [RoutePaths.methodWord].
  final String? method;

  @override
  ConsumerState<ExamWizardScreen> createState() => _ExamWizardScreenState();
}

class _ExamWizardScreenState extends ConsumerState<ExamWizardScreen> {
  late String? _examId = widget.examId == RoutePaths.newExamId ? null : widget.examId;
  int _step = 0;

  static const int _stepCount = 5;

  void _goTo(int step) => setState(() => _step = step.clamp(0, _stepCount - 1));

  Future<void> _created(Exam exam) async {
    setState(() => _examId = exam.id);
    ref.invalidate(examListProvider);
    if (widget.method == RoutePaths.methodWord) {
      // The importer needs a saved, titled exam to add the questions to; it comes back to the questions step.
      setState(() => _step = 1);
      await context.push<void>(RoutePaths.instructorExamImport(exam.id));
      if (!mounted) return;
      ref.invalidate(examDetailProvider(exam.id));
    } else {
      _goTo(1);
    }
  }

  void _changed(Exam exam) {
    ref.invalidate(examDetailProvider(exam.id));
    ref.invalidate(examListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final id = _examId;
    final stepNames = [
      strings.stepDetails,
      strings.stepQuestions,
      strings.stepSettings,
      strings.stepSchedule,
      strings.stepReview,
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(id == null ? strings.wizardNewTitle : strings.wizardEditTitle),
      ),
      body: SafeArea(
        child: id == null
            ? _Body(
                step: 0,
                stepNames: stepNames,
                canJump: false,
                onJump: _goTo,
                child: DetailsStep(
                  key: const ValueKey('details-new'),
                  exam: null,
                  editable: true,
                  onSaved: (exam) => unawaited(_created(exam)),
                ),
              )
            : _existing(id, stepNames),
      ),
    );
  }

  Widget _existing(String id, List<String> stepNames) {
    final result = ref.watch(examDetailProvider(id));
    return result.when(
      loading: () => const AppLoadingView(),
      error: (error, stack) => AppErrorView(
        // Repositories return failures instead of throwing, so this is an unexpected error.
        failure: const ServerFailure(),
        onRetry: () => ref.invalidate(examDetailProvider(id)),
      ),
      data: (outcome) => switch (outcome) {
        Err<Exam>(:final failure) => AppErrorView(
          failure: failure,
          onRetry: () => ref.invalidate(examDetailProvider(id)),
        ),
        Ok<Exam>(:final value) => _loaded(value, stepNames),
      },
    );
  }

  Widget _loaded(Exam exam, List<String> stepNames) {
    final now = ref.watch(clockProvider).now();
    final editable = switch (exam.lifecycle) {
      ExamLifecycle.draft => true,
      ExamLifecycle.archived => false,
      ExamLifecycle.published => exam.opensAt != null && exam.opensAt!.isAfter(now),
    };
    final key = ValueKey('${exam.id}-$_step');
    final Widget step = switch (_step) {
      0 => DetailsStep(
        key: key,
        exam: exam,
        editable: editable,
        onSaved: (saved) {
          _changed(saved);
          _goTo(1);
        },
      ),
      1 => QuestionsStep(
        key: key,
        exam: exam,
        editable: editable,
        onChanged: () => _changed(exam),
        onNext: () => _goTo(2),
      ),
      2 => SettingsStep(
        key: key,
        exam: exam,
        editable: editable,
        onSaved: (saved) {
          _changed(saved);
          _goTo(3);
        },
      ),
      3 => ScheduleStep(
        key: key,
        exam: exam,
        editable: editable,
        onSaved: (saved) {
          _changed(saved);
          _goTo(4);
        },
      ),
      _ => ReviewStep(key: key, exam: exam, onChanged: () => _changed(exam), onGoToStep: _goTo),
    };
    return _Body(
      step: _step,
      stepNames: stepNames,
      canJump: true,
      onJump: _goTo,
      notice: editable ? null : context.strings.examNotEditableNotice,
      child: step,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.step,
    required this.stepNames,
    required this.canJump,
    required this.onJump,
    required this.child,
    this.notice,
  });

  final int step;
  final List<String> stepNames;
  final bool canJump;
  final ValueChanged<int> onJump;
  final Widget child;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SingleChildScrollView(
      child: ResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                strings.wizardStepOf(step + 1, stepNames.length, stepNames[step]),
                style: AppTypography.heading,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ExcludeSemantics(child: LinearProgressIndicator(value: (step + 1) / stepNames.length)),
            const SizedBox(height: AppSpacing.md),
            // A Wrap so the five names flow onto more lines at large text sizes.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var index = 0; index < stepNames.length; index++)
                  ChoiceChip(
                    label: Text(stepNames[index]),
                    selected: index == step,
                    onSelected: canJump ? (_) => onJump(index) : null,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (notice != null) ...[
              AppBanner(message: notice!, tone: StatusTone.warning),
              const SizedBox(height: AppSpacing.lg),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
