import 'dart:math';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exam_session/data/consent_record.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/exam_session_repositories.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:uuid/uuid.dart';

/// A student's attempts, kept on this device.
///
/// Every call acts for the signed-in student and only ever touches that student's own attempts; another student's attempt
/// is "not found". The attempt keeps a snapshot of the exam (answer key included) so grading never depends on later edits,
/// and nothing that leaves this class carries that key: the student's own types have no field for it.
final class LocalAttemptRepository implements AttemptRepository {
  /// Creates the repository. [random] decides the shuffles; tests pass a seeded one.
  LocalAttemptRepository({
    required this._exams,
    required this._attempts,
    required this._consents,
    required this._caller,
    required this._clock,
    this._random,
    this._uuid = const Uuid(),
  });

  final JsonCollectionStore<Exam> _exams;
  final JsonCollectionStore<Attempt> _attempts;
  final JsonCollectionStore<ConsentRecord> _consents;
  final LocalCaller _caller;
  final AppClock _clock;
  final Random? _random;
  final Uuid _uuid;

  @override
  Future<Result<void>> recordConsent(String examId) => _guarded<void>((student) async {
    final exam = await _publishedExam(examId);
    if (exam == null) return const Err(NotFoundFailure());
    await _consents.mutate<void>((records) {
      if (records.any((r) => r.studentId == student.id && r.examId == examId)) return;
      records.add(ConsentRecord(studentId: student.id, examId: examId, givenAt: _clock.now()));
    });
    return const Ok<void>(null);
  });

  @override
  Future<Result<bool>> hasConsent(String examId) => _guarded<bool>((student) async {
    final records = await _consents.all();
    return Ok(records.any((r) => r.studentId == student.id && r.examId == examId));
  });

  @override
  Future<Result<StudentAttemptSession>> startAttempt(String examId) => _guarded((student) async {
    final exam = await _publishedExam(examId);
    if (exam == null) return const Err(NotFoundFailure());
    final now = _clock.now();

    // An attempt that already exists is resumed (or refused if it was submitted) whatever the window says now.
    final existing = [
      for (final attempt in await _attempts.all())
        if (attempt.exam.id == examId && attempt.studentId == student.id) attempt,
    ];
    if (existing.isNotEmpty) {
      final attempt = existing.first;
      if (attempt.status == AttemptStatus.submitted) {
        return const Err(ConflictFailure(code: 'attempt_already_submitted'));
      }
      return Ok(_session(attempt));
    }

    final opens = exam.opensAt;
    final closes = exam.closesAt;
    if (opens != null && now.isBefore(opens)) return const Err(ConflictFailure(code: 'exam_not_open_yet'));
    if (closes != null && !now.isBefore(closes)) return const Err(ConflictFailure(code: 'exam_closed'));
    final consents = await _consents.all();
    if (!consents.any((r) => r.studentId == student.id && r.examId == examId)) {
      return const Err(ConflictFailure(code: 'consent_required'));
    }

    final created = await _attempts.mutate<Result<Attempt>>((all) {
      // Two starts at once must make one attempt.
      for (final attempt in all) {
        if (attempt.exam.id == examId && attempt.studentId == student.id) return Ok(attempt);
      }
      final random = _random ?? Random.secure();
      final questionIds = [for (final question in exam.questions) question.id];
      if (exam.settings.randomizeQuestions) questionIds.shuffle(random);
      final optionOrders = <String, List<String>>{};
      for (final question in exam.questions) {
        if (!question.type.hasOptions) continue;
        final ids = [for (final option in question.options) option.id];
        if (exam.settings.randomizeOptions) ids.shuffle(random);
        optionOrders[question.id] = ids;
      }
      final attempt = Attempt(
        id: _uuid.v4(),
        studentId: student.id,
        studentName: student.fullName,
        exam: exam,
        startedAt: now,
        deadline: exam.deadlineFor(now),
        lastSeenAt: now,
        status: AttemptStatus.inProgress,
        currentIndex: 0,
        questionOrder: questionIds,
        optionOrders: optionOrders,
        answers: const {},
        manualMarks: const {},
      );
      all.add(attempt);
      return Ok(attempt);
    });
    switch (created) {
      case Err<Attempt>(:final failure):
        return Err(failure);
      case Ok<Attempt>(:final value):
        return Ok(_session(value));
    }
  });

