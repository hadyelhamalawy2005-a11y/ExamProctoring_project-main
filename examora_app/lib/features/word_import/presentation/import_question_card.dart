import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/utilities/number_parsing.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:examora_app/features/word_import/domain/import_review.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// One question from the document, editable. Every change is handed to [onChanged] at once, so the status word and the
/// summary above always describe what is on screen.
class ImportQuestionCard extends StatefulWidget {
  /// Creates the card.
  const ImportQuestionCard({required this.draft, required this.onChanged, super.key});

  /// The question as it stands.
  final ImportDraft draft;

  /// Called with the changed draft.
  final ValueChanged<ImportDraft> onChanged;

  @override
  State<ImportQuestionCard> createState() => _ImportQuestionCardState();
}

class _OptionField {
  _OptionField(this.id, String text) : controller = TextEditingController(text: text);

  final String id;
  final TextEditingController controller;
}

class _ImportQuestionCardState extends State<ImportQuestionCard> {
  static const Uuid _uuid = Uuid();

  late final _text = TextEditingController(text: widget.draft.text);
  late final _marks = TextEditingController(text: widget.draft.marks == null ? '' : formatNumber(widget.draft.marks!));
  late final _model = TextEditingController(text: widget.draft.modelAnswer);
  late final _explanation = TextEditingController(text: widget.draft.explanation);
  late final List<_OptionField> _options = [for (final o in widget.draft.options) _OptionField(o.id, o.text)];
  final List<TextEditingController> _retired = [];

  ImportDraft get _draft => widget.draft;

