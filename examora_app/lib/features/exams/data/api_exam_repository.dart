import 'package:examora_app/core/network/api_client.dart';
import 'package:examora_app/core/network/missing_endpoints.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_repository.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';

/// An instructor's exams on the Examora HTTP API (`ExamsController` and `QuestionsController`).
///
/// The server models less than the app does (see [MissingEndpoints]): no course name, instructions, pass mark, version or
/// settings, no availability window beyond the duration, no multiple-choice questions. Reading is done with what the
/// server has; a field it lacks is left empty or null, never invented. Writing something the server cannot store is
/// REFUSED, naming the endpoint, instead of being silently dropped or kept locally.
final class ApiExamRepository implements ExamRepository {
  /// Creates the repository.
  const ApiExamRepository({required this._client});

  final ApiClient _client;

  @override
  Future<Result<ExamPage>> listExams({
    ExamStatus? status,
    int page = 1,
    int pageSize = ExamRepository.defaultPageSize,
  }) async {
    final String? serverStatus;
    switch (status) {
      case null:
        serverStatus = null;
      case ExamStatus.draft:
        serverStatus = 'Draft';
      case ExamStatus.archived:
        serverStatus = 'Cancelled';
      case ExamStatus.scheduled || ExamStatus.ongoing || ExamStatus.completed:
        return MissingEndpoints.listExamsByPhase.refuse();
    }
    final response = await _client.get(
      '/api/exams',
      query: {'status': ?serverStatus, 'page': '$page', 'pageSize': '$pageSize'},
    );
    return _parse(
      response,
      (json) => ExamPage(
        items: json.list('items', _summary),
        page: json.integer('page'),
        pageSize: json.integer('pageSize'),
        totalCount: json.integer('totalCount'),
      ),
    );
  }

  @override
  Future<Result<Exam>> getExam(String id) async {
    final examResponse = await _client.get('/api/exams/${_id(id)}');
    final questionsResponse = await _client.get('/api/exams/${_id(id)}/questions');
    switch ((examResponse, questionsResponse)) {
      case (Err<Object?>(:final failure), _):
        return Err(failure);
      case (_, Err<Object?>(:final failure)):
        return Err(failure);
      case (Ok<Object?>(value: final examJson), Ok<Object?>(value: final questionsJson)):
        return JsonReader.parse<Exam>({
          'exam': examJson,
          'questions': questionsJson,
        }, (json) => _exam(json.object('exam'), json.object('questions').list('items', _question)));
    }
  }

  @override
  Future<Result<Exam>> createExam(ExamDetails details) async => MissingEndpoints.createDraftExam.refuse();

  @override
  Future<Result<Exam>> updateDetails(String id, ExamDetails details) async {
    // Title, description and duration exist. The rest has nowhere to go.
    if (details.courseName.trim().isNotEmpty ||
        details.instructions.trim().isNotEmpty ||
        details.passMarkPercent != 0) {
      return MissingEndpoints.examExtendedFields.refuse();
    }
    return _putExam(
      id,
      title: details.title.trim(),
      description: details.description.trim(),
      duration: details.durationMinutes,
    );
  }

  @override
  Future<Result<Exam>> updateSettings(String id, ExamSettings settings) async =>
      MissingEndpoints.examExtendedFields.refuse();

  @override
  Future<Result<Exam>> updateSchedule(String id, {required DateTime opensAt, required DateTime closesAt}) async {
    final current = await getExam(id);
    switch (current) {
      case Err<Exam>():
        return current;
      case Ok<Exam>(:final value):
        if (closesAt.difference(opensAt) != Duration(minutes: value.durationMinutes)) {
          return MissingEndpoints.availabilityWindow.refuse();
        }
        return _putExam(
          id,
          title: value.title,
          description: value.description,
          duration: value.durationMinutes,
          startsAt: opensAt,
        );
    }
  }

  @override
  Future<Result<Exam>> saveQuestion(String examId, Question question, {bool confirmsAnswerKey = false}) async {
    if (question.type == QuestionType.multipleChoice) return MissingEndpoints.multipleChoiceQuestions.refuse();
    if (question.topic != null || question.difficulty != null) return MissingEndpoints.questionMetadata.refuse();
    final body = {
      'type': question.type == QuestionType.shortText ? 'Essay' : 'Mcq',
      'text': question.text.trim(),
      'marks': question.marks,
      'modelAnswer': question.modelAnswer?.trim(),
      'options': question.type == QuestionType.shortText
          ? <Object>[]
          : [
              for (final option in question.options) {'text': option.text.trim(), 'isCorrect': option.isCorrect},
            ],
    };
    final existing = await _client.get('/api/exams/${_id(examId)}/questions');
    final bool exists;
    switch (existing) {
      case Err<Object?>(:final failure):
        return Err(failure);
      case Ok<Object?>(:final value):
        final parsed = JsonReader.parse<List<String>>(value, (json) => json.list('items', (item) => item.string('id')));
        switch (parsed) {
          case Err<List<String>>(:final failure):
            return Err(failure);
          case Ok<List<String>>(value: final ids):
            exists = ids.contains(question.id);
        }
    }
    final response = exists
        ? await _client.put('/api/questions/${_id(question.id)}', body: body)
        : await _client.post('/api/exams/${_id(examId)}/questions', body: body);
    return _afterWrite(response, examId);
  }

