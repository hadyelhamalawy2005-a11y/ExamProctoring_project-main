import 'dart:async';

import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Step 4: when the exam opens and closes. Nothing is pre-filled: a time nobody chose is a time nobody agreed to.
class ScheduleStep extends ConsumerStatefulWidget {
  /// Creates the step.
  const ScheduleStep({required this.exam, required this.editable, required this.onSaved, super.key});

  /// The exam being edited.
  final Exam exam;

  /// False when the exam can no longer be changed.
  final bool editable;

  /// Called with the exam as saved.
  final ValueChanged<Exam> onSaved;

  @override
  ConsumerState<ScheduleStep> createState() => _ScheduleStepState();
}

class _ScheduleStepState extends ConsumerState<ScheduleStep> {
  late DateTime? _opens = widget.exam.opensAt;
  late DateTime? _closes = widget.exam.closesAt;
  bool _busy = false;
  AppFailure? _failure;
  Map<String, FieldProblem> _fields = {};

  Future<DateTime?> _pick(DateTime? current) async {
    final now = ref.read(clockProvider).now().toLocal();
    final initial = (current ?? now.add(const Duration(days: 1))).toLocal();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute).toUtc();
  }

  Future<void> _save() async {
    if (_busy) return;
    final opens = _opens;
    final closes = _closes;
    if (opens == null || closes == null) {
      setState(() {
        _failure = null;
        _fields = {
          if (opens == null) 'opensAt': const KnownFieldProblem(FieldReason.required),
          if (closes == null) 'closesAt': const KnownFieldProblem(FieldReason.required),
        };
      });
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
      _fields = {};
    });
    final result = await ref
        .read(examRepositoryProvider)
        .updateSchedule(widget.exam.id, opensAt: opens, closesAt: closes);
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

  Widget _row({
    required String label,
    required DateTime? value,
    required String field,
    required ValueChanged<DateTime> onPicked,
  }) {
    final strings = context.strings;
    final problem = _fields[field];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption),
          Text(
            value == null ? strings.scheduleNotSet : DateFormatting.dateTime(context, value),
            style: AppTypography.heading,
          ),
          if (problem != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                strings.fieldProblemMessage(problem),
                style: AppTypography.caption.copyWith(color: AppColors.danger),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: strings.scheduleChoose,
            icon: Icons.event_outlined,
            variant: AppButtonVariant.secondary,
            expand: false,
            onPressed: widget.editable && !_busy
                ? () async {
                    final picked = await _pick(value);
                    if (picked != null && mounted) onPicked(picked);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final failure = _failure;
    final anchor = _opens ?? _closes ?? ref.read(clockProvider).now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.scheduleHelp, style: AppTypography.body),
        const SizedBox(height: AppSpacing.md),
        if (failure != null) ...[
          AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
          const SizedBox(height: AppSpacing.lg),
        ],
        _row(
          label: strings.scheduleOpensLabel,
          value: _opens,
          field: 'opensAt',
          onPicked: (value) => setState(() => _opens = value),
        ),
        const SizedBox(height: AppSpacing.md),
        _row(
          label: strings.scheduleClosesLabel,
          value: _closes,
          field: 'closesAt',
          onPicked: (value) => setState(() => _closes = value),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(strings.timeZoneNote(DateFormatting.zone(anchor)), style: AppTypography.caption),
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
