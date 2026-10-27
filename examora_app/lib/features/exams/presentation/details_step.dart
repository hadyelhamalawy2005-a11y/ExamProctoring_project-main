import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/number_parsing.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/exam_validation.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Step 1: title, course, description, instructions, duration and pass mark. For a new exam, saving creates the draft.
class DetailsStep extends ConsumerStatefulWidget {
  /// Creates the step. [exam] is null while the exam does not exist yet.
  const DetailsStep({required this.exam, required this.editable, required this.onSaved, super.key});

  /// The exam being edited, or null for a new one.
  final Exam? exam;

  /// False when the exam can no longer be changed.
  final bool editable;

  /// Called with the exam as saved.
  final ValueChanged<Exam> onSaved;

  @override
  ConsumerState<DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends ConsumerState<DetailsStep> {
  late final _title = TextEditingController(text: widget.exam?.title);
  late final _course = TextEditingController(text: widget.exam?.courseName);
  late final _description = TextEditingController(text: widget.exam?.description);
  late final _instructions = TextEditingController(text: widget.exam?.instructions);
  late final _duration = TextEditingController(text: widget.exam?.durationMinutes.toString());
  late final _passMark = TextEditingController(
    text: widget.exam?.passMarkPercent == null ? '' : formatNumber(widget.exam!.passMarkPercent!),
  );
  bool _busy = false;
  AppFailure? _failure;
  Map<String, FieldProblem> _fields = {};

  @override
  void dispose() {
    _title.dispose();
    _course.dispose();
    _description.dispose();
    _instructions.dispose();
    _duration.dispose();
    _passMark.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final minutes = NumberParsing.parseInt(_duration.text);
    final passMark = NumberParsing.parseDecimal(_passMark.text);
    final details = ExamDetails(
      title: _title.text,
      courseName: _course.text,
      description: _description.text,
      instructions: _instructions.text,
      durationMinutes: minutes ?? 0,
      passMarkPercent: passMark ?? double.nan,
    );
    final problems = {
      ...ExamValidation.details(details),
      // Nothing typed is "required", not "out of range".
      if (_duration.text.trim().isEmpty) 'durationMinutes': const KnownFieldProblem(FieldReason.required),
      if (_passMark.text.trim().isEmpty) 'passMarkPercent': const KnownFieldProblem(FieldReason.required),
    };
    if (problems.isNotEmpty) {
      setState(() {
        _failure = null;
        _fields = problems;
      });
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
      _fields = {};
    });
    final repository = ref.read(examRepositoryProvider);
    final existing = widget.exam;
    final result = existing == null
        ? await repository.createExam(details)
        : await repository.updateDetails(existing.id, details);
    if (!mounted) return;
    switch (result) {
      case Ok<Exam>(:final value):
        setState(() => _busy = false);
        widget.onSaved(value);
      case Err<Exam>(:final failure):
        setState(() {
          _busy = false;
          if (failure is ValidationFailure && failure.fields.isNotEmpty) {
            _fields = failure.fields;
          } else {
            _failure = failure;
          }
        });
    }
  }

  String? _error(String field) {
    final problem = _fields[field];
    return problem == null ? null : context.strings.fieldProblemMessage(problem);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final failure = _failure;
    final enabled = widget.editable && !_busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
          const SizedBox(height: AppSpacing.lg),
        ],
        AppTextField(
          controller: _title,
          label: strings.examTitleLabel,
          errorText: _error('title'),
          maxLength: ExamLimits.titleMax,
          textInputAction: TextInputAction.next,
          enabled: enabled,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _course,
          label: strings.examCourseLabel,
          errorText: _error('courseName'),
          maxLength: ExamLimits.courseNameMax,
          textInputAction: TextInputAction.next,
          enabled: enabled,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _description,
          label: strings.examDescriptionLabel,
          errorText: _error('description'),
          maxLines: 3,
          enabled: enabled,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _instructions,
          label: strings.examInstructionsLabel,
          errorText: _error('instructions'),
          maxLines: 4,
          enabled: enabled,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _duration,
          label: strings.examDurationLabel,
          errorText: _error('durationMinutes'),
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          enabled: enabled,
          ltr: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _passMark,
          label: strings.examPassMarkLabel,
          errorText: _error('passMarkPercent'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          enabled: enabled,
          ltr: true,
        ),
        if (widget.exam != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(strings.examVersionLabel(widget.exam!.version), style: AppTypography.caption),
          Text(strings.examVersionHelp, style: AppTypography.caption),
        ],
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: strings.saveAndContinue,
          busy: _busy,
          onPressed: widget.editable ? () => unawaited(_save()) : null,
        ),
      ],
    );
  }
}
