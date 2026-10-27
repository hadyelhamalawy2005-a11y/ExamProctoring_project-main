import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:meta/meta.dart';

/// How one question turned out.
enum QuestionOutcome {
  /// Auto-marked, and right: full marks.
  correct('correct'),

  /// Auto-marked, and wrong: no marks.
  incorrect('incorrect'),

  /// Not answered: no marks.
  unanswered('unanswered'),

  /// A typed answer waiting for the instructor to mark it. It has no marks yet and is never guessed.
  pendingManual('pendingManual'),

  /// A typed answer the instructor has marked.
  markedManually('markedManually');

  const QuestionOutcome(this.wireName);

  /// The stored name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, QuestionOutcome> byWireName = {
    'correct': QuestionOutcome.correct,
    'incorrect': QuestionOutcome.incorrect,
    'unanswered': QuestionOutcome.unanswered,
    'pendingManual': QuestionOutcome.pendingManual,
    'markedManually': QuestionOutcome.markedManually,
  };
}

/// The marks one question earned.
@immutable
final class QuestionResult {
  /// Creates a result.
  const QuestionResult({required this.questionId, required this.outcome, required this.maxMarks, this.marksAwarded});

  /// Reads a result.
  factory QuestionResult.fromJson(JsonReader json) => QuestionResult(
    questionId: json.string('questionId'),
    outcome: json.enumValue('outcome', QuestionOutcome.byWireName),
    maxMarks: json.number('maxMarks'),
    marksAwarded: json.optionalNumber('marksAwarded'),
  );

  /// The question.
  final String questionId;

  /// How it turned out.
  final QuestionOutcome outcome;

  /// What a full answer is worth.
  final double maxMarks;

  /// The marks earned, or null while the question waits for manual marking. Never more than [maxMarks], never negative.
  final double? marksAwarded;

  /// The stored form.
  Map<String, Object?> toJson() => {
    'questionId': questionId,
    'outcome': outcome.wireName,
    'maxMarks': maxMarks,
    'marksAwarded': marksAwarded,
  };
}

/// The marks of a whole attempt.
@immutable
final class AttemptResult {
  /// Creates a result.
  const AttemptResult({required this.questions, required this.totalMarks, this.passMarkPercent});

  /// Reads a result.
  factory AttemptResult.fromJson(JsonReader json) => AttemptResult(
    questions: json.list('questions', QuestionResult.fromJson),
    totalMarks: json.number('totalMarks'),
    passMarkPercent: json.optionalNumber('passMarkPercent'),
  );

  /// One entry per question, in the exam's own order.
  final List<QuestionResult> questions;

  /// What the whole exam is worth.
  final double totalMarks;

  /// The pass mark in percent of [totalMarks], or null when the exam has none.
  final double? passMarkPercent;

  /// The marks earned so far (questions waiting for manual marking count for nothing yet).
  double get awardedMarks => questions.fold(0, (sum, question) => sum + (question.marksAwarded ?? 0));

  /// How many questions still wait for the instructor.
  int get pendingManualCount => questions.where((q) => q.outcome == QuestionOutcome.pendingManual).length;

  /// True when every question has its marks.
  bool get isFinal => pendingManualCount == 0;

  /// [awardedMarks] as a percentage of [totalMarks] (0 for an exam worth nothing).
  double get percentage => totalMarks <= 0 ? 0 : awardedMarks / totalMarks * 100;

  /// Passed or not. Null while marks are pending (it could still change) and when the exam has no pass mark: the app never
  /// says "passed" or "failed" on information it does not have.
  bool? get passed {
    final mark = passMarkPercent;
    if (!isFinal || mark == null) return null;
    return percentage + 1e-9 >= mark;
  }

  /// The stored form.
  Map<String, Object?> toJson() => {
    'questions': [for (final question in questions) question.toJson()],
    'totalMarks': totalMarks,
    'passMarkPercent': passMarkPercent,
  };
}

/// Marks an attempt.
///
/// The inputs are the questions (with their answer key), the answers, and any marks an instructor gave by hand. There is
/// no input for proctoring: a warning, an incident or a flag can never reach this code, so it can never change a mark.
abstract final class Grader {
  /// Marks [answers] against [questions].
  ///
  /// * Single choice: full marks when exactly the correct option was chosen.
  /// * Multiple choice: ALL OR NOTHING. Full marks only when exactly the correct options were chosen; one missing or one
  ///   extra option earns nothing. Partial credit is a course policy, not something this app decides.
  /// * Short text: never marked here. It waits for the instructor; once they mark it, [manualMarks] supplies the marks,
  ///   clamped to what the question offers.
  static AttemptResult grade({
    required List<Question> questions,
    required Map<String, AnswerValue> answers,
    Map<String, double> manualMarks = const {},
    double? passMarkPercent,
  }) {
    final results = <QuestionResult>[];
    for (final question in questions) {
      results.add(_gradeOne(question, answers[question.id], manualMarks[question.id]));
    }
    return AttemptResult(
      questions: results,
      totalMarks: questions.fold<double>(0, (sum, question) => sum + question.marks),
      passMarkPercent: passMarkPercent,
    );
  }

  static QuestionResult _gradeOne(Question question, AnswerValue? answer, double? manual) {
    QuestionResult result(QuestionOutcome outcome, double? marks) =>
        QuestionResult(questionId: question.id, outcome: outcome, maxMarks: question.marks, marksAwarded: marks);

    switch (question.type) {
      case QuestionType.shortText:
        if (manual != null) return result(QuestionOutcome.markedManually, clamp(manual, question.marks));
        // An empty answer is worth nothing and does not need a human to say so.
        if (answer is! TextAnswer || answer.text.trim().isEmpty) return result(QuestionOutcome.unanswered, 0);
        return result(QuestionOutcome.pendingManual, null);
      case QuestionType.singleChoice || QuestionType.multipleChoice:
        if (answer is! ChoiceAnswer || answer.optionIds.isEmpty) return result(QuestionOutcome.unanswered, 0);
        final correct = question.correctOptionIds;
        final exact = answer.optionIds.length == correct.length && answer.optionIds.containsAll(correct);
        return exact ? result(QuestionOutcome.correct, question.marks) : result(QuestionOutcome.incorrect, 0);
    }
  }

  /// [marks] limited to between 0 and [max]. A NaN or infinite value earns nothing.
  static double clamp(double marks, double max) {
    if (marks.isNaN || marks.isInfinite) return 0;
    return marks.clamp(0, max).toDouble();
  }
}
