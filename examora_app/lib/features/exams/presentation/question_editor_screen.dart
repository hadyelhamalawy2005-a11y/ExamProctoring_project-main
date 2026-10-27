import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/number_parsing.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/exam_validation.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Opens the question editor on top of the wizard. Completes with true when a question was saved.
Future<bool?> openQuestionEditor(BuildContext context, {required String examId, Question? question}) =>
    Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => QuestionEditorScreen(examId: examId, question: question),
      ),
    );

class _OptionDraft {
  _OptionDraft({required this.id, String text = '', this.correct = false})
    : controller = TextEditingController(text: text);

  final String id;
  final TextEditingController controller;
  bool correct;
}

/// Writes or edits one question. Saving from here is the instructor looking at the correct answer, so it confirms the
/// answer key; a question that is flagged for review or whose key is stale must be confirmed with an explicit tick first.
class QuestionEditorScreen extends ConsumerStatefulWidget {
  /// Creates the editor for a new question, or for [question].
  const QuestionEditorScreen({required this.examId, this.question, super.key});

  /// The exam the question belongs to.
  final String examId;

  /// The question being edited, or null for a new one.
  final Question? question;

  @override
  ConsumerState<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends ConsumerState<QuestionEditorScreen> {
  static const Uuid _uuid = Uuid();

  late final String _id = widget.question?.id ?? _uuid.v4();
  late QuestionType _type = widget.question?.type ?? QuestionType.singleChoice;
  late final _text = TextEditingController(text: widget.question?.text);
  late final _marks = TextEditingController(text: widget.question == null ? '' : formatNumber(widget.question!.marks));
  late final _modelAnswer = TextEditingController(text: widget.question?.modelAnswer);
  late final _explanation = TextEditingController(text: widget.question?.explanation);
  late final List<_OptionDraft> _options = widget.question != null && widget.question!.options.isNotEmpty
      ? [for (final o in widget.question!.options) _OptionDraft(id: o.id, text: o.text, correct: o.isCorrect)]
      : [_OptionDraft(id: _uuid.v4()), _OptionDraft(id: _uuid.v4())];
  bool _confirmed = false;
  bool _busy = false;
  AppFailure? _failure;
  List<QuestionProblem> _problems = const [];
  bool _confirmMissing = false;
  final List<TextEditingController> _retired = [];

  bool get _needsExplicitConfirmation =>
      widget.question != null && (widget.question!.needsReview || widget.question!.answerKeyStale);

  @override
  void dispose() {
    _text.dispose();
    _marks.dispose();
    _modelAnswer.dispose();
    _explanation.dispose();
    for (final option in _options) {
      option.controller.dispose();
    }
    for (final controller in _retired) {
      controller.dispose();
    }
    super.dispose();
  }

  void _setType(QuestionType type) {
    setState(() {
      _type = type;
      if (type == QuestionType.singleChoice) {
        // Only one option can stay correct.
        var seen = false;
        for (final option in _options) {
          if (option.correct && seen) option.correct = false;
          seen = seen || option.correct;
        }
      }
    });
  }

  void _toggleCorrect(_OptionDraft option) {
    setState(() {
      if (_type == QuestionType.singleChoice) {
        for (final other in _options) {
          other.correct = identical(other, option);
        }
      } else {
        option.correct = !option.correct;
      }
    });
  }

  Question _build() => Question(
    id: _id,
    type: _type,
    text: _text.text,
    marks: NumberParsing.parseDecimal(_marks.text) ?? double.nan,
    options: _type.hasOptions
        ? [for (final o in _options) QuestionOption(id: o.id, text: o.controller.text, isCorrect: o.correct)]
        : const [],
    modelAnswer: _type == QuestionType.shortText ? _modelAnswer.text : null,
    explanation: _explanation.text,
    source: widget.question?.source ?? QuestionSource.manual,
  );

  Future<void> _save() async {
    if (_busy) return;
    final question = _build();
    final problems = ExamValidation.questionStructure(question);
    final missingConfirm = _needsExplicitConfirmation && !_confirmed;
    if (problems.isNotEmpty || missingConfirm) {
      setState(() {
        _failure = null;
        _problems = problems;
        _confirmMissing = missingConfirm;
      });
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
      _problems = const [];
      _confirmMissing = false;
    });
    // Saving here is the instructor looking at the answer: it clears the review flag and confirms the answer key.
    final result = await ref
        .read(examRepositoryProvider)
        .saveQuestion(widget.examId, question.copyWith(needsReview: false), confirmsAnswerKey: true);
    if (!mounted) return;
    switch (result) {
      case Ok<Exam>():
        Navigator.of(context).pop(true);
      case Err<Exam>(:final failure):
        setState(() {
          _busy = false;
          if (failure is QuestionInvalidFailure) {
            _problems = failure.problems;
          } else {
            _failure = failure;
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final failure = _failure;
    final enabled = !_busy;
    final isNew = widget.question == null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(isNew ? strings.newQuestionTitle : strings.editQuestionTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (failure != null) ...[
                  AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (_problems.isNotEmpty) ...[
                  for (final problem in _problems) ...[
                    AppBanner(message: strings.questionProblemMessage(problem), tone: StatusTone.danger),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
                Text(strings.questionTypeLabel, style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                // Three long labels do not fit on one line on a phone, so the choices wrap.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final type in QuestionType.values)
                      ChoiceChip(
                        label: Text(strings.questionTypeName(type)),
                        selected: _type == type,
                        onSelected: enabled ? (_) => _setType(type) : null,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(strings.questionTypeHint(_type), style: AppTypography.caption),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(controller: _text, label: strings.questionTextLabel, maxLines: 5, enabled: enabled),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _marks,
                  label: strings.marksFieldLabel,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  enabled: enabled,
                  ltr: true,
                ),
                if (_type.hasOptions) ...[
                  const SizedBox(height: AppSpacing.lg),
                  for (var index = 0; index < _options.length; index++) _optionRow(index, enabled),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: enabled && _options.length < ExamLimits.optionsMax
                          ? () => setState(() => _options.add(_OptionDraft(id: _uuid.v4())))
                          : null,
                      icon: const Icon(Icons.add),
                      label: Text(strings.addOption),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _modelAnswer,
                    label: strings.modelAnswerLabel,
                    maxLines: 4,
                    enabled: enabled,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppTextField(controller: _explanation, label: strings.explanationLabel, maxLines: 3, enabled: enabled),
                if (_needsExplicitConfirmation) ...[
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(strings.confirmAnswerKey),
                    subtitle: _confirmMissing
                        ? Text(strings.fieldRequired, style: const TextStyle(color: AppColors.danger))
                        : null,
                    value: _confirmed,
                    onChanged: enabled ? (value) => setState(() => _confirmed = value ?? false) : null,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: strings.saveQuestion, busy: _busy, onPressed: () => unawaited(_save())),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionRow(int index, bool enabled) {
    final strings = context.strings;
    final option = _options[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            selected: option.correct,
            label: '${strings.markCorrect}: ${strings.optionLabel(index + 1)}',
            child: IconButton(
              tooltip: strings.markCorrect,
              icon: Icon(
                option.correct
                    ? (_type == QuestionType.singleChoice ? Icons.radio_button_checked : Icons.check_box)
                    : (_type == QuestionType.singleChoice
                          ? Icons.radio_button_unchecked
                          : Icons.check_box_outline_blank),
                color: option.correct ? AppColors.success : AppColors.textMuted,
              ),
              onPressed: enabled ? () => _toggleCorrect(option) : null,
            ),
          ),
          Expanded(
            child: AppTextField(controller: option.controller, label: strings.optionLabel(index + 1), enabled: enabled),
          ),
          IconButton(
            tooltip: strings.removeOption,
            icon: const Icon(Icons.close),
            onPressed: enabled && _options.length > 1
                ? () => setState(() {
                    // Disposed with the screen, not now: the field is still on screen for this frame.
                    _retired.add(_options.removeAt(index).controller);
                  })
                : null,
          ),
        ],
      ),
    );
  }
}
