import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/features/exams/domain/exam_validation.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:meta/meta.dart';

/// Where one imported question stands in the review. Always shown as a word, never by colour alone.
enum ImportStatus {
  /// Valid, and nothing about it needs a person's eyes.
  ready,

  /// Something is missing or doubtful.
  needsAttention,

  /// Left out of the import.
  notImported,
}

/// A question from the document as the instructor is editing it. It is not a [Question] yet: marks may be missing, and
/// nothing becomes part of an exam until the whole review is confirmed.
@immutable
final class ImportDraft {
  /// Creates a draft.
  const ImportDraft({
    required this.id,
    required this.number,
    required this.startLine,
    required this.sourceLines,
    required this.type,
    required this.text,
    required this.options,
    required this.parserIssues,
    this.marks,
    this.modelAnswer = '',
    this.explanation = '',
    this.topic,
    this.difficulty,
    this.acknowledged = false,
    this.excluded = false,
  });

  /// Starts a draft from a parsed question. Option ids are made here and never change.
  factory ImportDraft.fromParsed(ParsedQuestion parsed, {required String Function() newId}) => ImportDraft(
    id: newId(),
    number: parsed.number,
    startLine: parsed.startLine,
    sourceLines: parsed.sourceLines,
    type: parsed.type,
    text: parsed.text,
    options: [
      for (final option in parsed.options)
        QuestionOption(id: newId(), text: option.text, isCorrect: parsed.correctLabels.contains(option.label)),
    ],
    marks: parsed.marks,
    modelAnswer: parsed.modelAnswer ?? '',
    explanation: parsed.explanation ?? '',
    topic: parsed.topic,
    difficulty: parsed.difficulty,
    parserIssues: parsed.issues,
  );

  /// A stable id for the draft (and for the question it becomes).
  final String id;

  /// The number written in the document.
  final int number;

  /// The document line the question starts on.
  final int startLine;

  /// The question exactly as written, line by line.
  final List<SourceLine> sourceLines;

  /// The kind of question.
  final QuestionType type;

  /// The question text.
  final String text;

  /// The options in order.
  final List<QuestionOption> options;

  /// The marks, or null while nobody has entered any. Never defaulted.
  final double? marks;

  /// The model answer (short text only).
  final String modelAnswer;

  /// The explanation.
  final String explanation;

  /// The topic read from the file (a label only).
  final String? topic;

  /// The difficulty read from the file (a label only).
  final String? difficulty;

  /// What the importer noticed.
  final List<ImportIssue> parserIssues;

  /// True once the instructor confirmed they checked the question.
  final bool acknowledged;

  /// True when the instructor chose to leave it out.
  final bool excluded;

  /// A copy with the given changes.
  ImportDraft copyWith({
    QuestionType? type,
    String? text,
    List<QuestionOption>? options,
    ({double? value})? marks,
    String? modelAnswer,
    String? explanation,
    bool? acknowledged,
    bool? excluded,
  }) => ImportDraft(
    id: id,
    number: number,
    startLine: startLine,
    sourceLines: sourceLines,
    type: type ?? this.type,
    text: text ?? this.text,
    options: options ?? this.options,
    marks: marks == null ? this.marks : marks.value,
    modelAnswer: modelAnswer ?? this.modelAnswer,
    explanation: explanation ?? this.explanation,
    topic: topic,
    difficulty: difficulty,
    parserIssues: parserIssues,
    acknowledged: acknowledged ?? this.acknowledged,
    excluded: excluded ?? this.excluded,
  );

  /// The draft as a question, for validation. Missing marks become NaN, which is never valid.
  Question toQuestion({bool review = false}) => Question(
    id: id,
    type: type,
    text: text.trim(),
    marks: marks ?? double.nan,
    options: type.hasOptions ? options : const [],
    modelAnswer: type == QuestionType.shortText && modelAnswer.trim().isNotEmpty ? modelAnswer.trim() : null,
    explanation: explanation.trim().isEmpty ? null : explanation.trim(),
    topic: topic,
    difficulty: difficulty,
    source: QuestionSource.wordImport,
    needsReview: review,
  );
}

/// The rules of the review screen, in one place so the screen and the tests use the same ones.
abstract final class ImportReview {
  /// The issues the importer raised that still stand. A missing or unreadable mark disappears once marks are entered; the
  /// others stay until the instructor confirms they checked the question.
  static List<ImportIssue> standingIssues(ImportDraft draft) => [
    for (final issue in draft.parserIssues)
      if (issue.code.resolvedByEdit ? draft.marks == null : !draft.acknowledged) issue,
  ];

  /// What is wrong with the question itself, by the same rules manual authoring uses.
  static List<QuestionProblem> problems(ImportDraft draft) {
    final raised = standingIssues(draft);
    final marksExplained = raised.any(
      (issue) => issue.code == ImportIssueCode.missingMarks || issue.code == ImportIssueCode.marksUnreadable,
    );
    return [
      for (final problem in ExamValidation.questionStructure(draft.toQuestion()))
        // "No Marks: line" already says it better than "marks must be above 0".
        if (!(problem == QuestionProblem.invalidMarks && marksExplained && draft.marks == null)) problem,
    ];
  }

  /// The status of [draft].
  static ImportStatus statusOf(ImportDraft draft) {
    if (draft.excluded) return ImportStatus.notImported;
    if (ExamValidation.questionStructure(draft.toQuestion()).isNotEmpty) return ImportStatus.needsAttention;
    if (standingIssues(draft).isNotEmpty) return ImportStatus.needsAttention;
    return ImportStatus.ready;
  }

  /// True when the question can be added to the exam: kept, and valid by the manual-authoring rules.
  static bool canBeAdded(ImportDraft draft) =>
      !draft.excluded && ExamValidation.questionStructure(draft.toQuestion()).isEmpty;

  /// Counts for "N found · X ready · Y need attention · Z not imported".
  static ({int found, int ready, int attention, int notImported}) summarize(List<ImportDraft> drafts) {
    var ready = 0;
    var attention = 0;
    var notImported = 0;
    for (final draft in drafts) {
      switch (statusOf(draft)) {
        case ImportStatus.ready:
          ready++;
        case ImportStatus.needsAttention:
          attention++;
        case ImportStatus.notImported:
          notImported++;
      }
    }
    return (found: drafts.length, ready: ready, attention: attention, notImported: notImported);
  }

  /// Why the review cannot be confirmed yet, or null when it can: at least one question must remain, and every one that
  /// remains must be valid.
  static ImportBlock? blockOf(List<ImportDraft> drafts) {
    final kept = drafts.where((draft) => !draft.excluded).toList();
    if (kept.isEmpty) return ImportBlock.nothingKept;
    if (kept.any((draft) => !canBeAdded(draft))) return ImportBlock.invalidQuestions;
    return null;
  }

  /// The questions to add: every kept question, marked for review when the importer still has an unconfirmed doubt.
  static List<Question> build(List<ImportDraft> drafts) => [
    for (final draft in drafts)
      if (canBeAdded(draft)) draft.toQuestion(review: standingIssues(draft).isNotEmpty),
  ];
}

/// Why the review cannot be confirmed.
enum ImportBlock {
  /// Every question was left out.
  nothingKept,

  /// A question that is kept is not valid yet.
  invalidQuestions,
}
