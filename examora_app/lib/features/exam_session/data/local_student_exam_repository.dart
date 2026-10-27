import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/exam_session_repositories.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exams/domain/exam.dart';

/// The exams a student can see, read from the exams stored on this device.
///
/// Only published exams are visible, and they are converted to the student's own types ([StudentExamInfo]), which have no
/// field for an answer key. A draft or an archived exam is "not found".
final class LocalStudentExamRepository implements StudentExamRepository {
  /// Creates the repository.
  LocalStudentExamRepository({
    required this._exams,
    required this._attempts,
    required this._caller,
    required this._clock,
  });

  final JsonCollectionStore<Exam> _exams;
  final JsonCollectionStore<Attempt> _attempts;
  final LocalCaller _caller;
  final AppClock _clock;

  @override
  Future<Result<List<StudentExamSummary>>> listExams() => _guarded((student) async {
    final now = _clock.now();
    final attempts = await _attempts.all();
    final summaries = <StudentExamSummary>[];
    for (final exam in await _exams.all()) {
      if (exam.lifecycle != ExamLifecycle.published) continue;
      final attempt = _attemptFor(attempts, exam.id, student.id);
      summaries.add(
        StudentExamSummary(
          id: exam.id,
          title: exam.title,
          courseName: exam.courseName,
          durationMinutes: exam.durationMinutes,
          status: exam.statusAt(now),
          attemptState: _stateOf(attempt),
          questionCount: exam.questions.length,
          opensAt: exam.opensAt,
          closesAt: exam.closesAt,
          attemptId: attempt?.id,
        ),
      );
    }
    // The window that matters soonest (or is open now) first.
    summaries.sort((a, b) => (b.opensAt ?? DateTime(0)).compareTo(a.opensAt ?? DateTime(0)));
    return Ok(summaries);
  });

  @override
  Future<Result<StudentExamInfo>> getExam(String examId) => _guarded((student) async {
    final now = _clock.now();
    for (final exam in await _exams.all()) {
      if (exam.id != examId || exam.lifecycle != ExamLifecycle.published) continue;
      final attempt = _attemptFor(await _attempts.all(), exam.id, student.id);
      return Ok(StudentExamInfo.of(exam, now: now, attemptState: _stateOf(attempt), attemptId: attempt?.id));
    }
    return const Err(NotFoundFailure());
  });

  Attempt? _attemptFor(List<Attempt> attempts, String examId, String studentId) {
    for (final attempt in attempts) {
      if (attempt.exam.id == examId && attempt.studentId == studentId) return attempt;
    }
    return null;
  }

  AttemptState _stateOf(Attempt? attempt) => switch (attempt?.status) {
    null => AttemptState.notStarted,
    AttemptStatus.inProgress => AttemptState.inProgress,
    AttemptStatus.submitted => AttemptState.submitted,
  };

  Future<Result<T>> _guarded<T>(Future<Result<T>> Function(StoredAccount student) action) async {
    try {
      final caller = await _caller.currentWithRole(UserRole.student);
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
