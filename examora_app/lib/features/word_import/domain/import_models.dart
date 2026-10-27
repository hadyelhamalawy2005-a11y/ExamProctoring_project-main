import 'package:examora_app/features/exams/domain/question.dart';
import 'package:meta/meta.dart';

/// One non-empty line of the document, with its 1-based position among the document's non-empty lines.
@immutable
final class SourceLine {
  /// Creates a line.
  const SourceLine(this.number, this.text);

  /// Position among the non-empty lines, starting at 1.
  final int number;

  /// The text exactly as written (with tabs kept, direction marks removed).
  final String text;

  @override
  bool operator ==(Object other) => other is SourceLine && other.number == number && other.text == text;

  @override
  int get hashCode => Object.hash(number, text);
}

/// Content in the document that cannot be imported. It is reported, never dropped quietly.
enum SkippedKind {
  /// A picture or drawing.
  image,

  /// A table.
  table,

  /// A mathematical equation.
  equation,
}

/// One piece of content that could not be imported, and where it was.
@immutable
final class SkippedContent {
  /// Creates the record.
  const SkippedContent({required this.kind, required this.afterLine, this.preview = ''});

  /// What it was.
  final SkippedKind kind;

  /// The number of the last line before it (0 when it came first).
  final int afterLine;

  /// A few words of what was inside, when there were any (a table's first cell, for example).
  final String preview;
}

/// The readable content of a Word document.
@immutable
final class ExtractedDocument {
  /// Creates the document.
  const ExtractedDocument({required this.lines, required this.skipped});

  /// Every non-empty line in reading order.
  final List<SourceLine> lines;

  /// Everything that could not be turned into text.
  final List<SkippedContent> skipped;
}

/// Why a question read from a document needs a person to look at it.
enum ImportIssueCode {
  /// The document did not say what kind of question it is, so the importer guessed from its shape.
  typeInferred(resolvedByEdit: false),

  /// A `[tag]` after the question number is not a type the importer knows.
  unknownTypeTag(resolvedByEdit: false),

  /// A line inside the question matched nothing (not a text, an option, an answer or a marks line).
  strayText(resolvedByEdit: false),

  /// The correct-answer line names an option the question does not have.
  unknownAnswerLabel(resolvedByEdit: false),

  /// A single-choice question names more than one correct option.
  severalAnswersForSingle(resolvedByEdit: false),

  /// The question has more than one correct-answer line, and they disagree.
  conflictingAnswerLines(resolvedByEdit: false),

  /// A "Correct Answer" line on a question without options was kept as the model answer.
  answerTreatedAsModel(resolvedByEdit: false),

  /// Two options carry the same letter.
  duplicateOptionLabel(resolvedByEdit: false),

  /// The same question number appears twice in the document.
  duplicateQuestionNumber(resolvedByEdit: false),

  /// There is no `Marks:` line. The importer never picks a number for you.
  missingMarks(resolvedByEdit: true),

  /// The `Marks:` line could not be read as a number.
  marksUnreadable(resolvedByEdit: true);

  const ImportIssueCode({required this.resolvedByEdit});

  /// True when entering a valid value in the review screen settles the issue, so it disappears. The others stay until the
  /// instructor confirms that they checked the question.
  final bool resolvedByEdit;
}

/// One thing wrong with one question read from a document.
@immutable
final class ImportIssue {
  /// Creates an issue.
  const ImportIssue(this.code, {this.detail, this.line});

  /// What it is.
  final ImportIssueCode code;

  /// The text it is about (a letter, a tag, a stray line), as written in the document.
  final String? detail;

  /// The document line it came from, when there is one.
  final int? line;
}

/// An option as read from the document.
@immutable
final class ParsedOption {
  /// Creates an option.
  const ParsedOption({required this.label, required this.text});

  /// The letter as written, upper-cased and mapped to Latin (A, B, C, ...).
  final String label;

  /// The option's text.
  final String text;
}

/// One question as read from the document, before the instructor has looked at it.
@immutable
final class ParsedQuestion {
  /// Creates a parsed question.
  const ParsedQuestion({
    required this.number,
    required this.startLine,
    required this.sourceLines,
    required this.type,
    required this.text,
    required this.options,
    required this.correctLabels,
    required this.issues,
    this.marks,
    this.modelAnswer,
    this.explanation,
    this.topic,
    this.difficulty,
  });

  /// The number written in the document (or the running count when there was none).
  final int number;

  /// The line the question starts on.
  final int startLine;

  /// Every line that belongs to the question, exactly as written.
  final List<SourceLine> sourceLines;

  /// The kind of question.
  final QuestionType type;

  /// The question text.
  final String text;

  /// The options in order.
  final List<ParsedOption> options;

  /// The letters named as correct (empty when none was named).
  final Set<String> correctLabels;

  /// The marks, or null when the document gave none (or an unreadable one). Never defaulted.
  final double? marks;

  /// The model answer, when there was one.
  final String? modelAnswer;

  /// The explanation, when there was one.
  final String? explanation;

  /// The topic, when there was one.
  final String? topic;

  /// The difficulty, when there was one.
  final String? difficulty;

  /// What needs a person's attention.
  final List<ImportIssue> issues;
}

/// Everything read from a document.
@immutable
final class ImportPreview {
  /// Creates the preview.
  const ImportPreview({
    required this.questions,
    required this.unattached,
    required this.ignored,
    required this.skipped,
    this.documentTitle,
  });

  /// The questions in document order.
  final List<ParsedQuestion> questions;

  /// Lines that belong to no question (before the first, between questions). Reported so nothing vanishes.
  final List<SourceLine> unattached;

  /// Lines the importer understood but does not use (the document title, section headings).
  final List<SourceLine> ignored;

  /// Content that could not be imported.
  final List<SkippedContent> skipped;

  /// The exam title written in the document, if any. Not used: the exam already has its own.
  final String? documentTitle;
}
