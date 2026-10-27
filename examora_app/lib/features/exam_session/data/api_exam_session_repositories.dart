import 'package:examora_app/core/network/missing_endpoints.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/exam_session_repositories.dart';
import 'package:examora_app/features/exam_session/domain/instructor_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';

/// The student's exam list and briefing against the Examora API.
///
/// The API has no student-facing exam endpoints (see [MissingEndpoints]). Every call REFUSES, naming the endpoint it needs,
/// and sends nothing: it never falls back to the exams stored on the device.
final class ApiStudentExamRepository implements StudentExamRepository {
  /// Creates the repository.
  const ApiStudentExamRepository();

  @override
  Future<Result<List<StudentExamSummary>>> listExams() async => MissingEndpoints.studentExamList.refuse();

  @override
  Future<Result<StudentExamInfo>> getExam(String examId) async => MissingEndpoints.studentExamBriefing.refuse();
}

/// A student's attempts against the Examora API. The API has no attempts at all, so every call refuses by name.
final class ApiAttemptRepository implements AttemptRepository {
  /// Creates the repository.
  const ApiAttemptRepository();

  @override
  Future<Result<void>> recordConsent(String examId) async => MissingEndpoints.recordConsent.refuse();

  @override
  Future<Result<bool>> hasConsent(String examId) async => MissingEndpoints.recordConsent.refuse();

  @override
  Future<Result<StudentAttemptSession>> startAttempt(String examId) async => MissingEndpoints.startAttempt.refuse();

  @override
  Future<Result<StudentAttemptSession>> getSession(String attemptId) async => MissingEndpoints.attemptSession.refuse();

  @override
  Future<Result<void>> saveAnswer(String attemptId, String questionId, AnswerValue? answer) async =>
      MissingEndpoints.saveAnswer.refuse();

  @override
  Future<Result<void>> saveProgress(String attemptId, int questionIndex) async =>
      MissingEndpoints.saveProgress.refuse();

  @override
  Future<Result<StudentResult>> submit(String attemptId, {bool auto = false}) async =>
      MissingEndpoints.submitAttempt.refuse();

  @override
  Future<Result<StudentResult>> getResult(String attemptId) async => MissingEndpoints.attemptResult.refuse();

  @override
  Future<Result<List<StudentResult>>> listResults() async => MissingEndpoints.studentResults.refuse();
}

/// An instructor's view of attempts against the Examora API. The API has no attempts, so every call refuses by name.
final class ApiInstructorAttemptRepository implements InstructorAttemptRepository {
  /// Creates the repository.
  const ApiInstructorAttemptRepository();

  @override
  Future<Result<List<AttemptSummary>>> listForExam(String examId) async => MissingEndpoints.instructorAttempts.refuse();

  @override
  Future<Result<AttemptReview>> getReview(String attemptId) async => MissingEndpoints.attemptReview.refuse();

  @override
  Future<Result<AttemptReview>> markShortAnswer(String attemptId, String questionId, double marks) async =>
      MissingEndpoints.markShortAnswer.refuse();
}