  @override
  Future<Result<Exam>> addQuestions(String examId, List<Question> questions) async =>
      MissingEndpoints.addQuestionsBatch.refuse();

  @override
  Future<Result<Exam>> deleteQuestion(String examId, String questionId) async {
    final response = await _client.delete('/api/questions/${_id(questionId)}');
    return _afterWrite(response, examId);
  }

  @override
  Future<Result<Exam>> moveQuestion(String examId, String questionId, int toIndex) async =>
      MissingEndpoints.reorderQuestions.refuse();

  @override
  Future<Result<Exam>> publish(String examId) async =>
      _afterWrite(await _client.post('/api/exams/${_id(examId)}/publish'), examId);

  @override
  Future<Result<Exam>> unpublish(String examId) async =>
      _afterWrite(await _client.post('/api/exams/${_id(examId)}/unpublish'), examId);

  @override
  Future<Result<Exam>> archive(String examId) async =>
      _afterWrite(await _client.post('/api/exams/${_id(examId)}/cancel'), examId);

  @override
  Future<Result<void>> deleteDraft(String examId) async {
    final response = await _client.delete('/api/exams/${_id(examId)}');
    return switch (response) {
      Ok<Object?>() => const Ok<void>(null),
      Err<Object?>(:final failure) => Err<void>(failure),
    };
  }

  /// `PUT /api/exams/{id}` replaces all four fields, so the current start time is kept unless a new one is given.
  Future<Result<Exam>> _putExam(
    String id, {
    required String title,
    required String description,
    required int duration,
    DateTime? startsAt,
  }) async {
    var start = startsAt;
    if (start == null) {
      final current = await getExam(id);
      switch (current) {
        case Err<Exam>():
          return current;
        case Ok<Exam>(:final value):
          start = value.opensAt;
      }
    }
    if (start == null) return MissingEndpoints.createDraftExam.refuse();
    final response = await _client.put(
      '/api/exams/${_id(id)}',
      body: {
        'title': title,
        'description': description.isEmpty ? null : description,
        'startsAt': start.toUtc().toIso8601String(),
        'durationMinutes': duration,
      },
    );
    return _afterWrite(response, id);
  }

  /// A write that succeeded: read the exam again, so what is shown is what the server holds.
  Future<Result<Exam>> _afterWrite(Result<Object?> response, String examId) async => switch (response) {
    Err<Object?>(:final failure) => Err<Exam>(failure),
    Ok<Object?>() => getExam(examId),
  };

  Result<T> _parse<T>(Result<Object?> response, T Function(JsonReader reader) build) => switch (response) {
    Ok<Object?>(:final value) => JsonReader.parse<T>(value, build),
    Err<Object?>(:final failure) => Err<T>(failure),
  };

  String _id(String id) => Uri.encodeComponent(id);

  /// The server's stored status names.
  static const Map<String, ExamLifecycle> _lifecycles = {
    'Draft': ExamLifecycle.draft,
    'Published': ExamLifecycle.published,
    'Cancelled': ExamLifecycle.archived,
  };

  /// The server's calculated phase names for a published exam.
  static const Map<String, ExamStatus> _phases = {
    'Upcoming': ExamStatus.scheduled,
    'Open': ExamStatus.ongoing,
    'Closed': ExamStatus.completed,
  };

  static ExamStatus _status(JsonReader json) {
    switch (json.enumValue('status', _lifecycles)) {
      case ExamLifecycle.draft:
        return ExamStatus.draft;
      case ExamLifecycle.archived:
        return ExamStatus.archived;
      case ExamLifecycle.published:
        return json.enumValue('phase', _phases);
    }
  }

  static ExamSummary _summary(JsonReader json) => ExamSummary(
    id: json.string('id'),
    title: json.string('title'),
    durationMinutes: json.integer('durationMinutes'),
    status: _status(json),
    version: Exam.unversioned,
    opensAt: json.dateTime('startsAt'),
    closesAt: json.dateTime('endsAt'),
  );

  static Exam _exam(JsonReader json, List<Question> questions) => Exam(
    id: json.string('id'),
    ownerId: '',
    title: json.string('title'),
    courseName: '',
    description: json.optionalString('description') ?? '',
    instructions: '',
    durationMinutes: json.integer('durationMinutes'),
    opensAt: json.dateTime('startsAt'),
    closesAt: json.dateTime('endsAt'),
    settings: const ExamSettings(),
    version: Exam.unversioned,
    lifecycle: json.enumValue('status', _lifecycles),
    publishedAt: json.optionalDateTime('publishedAt'),
    questions: questions,
  );

  static Question _question(JsonReader json) {
    return Question(
      id: json.string('id'),
      type: json.enumValue('type', const {'Mcq': QuestionType.singleChoice, 'Essay': QuestionType.shortText}),
      text: json.string('text'),
      marks: json.number('marks'),
      modelAnswer: json.optionalString('modelAnswer'),
      options: json.list(
        'options',
        (option) => QuestionOption(
          id: option.string('id'),
          text: option.string('text'),
          isCorrect: option.boolean('isCorrect'),
        ),
      ),
    );
  }
}
