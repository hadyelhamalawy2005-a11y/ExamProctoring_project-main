import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';

/// An instructor's exams: writing them, and publishing them. Every call acts for the signed-in instructor, who can see and
/// change only their own exams; anyone else's exam is "not found".
abstract interface class ExamRepository {
  /// The default page size.
  static const int defaultPageSize = 10;

  /// The largest page size.
  static const int maxPageSize = 100;

  /// The instructor's exams, newest first, optionally only those whose status at the current time is [status].
  Future<Result<ExamPage>> listExams({ExamStatus? status, int page = 1, int pageSize = defaultPageSize});

  /// One exam with its questions and answer key.
  Future<Result<Exam>> getExam(String id);

  /// Creates a draft exam from the wizard's first step.
  Future<Result<Exam>> createExam(ExamDetails details);

  /// Replaces the first step's fields.
  Future<Result<Exam>> updateDetails(String id, ExamDetails details);

  /// Replaces the settings.
  Future<Result<Exam>> updateSettings(String id, ExamSettings settings);

  /// Sets the availability window.
  Future<Result<Exam>> updateSchedule(String id, {required DateTime opensAt, required DateTime closesAt});

  /// Adds the question, or replaces the one with the same id. [confirmsAnswerKey] says the instructor looked at the
  /// correct answer in this save (see [AnswerKey.staleAfterEdit]).
  Future<Result<Exam>> saveQuestion(String examId, Question question, {bool confirmsAnswerKey = false});

  /// Appends several questions at once (the Word import). Each must pass validation, or none is added.
  Future<Result<Exam>> addQuestions(String examId, List<Question> questions);

  /// Removes a question.
  Future<Result<Exam>> deleteQuestion(String examId, String questionId);

  /// Moves a question to [toIndex] (0-based).
  Future<Result<Exam>> moveQuestion(String examId, String questionId, int toIndex);

  /// Publishes the exam, or refuses with every reason ([ExamNotPublishableFailure]).
  Future<Result<Exam>> publish(String examId);

  /// Returns a published exam that has not opened (and has no attempts) to draft.
  Future<Result<Exam>> unpublish(String examId);

  /// Withdraws a published exam for good.
  Future<Result<Exam>> archive(String examId);

  /// Deletes a draft with its questions. A published exam is never deleted.
  Future<Result<void>> deleteDraft(String examId);
}
