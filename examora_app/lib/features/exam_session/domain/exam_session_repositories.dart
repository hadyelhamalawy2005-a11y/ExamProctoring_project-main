import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/instructor_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';

/// The exams a student can see. Only published exams appear, and only in the student's own types, which carry no answer
/// key.
abstract interface class StudentExamRepository {
  /// Published exams that are scheduled, open or finished, newest window first, with the student's own attempt state.
  Future<Result<List<StudentExamSummary>>> listExams();

  /// One exam's briefing. A draft or archived exam is "not found" to a student.
  Future<Result<StudentExamInfo>> getExam(String examId);
}

/// A student's attempts. Every call acts for the signed-in student and only ever touches that student's own attempts:
/// someone else's attempt is "not found", exactly as if it did not exist.
abstract interface class AttemptRepository {
  /// Records that the student read and accepted the proctoring notice for [examId]. Required before an attempt starts.
  Future<Result<void>> recordConsent(String examId);

  /// Whether consent was recorded for [examId].
  Future<Result<bool>> hasConsent(String examId);

  /// Starts the attempt, or resumes the one already under way: a resumed attempt keeps its answers and its ORIGINAL
  /// deadline. Refused before the window opens, after it closes, without consent, and once the student has submitted.
  Future<Result<StudentAttemptSession>> startAttempt(String examId);

  /// Reloads an attempt.
  Future<Result<StudentAttemptSession>> getSession(String attemptId);

  /// Saves the answer to a question at once. A null [answer] clears it. Refused after the deadline.
  Future<Result<void>> saveAnswer(String attemptId, String questionId, AnswerValue? answer);

  /// Remembers which question the student is on, so resuming returns there. Also advances the attempt's clock floor.
  Future<Result<void>> saveProgress(String attemptId, int questionIndex);

  /// Submits. [auto] says the deadline did it. Submitting again, in any way, returns the original result unchanged: nothing
  /// is graded twice.
  Future<Result<StudentResult>> submit(String attemptId, {bool auto = false});

  /// The result of a submitted attempt of this student.
  Future<Result<StudentResult>> getResult(String attemptId);

  /// This student's submitted attempts, newest first.
  Future<Result<List<StudentResult>>> listResults();
}

/// An instructor's view of the attempts at their own exams.
abstract interface class InstructorAttemptRepository {
  /// The attempts at [examId], newest first. Only the owning instructor may ask.
  Future<Result<List<AttemptSummary>>> listForExam(String examId);

  /// One attempt with every answer and mark. Only the instructor who owns the exam may open it.
  Future<Result<AttemptReview>> getReview(String attemptId);

  /// Gives marks to a typed answer. The marks are limited to between 0 and what the question offers.
  Future<Result<AttemptReview>> markShortAnswer(String attemptId, String questionId, double marks);
}