  @override
  Future<Result<StudentAttemptSession>> getSession(String attemptId) => _guarded((student) async {
    final attempt = await _owned(attemptId, student.id);
    return attempt == null ? const Err(NotFoundFailure()) : Ok(_session(attempt));
  });

  @override
  Future<Result<void>> saveAnswer(String attemptId, String questionId, AnswerValue? answer) =>
      _guarded<void>((student) async {
        final now = _clock.now();
        return _attempts.mutate<Result<void>>((all) {
          final index = _indexOwned(all, attemptId, student.id);
          if (index < 0) return const Err(NotFoundFailure());
          final attempt = all[index];
          if (attempt.status == AttemptStatus.submitted) {
            return const Err(ConflictFailure(code: 'attempt_already_submitted'));
          }
          final timer = AttemptTimer(deadline: attempt.deadline, seenUpTo: attempt.lastSeenAt);
          final trusted = timer.observe(now);
          if (timer.isOver(trusted)) {
            // Keep what the clock showed, so a rewound clock stays rewound.
            all[index] = attempt.copyWith(lastSeenAt: timer.seenUpTo);
            return const Err(ConflictFailure(code: 'attempt_time_over'));
          }
          final question = attempt.exam.questions.where((q) => q.id == questionId).firstOrNull;
          if (question == null) return const Err(NotFoundFailure());
          final problem = _invalidAnswer(question, answer);
          if (problem != null) return Err(ValidationFailure(fields: {'answer': problem}));

          final answers = {...attempt.answers};
          if (answer == null) {
            answers.remove(questionId);
          } else {
            answers[questionId] = answer;
          }
          all[index] = attempt.copyWith(answers: answers, lastSeenAt: timer.seenUpTo);
          return const Ok<void>(null);
        });
      });

  @override
  Future<Result<void>> saveProgress(String attemptId, int questionIndex) => _guarded<void>((student) async {
    final now = _clock.now();
    return _attempts.mutate<Result<void>>((all) {
      final index = _indexOwned(all, attemptId, student.id);
      if (index < 0) return const Err(NotFoundFailure());
      final attempt = all[index];
      if (attempt.status == AttemptStatus.submitted) return const Ok<void>(null);
      final timer = AttemptTimer(deadline: attempt.deadline, seenUpTo: attempt.lastSeenAt)..observe(now);
      final last = attempt.questionOrder.isEmpty ? 0 : attempt.questionOrder.length - 1;
      all[index] = attempt.copyWith(currentIndex: questionIndex.clamp(0, last), lastSeenAt: timer.seenUpTo);
      return const Ok<void>(null);
    });
  });

  @override
  Future<Result<StudentResult>> submit(String attemptId, {bool auto = false}) => _guarded((student) async {
    final now = _clock.now();
    final outcome = await _attempts.mutate<Result<Attempt>>((all) {
      final index = _indexOwned(all, attemptId, student.id);
      if (index < 0) return const Err(NotFoundFailure());
      final attempt = all[index];
      // Already submitted: the original result stands. Nothing is graded twice.
      if (attempt.status == AttemptStatus.submitted) return Ok(attempt);

      final timer = AttemptTimer(deadline: attempt.deadline, seenUpTo: attempt.lastSeenAt);
      final trusted = timer.observe(now);
      final late = timer.isOver(trusted);
      final result = Grader.grade(
        questions: attempt.exam.questions,
        answers: attempt.answers,
        passMarkPercent: attempt.exam.passMarkPercent,
      );
      final submitted = attempt.copyWith(
        status: AttemptStatus.submitted,
        // After the deadline the attempt ended AT the deadline, not whenever the app got round to saying so.
        submittedAt: late ? attempt.deadline : trusted,
        submissionKind: auto || late ? SubmissionKind.auto : SubmissionKind.manual,
        lastSeenAt: timer.seenUpTo,
        result: result,
      );
      all[index] = submitted;
      return Ok(submitted);
    });
    switch (outcome) {
      case Err<Attempt>(:final failure):
        return Err(failure);
      case Ok<Attempt>(:final value):
        return Ok(_resultOf(value, now));
    }
  });

