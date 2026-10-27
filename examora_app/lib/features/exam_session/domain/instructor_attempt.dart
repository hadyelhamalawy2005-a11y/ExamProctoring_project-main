import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:meta/meta.dart';

/// One attempt in an instructor's list for an exam.
@immutable
final class AttemptSummary {
  /// Creates a summary.
  const AttemptSummary({
    required this.attemptId,
    required this.studentName,
    required this.status,
    required this.startedAt,
    required this.incidentCount,
    this.submittedAt,
    this.submissionKind,
    this.result,
  });

  /// The attempt.
  final String attemptId;

  /// The student's name.
  final String studentName;

  /// Whether it is still open.
  final AttemptStatus status;

  /// When it began.
  final DateTime startedAt;

  /// When it was submitted.
  final DateTime? submittedAt;

  /// How it was submitted.
  final SubmissionKind? submissionKind;

  /// The marks so far (null while the attempt is open).
  final AttemptResult? result;

  /// How many incidents were recorded.
  final int incidentCount;
}

/// One question of an attempt, for the instructor reviewing it.
@immutable
final class ReviewedQuestion {
  /// Creates the record.
  const ReviewedQuestion({required this.question, required this.answer, required this.result});

  /// The question with its answer key (the instructor owns the exam).
  final Question question;

  /// The student's answer, if any.
  final AnswerValue? answer;

  /// How it was marked.
  final QuestionResult result;
}

/// An attempt as the owning instructor reviews it.
@immutable
final class AttemptReview {
  /// Creates the review.
  const AttemptReview({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.studentName,
    required this.status,
    required this.questions,
    required this.result,
    required this.incidentCount,
    this.submittedAt,
    this.submissionKind,
  });

  /// The attempt.
  final String attemptId;

  /// The exam.
  final String examId;

  /// The exam's title.
  final String examTitle;

  /// The student.
  final String studentName;

  /// Whether the attempt is still open.
  final AttemptStatus status;

  /// When it was submitted.
  final DateTime? submittedAt;

  /// How it was submitted.
  final SubmissionKind? submissionKind;

  /// Every question with the answer and its marks.
  final List<ReviewedQuestion> questions;

  /// The total marks.
  final AttemptResult result;

  /// How many incidents were recorded.
  final int incidentCount;
}