  @override
  void dispose() {
    _text.dispose();
    _marks.dispose();
    _model.dispose();
    _explanation.dispose();
    for (final option in _options) {
      option.controller.dispose();
    }
    for (final controller in _retired) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit({QuestionType? type, List<QuestionOption>? options, bool? acknowledged, bool? excluded}) {
    final marksText = _marks.text.trim();
    final marks = marksText.isEmpty ? null : NumberParsing.parseDecimal(marksText);
    // Option texts live in the fields; which options are correct lives in the draft (or in [options], when it changed).
    final flags = {for (final o in options ?? _draft.options) o.id: o.isCorrect};
    widget.onChanged(
      _draft.copyWith(
        type: type,
        text: _text.text,
        options: [
          for (final field in _options)
            QuestionOption(id: field.id, text: field.controller.text, isCorrect: flags[field.id] ?? false),
        ],
        marks: (value: marks),
        modelAnswer: _model.text,
        explanation: _explanation.text,
        acknowledged: acknowledged,
        excluded: excluded,
      ),
    );
  }

  void _toggleCorrect(int index) {
    final single = _draft.type == QuestionType.singleChoice;
    final options = [
      for (var i = 0; i < _draft.options.length; i++)
        _draft.options[i].copyWith(
          isCorrect: single ? i == index : (i == index ? !_draft.options[i].isCorrect : _draft.options[i].isCorrect),
        ),
    ];
    _emit(options: options);
  }

  void _setType(QuestionType type) {
    var options = _draft.options;
    if (type == QuestionType.singleChoice) {
      var seen = false;
      options = [
        for (final o in options)
          () {
            final keep = o.isCorrect && !seen;
            seen = seen || o.isCorrect;
            return o.copyWith(isCorrect: keep);
          }(),
      ];
    }
    // Choosing a type is confirming it.
    _emit(type: type, options: options, acknowledged: _draft.acknowledged);
  }

  void _addOption() {
    final field = _OptionField(_uuid.v4(), '');
    setState(() => _options.add(field));
    _emit(
      options: [
        ..._draft.options,
        QuestionOption(id: field.id, text: '', isCorrect: false),
      ],
    );
  }

  void _removeOption(int index) {
    final removed = _options[index];
    setState(() {
      _options.removeAt(index);
      // Disposed with the card, not now: the field is still on screen for this frame.
      _retired.add(removed.controller);
    });
    _emit(
      options: [
        for (final o in _draft.options)
          if (o.id != removed.id) o,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final draft = _draft;
    final status = ImportReview.statusOf(draft);
    final standing = ImportReview.standingIssues(draft);
    final problems = ImportReview.problems(draft);
    final needsAcknowledgement = standing.any((issue) => !issue.code.resolvedByEdit) && !draft.acknowledged;

    final tone = switch (status) {
      ImportStatus.ready => StatusTone.success,
      ImportStatus.needsAttention => StatusTone.warning,
      ImportStatus.notImported => StatusTone.info,
    };

    return AppCard(
      key: ValueKey('import-card-${draft.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(strings.importQuestionHeading(draft.number, draft.startLine), style: AppTypography.heading),
              StatusBadge(label: strings.importStatusName(status), tone: tone),
              if (draft.acknowledged) StatusBadge(label: strings.importAcknowledged, tone: StatusTone.info),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (draft.excluded) ...[
            Text(
              strings.isolate(draft.text),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: strings.importDoImport,
              variant: AppButtonVariant.secondary,
              onPressed: () => _emit(excluded: false),
            ),
          ] else ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final type in QuestionType.values)
                  ChoiceChip(
                    label: Text(strings.questionTypeName(type)),
                    selected: draft.type == type,
                    onSelected: (_) => _setType(type),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _text,
              label: strings.questionTextLabel,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _marks,
              label: strings.marksFieldLabel,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _emit(),
              ltr: true,
            ),
            if (draft.type.hasOptions) ...[
              const SizedBox(height: AppSpacing.md),
              for (var index = 0; index < _options.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        selected: draft.options[index].isCorrect,
                        label: '${strings.markCorrect}: ${strings.optionLabel(index + 1)}',
                        child: IconButton(
                          tooltip: strings.markCorrect,
                          icon: Icon(
                            draft.options[index].isCorrect
                                ? (draft.type == QuestionType.singleChoice
                                      ? Icons.radio_button_checked
                                      : Icons.check_box)
                                : (draft.type == QuestionType.singleChoice
                                      ? Icons.radio_button_unchecked
                                      : Icons.check_box_outline_blank),
                            color: draft.options[index].isCorrect ? AppColors.success : AppColors.textMuted,
                          ),
                          onPressed: () => _toggleCorrect(index),
                        ),
                      ),
                      Expanded(
                        child: AppTextField(
                          controller: _options[index].controller,
                          label: strings.optionLabel(index + 1),
                          onChanged: (_) => _emit(),
                        ),
                      ),
                      IconButton(
                        tooltip: strings.removeOption,
                        icon: const Icon(Icons.close),
                        onPressed: _options.length > 1 ? () => _removeOption(index) : null,
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _options.length < ExamLimits.optionsMax ? _addOption : null,
                  icon: const Icon(Icons.add),
                  label: Text(strings.addOption),
                ),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _model, label: strings.modelAnswerLabel, maxLines: 3, onChanged: (_) => _emit()),
            ],
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _explanation,
              label: strings.explanationLabel,
              maxLines: 2,
              onChanged: (_) => _emit(),
            ),
            if (draft.topic != null || draft.difficulty != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (draft.topic != null)
                    StatusBadge(
                      label: '${strings.topicLabel}: ${strings.isolate(draft.topic!)}',
                      tone: StatusTone.info,
                    ),
                  if (draft.difficulty != null)
                    StatusBadge(
                      label: '${strings.difficultyLabel}: ${strings.isolate(draft.difficulty!)}',
                      tone: StatusTone.info,
                    ),
                ],
              ),
              Text(strings.importReadOnlyNote, style: AppTypography.caption),
            ],
            const SizedBox(height: AppSpacing.md),
            if (standing.isEmpty && problems.isEmpty)
              Text(strings.importNoProblems, style: AppTypography.caption)
            else ...[
              for (final issue in standing) ...[
                AppBanner(message: strings.importIssueMessage(issue), tone: StatusTone.warning),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (final problem in problems) ...[
                AppBanner(message: strings.questionProblemMessage(problem), tone: StatusTone.danger),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
            if (needsAcknowledgement) ...[
              AppButton(
                label: strings.importAcknowledge,
                variant: AppButtonVariant.secondary,
                onPressed: () => _emit(acknowledged: true),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: strings.importDontImport,
              variant: AppButtonVariant.secondary,
              onPressed: () => _emit(excluded: true),
            ),
          ],
          // What the file really said, so an edit can always be told apart from the original.
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(strings.importAsWritten),
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in draft.sourceLines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: SelectableText(
                          strings.importLine(line.number, line.text),
                          style: AppTypography.caption.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