  @override
  Future<Result<StudentResult>> getResult(String attemptId) => _guarded((student) async {
    final attempt = await _owned(attemptId, student.id);
    if (attempt == null || attempt.status != AttemptStatus.submitted) return const Err(NotFoundFailure());
    return Ok(_resultOf(attempt, _clock.now()));
  });

  @override
  Future<Result<List<StudentResult>>> listResults() => _guarded((student) async {
    final now = _clock.now();
    final results = [
      for (final attempt in await _attempts.all())
        if (attempt.studentId == student.id && attempt.status == AttemptStatus.submitted) _resultOf(attempt, now),
    ]..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return Ok(results);
  });

  /// The student's view of an attempt: this student's order, no answer key.
  StudentAttemptSession _session(Attempt attempt) {
    final exam = attempt.exam;
    final questions = [
      for (final question in attempt.orderedQuestions)
        StudentQuestion.of(question, optionOrder: attempt.optionOrders[question.id]),
    ];
    return StudentAttemptSession(
      attemptId: attempt.id,
      examId: exam.id,
      title: exam.title,
      instructions: exam.instructions,
      startedAt: attempt.startedAt,
      deadline: attempt.deadline,
      lastSeenAt: attempt.lastSeenAt,
      status: attempt.status,
      currentIndex: attempt.currentIndex,
      questions: questions,
      answers: attempt.answers,
      calculatorEnabled: exam.settings.calculatorEnabled,
      allowBackwardNavigation: exam.settings.allowBackwardNavigation,
      plan: ProctoringPlan(
        activeRules: {
          for (final rule in exam.settings.enabledRules)
            if (rule.hasDetector) rule,
        },
        sustainedThresholdSeconds: exam.settings.sustainedThresholdSeconds,
        evidenceBufferSeconds: exam.settings.evidenceBufferSeconds,
        maxWarnings: exam.settings.maxWarnings,
      ),
    );
  }

  /// The result as the student may see it: held back (not even sent) until the exam shows results or its window closes.
  StudentResult _resultOf(Attempt attempt, DateTime now) {
    final exam = attempt.exam;
    final closes = exam.closesAt;
    final visible = exam.settings.showResultImmediately || closes == null || !now.isBefore(closes);
    return StudentResult(
      attemptId: attempt.id,
      examId: exam.id,
      examTitle: exam.title,
      submittedAt: attempt.submittedAt ?? attempt.deadline,
      submissionKind: attempt.submissionKind ?? SubmissionKind.manual,
      visible: visible,
      releaseAt: visible ? null : closes,
      result: visible ? attempt.result : null,
      questionTexts: visible ? {for (final q in exam.questions) q.id: q.text} : const {},
      explanations: visible && exam.settings.showExplanations
          ? {
              for (final q in exam.questions)
                if (q.explanation != null) q.id: q.explanation!,
            }
          : const {},
    );
  }

  FieldProblem? _invalidAnswer(Question question, AnswerValue? answer) {
    switch (answer) {
      case null:
        return null;
      case ChoiceAnswer(:final optionIds):
        if (!question.type.hasOptions) return const KnownFieldProblem(FieldReason.invalidCharacters);
        final known = {for (final option in question.options) option.id};
        if (!known.containsAll(optionIds)) return const KnownFieldProblem(FieldReason.outOfRange);
        if (question.type == QuestionType.singleChoice && optionIds.length > 1) {
          return const KnownFieldProblem(FieldReason.outOfRange);
        }
        return null;
      case TextAnswer(:final text):
        if (question.type != QuestionType.shortText) return const KnownFieldProblem(FieldReason.invalidCharacters);
        if (text.length > TextAnswer.maxLength) return const KnownFieldProblem(FieldReason.tooLong);
        return null;
    }
  }

  Future<Exam?> _publishedExam(String examId) async {
    for (final exam in await _exams.all()) {
      if (exam.id == examId && exam.lifecycle == ExamLifecycle.published) return exam;
    }
    return null;
  }

  Future<Attempt?> _owned(String attemptId, String studentId) async {
    for (final attempt in await _attempts.all()) {
      if (attempt.id == attemptId && attempt.studentId == studentId) return attempt;
    }
    return null;
  }

  int _indexOwned(List<Attempt> all, String attemptId, String studentId) =>
      all.indexWhere((attempt) => attempt.id == attemptId && attempt.studentId == studentId);

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
