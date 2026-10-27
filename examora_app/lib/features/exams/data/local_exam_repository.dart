import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_repository.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/exam_validation.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:uuid/uuid.dart';

/// Whether an exam already has attempts. Attempts are stored elsewhere, so this is a function the provider supplies.
typedef HasAttempts = Future<bool> Function(String examId);

/// An instructor's exams, kept on this device.
///
/// Every call is made by the signed-in instructor and touches only their own exams: someone else's exam answers "not
/// found", exactly as if it did not exist.
final class LocalExamRepository implements ExamRepository {
  /// Creates the repository.
  LocalExamRepository({
    required this._exams,
    required this._caller,
    required this._clock,
    this._hasAttempts = _noAttempts,
    this._uuid = const Uuid(),
  });

  static Future<bool> _noAttempts(String examId) async => false;

  final JsonCollectionStore<Exam> _exams;
  final LocalCaller _caller;
  final AppClock _clock;
  final HasAttempts _hasAttempts;
  final Uuid _uuid;

  @override
  Future<Result<ExamPage>> listExams({
    ExamStatus? status,
    int page = 1,
    int pageSize = ExamRepository.defaultPageSize,
  }) => _guarded((owner) async {
    if (page < 1 || pageSize < 1 || pageSize > ExamRepository.maxPageSize) {
      return const Err(ValidationFailure(fields: {'page': ServerFieldProblem('Page or page size is out of range.')}));
    }
    final now = _clock.now();
    final matching = [
      for (final exam in await _exams.all())
        if (exam.ownerId == owner && (status == null || exam.statusAt(now) == status)) exam,
    ]..sort((a, b) => _created(b).compareTo(_created(a)));
    final start = (page - 1) * pageSize;
    return Ok(
      ExamPage(
        items: [
          for (final exam in start >= matching.length ? const <Exam>[] : matching.skip(start).take(pageSize))
            ExamSummary(
              id: exam.id,
              title: exam.title,
              courseName: exam.courseName,
              durationMinutes: exam.durationMinutes,
              status: exam.statusAt(now),
              version: exam.version,
              opensAt: exam.opensAt,
              closesAt: exam.closesAt,
              questionCount: exam.questions.length,
            ),
        ],
        page: page,
        pageSize: pageSize,
        totalCount: matching.length,
      ),
    );
  });

  @override
  Future<Result<Exam>> getExam(String id) => _guarded((owner) async {
    for (final exam in await _exams.all()) {
      if (exam.id == id && exam.ownerId == owner) return Ok(exam);
    }
    return const Err(NotFoundFailure());
  });

  @override
  Future<Result<Exam>> createExam(ExamDetails details) => _guarded((owner) async {
    final problems = ExamValidation.details(details);
    if (problems.isNotEmpty) return Err(ValidationFailure(fields: problems));
    final now = _clock.now();
    final exam = Exam(
      id: _uuid.v4(),
      ownerId: owner,
      title: details.title.trim(),
      courseName: details.courseName.trim(),
      description: details.description.trim(),
      instructions: details.instructions.trim(),
      durationMinutes: details.durationMinutes,
      passMarkPercent: details.passMarkPercent,
      settings: const ExamSettings(),
      version: 1,
      lifecycle: ExamLifecycle.draft,
      createdAt: now,
      updatedAt: now,
    );
    await _exams.mutate<void>((all) => all.add(exam));
    return Ok(exam);
  });

  @override
  Future<Result<Exam>> updateDetails(String id, ExamDetails details) => _edit(id, (exam) {
    final problems = ExamValidation.details(details);
    if (problems.isNotEmpty) return Err(ValidationFailure(fields: problems));
    return Ok(
      exam.copyWith(
        title: details.title.trim(),
        courseName: details.courseName.trim(),
        description: details.description.trim(),
        instructions: details.instructions.trim(),
        durationMinutes: details.durationMinutes,
        passMarkPercent: (value: details.passMarkPercent),
      ),
    );
  });

  @override
  Future<Result<Exam>> updateSettings(String id, ExamSettings settings) => _edit(id, (exam) {
    final problems = ExamValidation.settings(settings);
    if (problems.isNotEmpty) return Err(ValidationFailure(fields: problems));
    return Ok(exam.copyWith(settings: settings));
  });

