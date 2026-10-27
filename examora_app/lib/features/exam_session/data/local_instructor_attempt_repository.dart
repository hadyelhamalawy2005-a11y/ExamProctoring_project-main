import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/exam_session_repositories.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exam_session/domain/instructor_attempt.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/question.dart';

/// How many incidents an attempt has. Incidents are stored separately, so the provider supplies this.
typedef IncidentCounter = Future<int> Function(String attemptId);

/// An instructor's view of the attempts at the exams they own, over the attempts stored on this device.
///
/// Another instructor's exam, and the attempts at it, are "not found". A student is turned away.
final class LocalInstructorAttemptRepository implements InstructorAttemptRepository {
  /// Creates the repository.
  LocalInstructorAttemptRepository({
    required this._exams,
    required this._attempts,
    required this._caller,
    this._incidentCount = _noIncidents,
  });

  static Future<int> _noIncidents(String attemptId) async => 0;

  final JsonCollectionStore<Exam> _exams;
  final JsonCollectionStore<Attempt> _attempts;
  final LocalCaller _caller;
  final IncidentCounter _incidentCount;

  @override
  Future<Result<List<AttemptSummary>>> listForExam(String examId) => _guarded((instructor) async {
    final owns = (await _exams.all()).any((exam) => exam.id == examId && exam.ownerId == instructor.id);
    if (!owns) return const Err(NotFoundFailure());
    final summaries = <AttemptSummary>[];
    for (final attempt in await _attempts.all()) {
      if (attempt.exam.id != examId) continue;
      summaries.add(
        AttemptSummary(
          attemptId: attempt.id,
          studentName: attempt.studentName,
          status: attempt.status,
          startedAt: attempt.startedAt,
          submittedAt: attempt.submittedAt,
          submissionKind: attempt.submissionKind,
          result: attempt.result,
          incidentCount: await _incidentCount(attempt.id),
        ),
      );
    }
    summaries.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return Ok(summaries);
  });

  @override
  Future<Result<AttemptReview>> getReview(String attemptId) => _guarded((instructor) async {
    for (final attempt in await _attempts.all()) {
      if (attempt.id == attemptId && attempt.exam.ownerId == instructor.id) {
        return Ok(await _review(attempt));
      }
    }
    return const Err(NotFoundFailure());
  });

  @override
  Future<Result<AttemptReview>> markShortAnswer(String attemptId, String questionId, double marks) => _guarded((
    instructor,
  ) async {
    final outcome = await _attempts.mutate<Result<Attempt>>((all) {
      final index = all.indexWhere((a) => a.id == attemptId && a.exam.ownerId == instructor.id);
      if (index < 0) return const Err(NotFoundFailure());
      final attempt = all[index];
      if (attempt.status != AttemptStatus.submitted) return const Err(ConflictFailure(code: 'attempt_not_submitted'));
      final question = attempt.exam.questions.where((q) => q.id == questionId).firstOrNull;
      if (question == null) return const Err(NotFoundFailure());
      if (question.type != QuestionType.shortText) {
        return const Err(ValidationFailure(fields: {'marks': KnownFieldProblem(FieldReason.invalidCharacters)}));
      }
      // The marks are limited to what the question offers: nobody can give 7 out of 5.
      final given = Grader.clamp(marks, question.marks);
      final manual = {...attempt.manualMarks, questionId: given};
      final updated = attempt.copyWith(
        manualMarks: manual,
        result: Grader.grade(
          questions: attempt.exam.questions,
          answers: attempt.answers,
          manualMarks: manual,
          passMarkPercent: attempt.exam.passMarkPercent,
        ),
      );
      all[index] = updated;
      return Ok(updated);
    });
    switch (outcome) {
      case Err<Attempt>(:final failure):
        return Err(failure);
      case Ok<Attempt>(:final value):
        return Ok(await _review(value));
    }
  });

  Future<AttemptReview> _review(Attempt attempt) async {
    final result =
        attempt.result ??
        Grader.grade(
          questions: attempt.exam.questions,
          answers: attempt.answers,
          manualMarks: attempt.manualMarks,
          passMarkPercent: attempt.exam.passMarkPercent,
        );
    final byId = {for (final r in result.questions) r.questionId: r};
    return AttemptReview(
      attemptId: attempt.id,
      examId: attempt.exam.id,
      examTitle: attempt.exam.title,
      studentName: attempt.studentName,
      status: attempt.status,
      submittedAt: attempt.submittedAt,
      submissionKind: attempt.submissionKind,
      questions: [
        for (final question in attempt.exam.questions)
          ReviewedQuestion(question: question, answer: attempt.answers[question.id], result: byId[question.id]!),
      ],
      result: result,
      incidentCount: await _incidentCount(attempt.id),
    );
  }

  Future<Result<T>> _guarded<T>(Future<Result<T>> Function(StoredAccount instructor) action) async {
    try {
      final caller = await _caller.currentWithRole(UserRole.instructor);
      switch (caller) {
        case Err<StoredAccount>(:final failure):
          return Err<T>(failure);
        case Ok<StoredAccount>(:final value):
          return await action(value);
      }
    } on Object {
      return Err<T>(const StorageFailure());
    }
  }
}
