import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/number_parsing.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_section_header.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/exam_validation.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Step 3: how the exam behaves, and which proctoring rules watch it.
///
/// Rules that need a face, gaze or speech model are listed but switched off and cannot be switched on: this build has no
/// such detector, and a rule that cannot fire must never look like one that does.
class SettingsStep extends ConsumerStatefulWidget {
  /// Creates the step.
  const SettingsStep({required this.exam, required this.editable, required this.onSaved, super.key});

  /// The exam being edited.
  final Exam exam;

  /// False when the exam can no longer be changed.
  final bool editable;

  /// Called with the exam as saved.
  final ValueChanged<Exam> onSaved;

  @override
  ConsumerState<SettingsStep> createState() => _SettingsStepState();
}

class _SettingsStepState extends ConsumerState<SettingsStep> {
  late ExamSettings _settings = widget.exam.settings;
  late final _threshold = TextEditingController(text: _settings.sustainedThresholdSeconds.toString());
  late final _buffer = TextEditingController(text: _settings.evidenceBufferSeconds.toString());
  late final _warnings = TextEditingController(text: _settings.maxWarnings.toString());
  bool _busy = false;
  AppFailure? _failure;
  Map<String, FieldProblem> _fields = {};

  @override
  void dispose() {
    _threshold.dispose();
    _buffer.dispose();
    _warnings.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final threshold = NumberParsing.parseInt(_threshold.text);
    final buffer = NumberParsing.parseInt(_buffer.text);
    final warnings = NumberParsing.parseInt(_warnings.text);
    final candidate = _settings.copyWith(
      sustainedThresholdSeconds: threshold ?? -1,
      evidenceBufferSeconds: buffer ?? -1,
      maxWarnings: warnings ?? -1,
    );
    final problems = ExamValidation.settings(candidate);
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
    final result = await ref.read(examRepositoryProvider).updateSettings(widget.exam.id, candidate);
    if (!mounted) return;
    switch (result) {
      case Ok<Exam>(:final value):
        setState(() => _busy = false);
        widget.onSaved(value);
      case Err<Exam>(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  String? _error(String field) {
    final problem = _fields[field];
    return problem == null ? null : context.strings.fieldProblemMessage(problem);
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    value: value,
    onChanged: widget.editable && !_busy ? onChanged : null,
  );

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
        _switch(
          strings.settingRandomizeQuestions,
          _settings.randomizeQuestions,
          (value) => setState(() => _settings = _settings.copyWith(randomizeQuestions: value)),
        ),
        _switch(
          strings.settingRandomizeOptions,
          _settings.randomizeOptions,
          (value) => setState(() => _settings = _settings.copyWith(randomizeOptions: value)),
        ),
        _switch(
          strings.settingCalculator,
          _settings.calculatorEnabled,
          (value) => setState(() => _settings = _settings.copyWith(calculatorEnabled: value)),
        ),
        _switch(
          strings.settingBackward,
          _settings.allowBackwardNavigation,
          (value) => setState(() => _settings = _settings.copyWith(allowBackwardNavigation: value)),
        ),
        _switch(
          strings.settingShowResult,
          _settings.showResultImmediately,
          (value) => setState(() => _settings = _settings.copyWith(showResultImmediately: value)),
        ),
        _switch(
          strings.settingShowExplanations,
          _settings.showExplanations,
          (value) => setState(() => _settings = _settings.copyWith(showExplanations: value)),
        ),
        AppSectionHeader(strings.proctoringRulesHeading),
        for (final category in IncidentCategory.values) _rule(category),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _threshold,
          label: strings.settingThreshold,
          helperText: strings.settingThresholdHelp,
          errorText: _error('sustainedThresholdSeconds'),
          keyboardType: TextInputType.number,
          enabled: enabled,
          ltr: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _buffer,
          label: strings.settingBuffer,
          helperText: strings.settingBufferHelp,
          errorText: _error('evidenceBufferSeconds'),
          keyboardType: TextInputType.number,
          enabled: enabled,
          ltr: true,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppTextField(
          controller: _warnings,
          label: strings.settingMaxWarnings,
          helperText: strings.settingMaxWarningsHelp,
          errorText: _error('maxWarnings'),
          keyboardType: TextInputType.number,
          enabled: enabled,
          ltr: true,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: strings.saveAndContinue,
          busy: _busy,
          onPressed: widget.editable ? () => unawaited(_save()) : null,
        ),
      ],
    );
  }

  Widget _rule(IncidentCategory category) {
    final text = context.strings;
    final inactive = !category.hasDetector;
    final on = !inactive && _settings.enabledRules.contains(category);
    final hint = inactive
        ? (category.needsAiDetector ? text.ruleInactiveNoDetector : text.ruleInactiveNotDetectable)
        : category.immediate
        ? text.ruleImmediateHint
        : text.ruleSustainedHint;
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(text.incidentCategoryName(category)),
      subtitle: Text(hint),
      value: on,
      // An AI-only rule cannot be switched on: nothing in this build could ever trigger it.
      onChanged: widget.editable && !_busy && !inactive
          ? (value) => setState(() {
              final rules = {..._settings.enabledRules};
              if (value ?? false) {
                rules.add(category);
              } else {
                rules.remove(category);
              }
              _settings = _settings.copyWith(enabledRules: rules);
            })
          : null,
    );
  }
}