  @override
  Future<Result<Exam>> updateSchedule(String id, {required DateTime opensAt, required DateTime closesAt}) =>
      _edit(id, (exam) {
        final problems = ExamValidation.schedule(
          opensAt: opensAt,
          closesAt: closesAt,
          durationMinutes: exam.durationMinutes,
        );
        if (problems.isNotEmpty) return Err(ValidationFailure(fields: problems));
        return Ok(exam.copyWith(opensAt: (value: opensAt.toUtc()), closesAt: (value: closesAt.toUtc())));
      });

  @override
  Future<Result<Exam>> saveQuestion(String examId, Question question, {bool confirmsAnswerKey = false}) =>
      _edit(examId, (exam) {
        final cleaned = _clean(question);
        final problems = ExamValidation.questionStructure(cleaned);
        if (problems.isNotEmpty) return Err(QuestionInvalidFailure(problems));

        final questions = [...exam.questions];
        final index = questions.indexWhere((existing) => existing.id == cleaned.id);
        if (index < 0) {
          questions.add(cleaned.copyWith(answerKeyStale: false));
        } else {
          final stale = AnswerKey.staleAfterEdit(questions[index], cleaned, confirmed: confirmsAnswerKey);
          questions[index] = cleaned.copyWith(answerKeyStale: stale);
        }
        return Ok(exam.copyWith(questions: questions));
      });

  @override
  Future<Result<Exam>> addQuestions(String examId, List<Question> questions) => _edit(examId, (exam) {
    final cleaned = [for (final question in questions) _clean(question)];
    for (final question in cleaned) {
      final problems = ExamValidation.questionStructure(question);
      if (problems.isNotEmpty) return Err(QuestionInvalidFailure(problems));
    }
    final existingIds = {for (final question in exam.questions) question.id};
    if (cleaned.any((question) => existingIds.contains(question.id))) {
      return const Err(ConflictFailure(code: 'question_exists'));
    }
    return Ok(exam.copyWith(questions: [...exam.questions, ...cleaned]));
  });

  @override
  Future<Result<Exam>> deleteQuestion(String examId, String questionId) => _edit(examId, (exam) {
    if (!exam.questions.any((question) => question.id == questionId)) return const Err(NotFoundFailure());
    return Ok(
      exam.copyWith(
        questions: [
          for (final q in exam.questions)
            if (q.id != questionId) q,
        ],
      ),
    );
  });

  @override
  Future<Result<Exam>> moveQuestion(String examId, String questionId, int toIndex) => _edit(examId, (exam) {
    final from = exam.questions.indexWhere((question) => question.id == questionId);
    if (from < 0) return const Err(NotFoundFailure());
    if (toIndex < 0 || toIndex >= exam.questions.length) {
      return const Err(ValidationFailure(fields: {'position': KnownFieldProblem(FieldReason.outOfRange)}));
    }
    final questions = [...exam.questions];
    questions.insert(toIndex, questions.removeAt(from));
    return Ok(exam.copyWith(questions: questions));
  });

  @override
  Future<Result<Exam>> publish(String examId) => _transition(examId, (exam, now) {
    switch (exam.lifecycle) {
      case ExamLifecycle.published:
        return const Err(ConflictFailure(code: 'exam_already_published'));
      case ExamLifecycle.archived:
        return const Err(ConflictFailure(code: 'exam_archived'));
      case ExamLifecycle.draft:
        final problems = ExamValidation.publishing(exam, now);
        if (problems.isNotEmpty) return Err(ExamNotPublishableFailure(problems));
        return Ok(exam.copyWith(lifecycle: ExamLifecycle.published, publishedAt: (value: now)));
    }
  });

  @override
  Future<Result<Exam>> unpublish(String examId) async {
    final attempts = await _hasAttempts(examId);
    return _transition(examId, (exam, now) {
      final started = exam.opensAt != null && !exam.opensAt!.isAfter(now);
      if (exam.lifecycle != ExamLifecycle.published || started || attempts) {
        return const Err(ConflictFailure(code: 'exam_not_unpublishable'));
      }
      return Ok(exam.copyWith(lifecycle: ExamLifecycle.draft, publishedAt: (value: null)));
    });
  }

