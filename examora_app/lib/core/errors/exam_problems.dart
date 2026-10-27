import 'package:meta/meta.dart';

/// Why a single question is not valid. A closed set, so every one can be shown in the user's language.
enum QuestionProblem {
  /// The question has no text.
  noText,

  /// The question text is too long.
  textTooLong,

  /// The marks are not a number above 0, at most 9999.99, with at most two decimals.
  invalidMarks,

  /// A choice question has fewer than two options.
  tooFewOptions,

  /// A choice question has more options than allowed.
  tooManyOptions,

  /// An option has no text.
  optionEmpty,

  /// An option's text is too long.
  optionTooLong,

  /// No option is marked correct.
  noCorrectAnswer,

  /// A single-choice question has more than one correct option.
  severalCorrectForSingle,

  /// Two options have the same text.
  duplicateOptionTexts,

  /// A short-text question has options.
  optionsOnShortText,

  /// The model answer is too long.
  modelAnswerTooLong,

  /// The question is flagged for review and the instructor has not confirmed it yet.
  flaggedForReview,

  /// The options changed after the correct answer was set, and the answer has not been confirmed again.
  answerKeyStale,
}

/// One reason an exam cannot be published.
@immutable
sealed class PublishProblem {
  /// Creates a problem.
  const PublishProblem();
}

/// The exam's own details (title, duration, ...) are incomplete or invalid.
final class DetailsIncompleteProblem extends PublishProblem {
  /// Creates the problem for the fields named in [fields].
  const DetailsIncompleteProblem(this.fields);

  /// The offending field names (camelCase).
  final List<String> fields;
}

/// The exam has no questions.
final class NoQuestionsProblem extends PublishProblem {
  /// Creates the problem.
  const NoQuestionsProblem();
}

/// One question is not valid or not confirmed.
final class QuestionPublishProblem extends PublishProblem {
  /// Creates the problem for the question at [position] (1-based).
  const QuestionPublishProblem(this.position, this.problem);

  /// Which question, counting from 1.
  final int position;

  /// What is wrong with it.
  final QuestionProblem problem;
}

/// No availability window has been set.
final class ScheduleMissingProblem extends PublishProblem {
  /// Creates the problem.
  const ScheduleMissingProblem();
}

/// The window is shorter than the exam's duration.
final class WindowTooShortProblem extends PublishProblem {
  /// Creates the problem.
  const WindowTooShortProblem();
}

/// The exam's start time has already passed.
final class StartTimePassedProblem extends PublishProblem {
  /// Creates the problem.
  const StartTimePassedProblem();
}

/// Why a Word file was turned away before any question was read.
enum DocumentRejection {
  /// The file name does not end in .docx.
  notDocx,

  /// An older Word file (.doc), by its name or by what is inside.
  oldDoc,

  /// A PDF, whatever the file is called.
  pdf,

  /// The file is not a zip archive, so it cannot be a .docx.
  notAZip,

  /// A zip archive, but not a Word document (no word/document.xml).
  notWord,

  /// Larger than the 10 MB limit.
  tooLarge,

  /// So many parts, or so much XML, that reading it is refused.
  tooComplex,

  /// The archive or its XML is damaged.
  unreadable,

  /// A valid Word file with no text in it.
  empty,
}
