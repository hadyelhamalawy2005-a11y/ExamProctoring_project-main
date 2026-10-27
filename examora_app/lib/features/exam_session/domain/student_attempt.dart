import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:meta/meta.dart';

/// The rules of proctoring for one attempt, as the player needs them.
@immutable
final class ProctoringPlan {
  /// Creates the plan.
  const ProctoringPlan({
    required this.activeRules,
    required this.sustainedThresholdSeconds,
    required this.evidenceBufferSeconds,
    required this.maxWarnings,
  });

  /// The rules that really run (the ones that need an AI detector are never in here).
  final Set<IncidentCategory> activeRules;

  /// Seconds a sustained behaviour must last.
  final int sustainedThresholdSeconds;

  /// Seconds of evidence the instructor asked for (the app reports it as unavailable).
  final int evidenceBufferSeconds;

  /// Warnings after which the attempt is flagged.
  final int maxWarnings;
}

/// An attempt as its own student sees it: the questions in this student's order, their answers, and the deadline. There is no
/// field for a correct option, a model answer or an explanation, so nothing in this type can leak an answer key.
@immutable
final class StudentAttemptSession {
  /// Creates the session.
  const StudentAttemptSession({
    required this.attemptId,
    required this.examId,
    required this.title,
    required this.instructions,
    required this.startedAt,
    required this.deadline,
    required this.lastSeenAt,
    required this.status,
    required this.currentIndex,
    required this.questions,
    required this.answers,
    required this.calculatorEnabled,
    required this.allowBackwardNavigation,
    required this.plan,
  });

  /// The attempt's id.
  final String attemptId;

  /// The exam's id.
  final String examId;

  /// The exam's title.
  final String title;

  /// The instructions.
  final String instructions;

  /// When the student began.
  final DateTime startedAt;

  /// When the attempt ends (never moves).
  final DateTime deadline;

  /// The latest moment the clock was ever seen at during this attempt.
  final DateTime lastSeenAt;

  /// Whether the attempt is still open.
  final AttemptStatus status;

  /// The question the student was on.
  final int currentIndex;

  /// The questions in this student's order.
  final List<StudentQuestion> questions;

  /// The answers saved so far.
  final Map<String, AnswerValue> answers;

  /// Whether the calculator is offered.
  final bool calculatorEnabled;

  /// Whether earlier questions can be revisited.
  final bool allowBackwardNavigation;

  /// How this attempt is watched.
  final ProctoringPlan plan;

  /// How many questions have an answer.
  int get answeredCount => questions.where((q) => isAnswered(q.id)).length;

  /// Whether the question has a real answer.
  bool isAnswered(String questionId) {
    final answer = answers[questionId];
    return switch (answer) {
      ChoiceAnswer(:final optionIds) => optionIds.isNotEmpty,
      TextAnswer(:final text) => text.trim().isNotEmpty,
      null => false,
    };
  }
}

/// A student's result for one attempt.
@immutable
final class StudentResult {
  /// Creates a result.
  const StudentResult({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.submittedAt,
    required this.submissionKind,
    required this.visible,
    this.releaseAt,
    this.result,
    this.questionTexts = const {},
    this.explanations = const {},
  });

  /// The attempt.
  final String attemptId;

  /// The exam.
  final String examId;

  /// The exam's title.
  final String examTitle;

  /// When it was submitted.
  final DateTime submittedAt;

  /// How it was submitted.
  final SubmissionKind submissionKind;

  /// Whether the marks may be shown now: the exam shows results immediately, or its window has closed.
  final bool visible;

  /// When the marks will be shown, when they are not visible yet.
  final DateTime? releaseAt;

  /// The marks. Null while [visible] is false: a held-back result is not sent to the screen at all.
  final AttemptResult? result;

  /// The question texts by id, so the result can name what each mark is for. Empty while not visible.
  final Map<String, String> questionTexts;

  /// Explanations by question id, present only when the exam shows explanations and the result is visible.
  final Map<String, String> explanations;
}