  @override
  Future<Result<Exam>> archive(String examId) => _transition(examId, (exam, now) {
    if (exam.lifecycle != ExamLifecycle.published) return const Err(ConflictFailure(code: 'exam_not_archivable'));
    return Ok(exam.copyWith(lifecycle: ExamLifecycle.archived, archivedAt: (value: now)));
  });

  @override
  Future<Result<void>> deleteDraft(String examId) => _guarded<void>((owner) async {
    final deleted = await _exams.mutate<Result<void>>((all) {
      final index = all.indexWhere((exam) => exam.id == examId && exam.ownerId == owner);
      if (index < 0) return const Err(NotFoundFailure());
      if (all[index].lifecycle != ExamLifecycle.draft) return const Err(ConflictFailure(code: 'exam_not_deletable'));
      all.removeAt(index);
      return const Ok<void>(null);
    });
    return deleted;
  });

  DateTime _created(Exam exam) => exam.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Trims what the instructor typed and drops an empty model answer or explanation.
  Question _clean(Question question) {
    String? nullIfBlank(String? text) {
      final trimmed = text?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }

    return Question(
      id: question.id,
      type: question.type,
      text: question.text.trim(),
      marks: question.marks,
      options: question.type.hasOptions
          ? [for (final option in question.options) option.copyWith(text: option.text.trim())]
          : const [],
      modelAnswer: nullIfBlank(question.modelAnswer),
      explanation: nullIfBlank(question.explanation),
      topic: nullIfBlank(question.topic),
      difficulty: nullIfBlank(question.difficulty),
      source: question.source,
      needsReview: question.needsReview,
      answerKeyStale: question.answerKeyStale,
    );
  }

  /// Changes an exam that can still be edited: a draft, or a published exam that has not opened yet.
  Future<Result<Exam>> _edit(String id, Result<Exam> Function(Exam exam) change) => _guarded((owner) {
    final now = _clock.now();
    return _exams.mutate<Result<Exam>>((all) {
      final index = all.indexWhere((exam) => exam.id == id && exam.ownerId == owner);
      if (index < 0) return const Err(NotFoundFailure());
      final current = all[index];
      if (!_isEditable(current, now)) return const Err(ConflictFailure(code: 'exam_not_editable'));
      return _store(all, index, current, change(current), now);
    });
  });

  /// Publish, unpublish and archive: allowed in states [_edit] refuses, so they decide for themselves.
  Future<Result<Exam>> _transition(String id, Result<Exam> Function(Exam exam, DateTime now) change) =>
      _guarded((owner) {
        final now = _clock.now();
        return _exams.mutate<Result<Exam>>((all) {
          final index = all.indexWhere((exam) => exam.id == id && exam.ownerId == owner);
          if (index < 0) return const Err(NotFoundFailure());
          final current = all[index];
          return _store(all, index, current, change(current, now), now);
        });
      });

  Result<Exam> _store(List<Exam> all, int index, Exam before, Result<Exam> outcome, DateTime now) {
    switch (outcome) {
      case Err<Exam>():
        return outcome;
      case Ok<Exam>(:final value):
        // The version goes up when something a student sees changes while the exam is published.
        final visibleChange =
            before.lifecycle == ExamLifecycle.published &&
            value.lifecycle == ExamLifecycle.published &&
            before.contentFingerprint != value.contentFingerprint;
        final updated = value.copyWith(version: visibleChange ? before.version + 1 : value.version, updatedAt: now);
        all[index] = updated;
        return Ok(updated);
    }
  }

  bool _isEditable(Exam exam, DateTime now) {
    switch (exam.lifecycle) {
      case ExamLifecycle.draft:
        return true;
      case ExamLifecycle.archived:
        return false;
      case ExamLifecycle.published:
        final opens = exam.opensAt;
        return opens != null && opens.isAfter(now);
    }
  }

  /// Runs [action] for the signed-in instructor, and turns a storage error into [StorageFailure].
  Future<Result<T>> _guarded<T>(Future<Result<T>> Function(String ownerId) action) async {
    try {
      final caller = await _caller.currentWithRole(UserRole.instructor);
      switch (caller) {
        case Err<StoredAccount>(:final failure):
          return Err<T>(failure);
        case Ok<StoredAccount>(:final value):
          return await action(value.id);
      }
    } on Object {
      return Err<T>(const StorageFailure());
    }
  }
}
