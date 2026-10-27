import 'dart:convert';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/network/api_client.dart';
import 'package:examora_app/core/network/api_tokens.dart';
import 'package:examora_app/core/network/missing_endpoints.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/features/exams/data/api_exam_repository.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/exam_fixtures.dart';
import '../../support/fake_clock.dart';

/// Pins the Api exam repository to the real .NET contract (`ExamsController`, `QuestionsController`), including what it
/// refuses because the server cannot store it.
void main() {
  late FakeClock clock;
  late ApiTokenStore tokenStore;
  late List<http.Request> requests;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 27, 9));
    tokenStore = ApiTokenStore(InMemorySecureStore());
    requests = [];
    await tokenStore.write(
      ApiTokens(
        accessToken: 'access-1',
        accessTokenExpiresAt: clock.now().add(const Duration(minutes: 15)),
        refreshToken: 'refresh-1',
        refreshTokenExpiresAt: clock.now().add(const Duration(days: 7)),
      ),
    );
  });

  ApiExamRepository repositoryAnswering(http.Response Function(http.Request request) answer) {
    final client = ApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      baseUrl: 'https://api.test',
      tokens: tokenStore,
      clock: clock,
    );
    return ApiExamRepository(client: client);
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Map<String, Object?> examJson({String status = 'Draft', String phase = 'Upcoming', String? description = 'About'}) =>
      {
        'id': 'e1',
        'title': 'Algorithms midterm',
        'description': description,
        'startsAt': '2026-11-01T09:00:00Z',
        'durationMinutes': 60,
        'endsAt': '2026-11-01T10:00:00Z',
        'status': status,
        'phase': phase,
        'warningLimit': 20,
        'publishedAt': status == 'Published' ? '2026-10-27T09:00:00Z' : null,
      };

  Map<String, Object?> mcqJson({String id = 'q1'}) => {
    'id': id,
    'examId': 'e1',
    'type': 'Mcq',
    'text': 'What is 2 + 2?',
    'marks': 1.5,
    'modelAnswer': null,
    'position': 1,
    'options': [
      {'id': 'o1', 'text': '3', 'isCorrect': false, 'position': 1},
      {'id': 'o2', 'text': '4', 'isCorrect': true, 'position': 2},
    ],
  };

  Map<String, Object?> essayJson() => {
    'id': 'q2',
    'examId': 'e1',
    'type': 'Essay',
    'text': 'Explain recursion.',
    'marks': 5,
    'modelAnswer': 'A function calling itself.',
    'position': 2,
    'options': <Object>[],
  };

  http.Response routes(http.Request request) {
    final key = '${request.method} ${request.url.path}';
    return switch (key) {
      'GET /api/exams/e1' => json(examJson()),
      'GET /api/exams/e1/questions' => json({
        'items': [mcqJson(), essayJson()],
      }),
      _ => http.Response('', 204),
    };
  }

  group('listing', () {
    test('sends status, page and pageSize and maps the rows without inventing a course or a question count', () async {
      final repository = repositoryAnswering(
        (_) => json({
          'items': [examJson(status: 'Published', phase: 'Open'), examJson(status: 'Cancelled'), examJson()],
          'page': 2,
          'pageSize': 3,
          'totalCount': 9,
        }),
      );
      final page = ok(await repository.listExams(status: ExamStatus.draft, page: 2, pageSize: 3));
      expect(requests.single.url.path, '/api/exams');
      expect(requests.single.url.queryParameters, {'status': 'Draft', 'page': '2', 'pageSize': '3'});
      expect(requests.single.headers['Authorization'], 'Bearer access-1');
      expect(page.items.map((e) => e.status), [ExamStatus.ongoing, ExamStatus.archived, ExamStatus.draft]);
      expect(page.items.first.courseName, isNull);
      expect(page.items.first.questionCount, isNull);
      expect(page.items.first.version, Exam.unversioned);
      expect(page.totalCount, 9);
      expect(page.hasNext, isTrue);
    });

    test('archived is sent as the server\'s Cancelled; no filter sends none', () async {
      final repository = repositoryAnswering(
        (_) => json({'items': <Object>[], 'page': 1, 'pageSize': 10, 'totalCount': 0}),
      );
      ok(await repository.listExams(status: ExamStatus.archived));
      expect(requests.last.url.queryParameters['status'], 'Cancelled');
      ok(await repository.listExams());
      expect(requests.last.url.queryParameters.containsKey('status'), isFalse);
    });

    test('Scheduled, Ongoing and Completed are refused by name: the server filters stored status only', () async {
      final repository = repositoryAnswering((_) => fail('no request expected'));
      for (final status in [ExamStatus.scheduled, ExamStatus.ongoing, ExamStatus.completed]) {
        final failure = err(await repository.listExams(status: status));
        expect(failure, isA<EndpointMissingFailure>());
        expect((failure as EndpointMissingFailure).endpoint, MissingEndpoints.listExamsByPhase.endpoint);
      }
      expect(requests, isEmpty);
    });

    test('an unrecognised phase is a parse error, not a guess', () async {
      final repository = repositoryAnswering(
        (_) => json({
          'items': [examJson(status: 'Published', phase: 'Weird')],
          'page': 1,
          'pageSize': 10,
          'totalCount': 1,
        }),
      );
      expect((err(await repository.listExams()) as ParseFailure).field, 'items[0].phase');
    });
  });

  group('reading one exam', () {
    test('reads the exam and its questions; what the server does not store stays empty', () async {
      final repository = repositoryAnswering(routes);
      final exam = ok(await repository.getExam('e1'));
      expect(requests.map((r) => '${r.method} ${r.url.path}'), ['GET /api/exams/e1', 'GET /api/exams/e1/questions']);
      expect(exam.title, 'Algorithms midterm');
      expect(exam.opensAt, DateTime.utc(2026, 11, 1, 9));
      expect(exam.closesAt, DateTime.utc(2026, 11, 1, 10));
      expect(exam.courseName, isEmpty);
      expect(exam.instructions, isEmpty);
      expect(exam.passMarkPercent, isNull);
      expect(exam.version, Exam.unversioned);
      expect(exam.createdAt, isNull);
      expect(exam.settings, const ExamSettings());
      expect(exam.questions.map((q) => q.type), [QuestionType.singleChoice, QuestionType.shortText]);
      expect(exam.questions.first.marks, 1.5);
      expect(exam.questions.first.correctOptionIds, {'o2'});
      expect(exam.questions.last.modelAnswer, 'A function calling itself.');
      expect(exam.lifecycle, ExamLifecycle.draft);
    });

    test('404 and 403 map to typed failures', () async {
      final notFound = repositoryAnswering(
        (_) => http.Response(
          jsonEncode({'status': 404, 'code': 'exam_not_found', 'detail': 'x'}),
          404,
          headers: {'content-type': 'application/problem+json'},
        ),
      );
      expect(err(await notFound.getExam('e1')), isA<NotFoundFailure>());
    });
  });

  group('writing', () {
    test(
      'creating a draft is refused by name: POST /api/exams needs a start time the wizard does not have yet',
      () async {
        final repository = repositoryAnswering((_) => fail('no request expected'));
        final failure = err(await repository.createExam(details()));
        expect(failure, isA<EndpointMissingFailure>());
        expect((failure as EndpointMissingFailure).endpoint, MissingEndpoints.createDraftExam.endpoint);
        expect(requests, isEmpty);
      },
    );

    test('course name, instructions or a pass mark are refused rather than silently dropped', () async {
      final repository = repositoryAnswering((_) => fail('no request expected'));
      final failure = err(await repository.updateDetails('e1', details()));
      expect((failure as EndpointMissingFailure).endpoint, MissingEndpoints.examExtendedFields.endpoint);
      expect(err(await repository.updateSettings('e1', const ExamSettings())), isA<EndpointMissingFailure>());
      expect(requests, isEmpty);
    });

    test(
      'title, description and duration are sent as PUT with the current start time, then the exam is read again',
      () async {
        final repository = repositoryAnswering((request) {
          if (request.method == 'PUT') return json(examJson());
          return routes(request);
        });
        ok(
          await repository.updateDetails(
            'e1',
            const ExamDetails(
              title: ' New title ',
              courseName: '',
              durationMinutes: 45,
              passMarkPercent: 0,
              description: ' Desc ',
            ),
          ),
        );
        final put = requests.firstWhere((r) => r.method == 'PUT');
        expect(put.url.path, '/api/exams/e1');
        expect(jsonDecode(put.body), {
          'title': 'New title',
          'description': 'Desc',
          'startsAt': '2026-11-01T09:00:00.000Z',
          'durationMinutes': 45,
        });
      },
    );

    test(
      'a schedule whose window equals the duration is a PUT of the start time; a longer window is refused by name',
      () async {
        final repository = repositoryAnswering(
          (request) => request.method == 'PUT' ? json(examJson()) : routes(request),
        );
        ok(
          await repository.updateSchedule(
            'e1',
            opensAt: DateTime.utc(2026, 12, 1, 9),
            closesAt: DateTime.utc(2026, 12, 1, 10),
          ),
        );
        expect(
          jsonDecode(requests.firstWhere((r) => r.method == 'PUT').body),
          containsPair('startsAt', '2026-12-01T09:00:00.000Z'),
        );

        final failure = err(
          await repository.updateSchedule(
            'e1',
            opensAt: DateTime.utc(2026, 12, 1, 9),
            closesAt: DateTime.utc(2026, 12, 1, 12),
          ),
        );
        expect((failure as EndpointMissingFailure).endpoint, MissingEndpoints.availabilityWindow.endpoint);
      },
    );

    test('publish, unpublish and cancel (archive) are POSTs with no body', () async {
      final repository = repositoryAnswering(
        (request) => request.method == 'POST' ? json(examJson(status: 'Published')) : routes(request),
      );
      ok(await repository.publish('e1'));
      ok(await repository.unpublish('e1'));
      ok(await repository.archive('e1'));
      expect(requests.where((r) => r.method == 'POST').map((r) => r.url.path), [
        '/api/exams/e1/publish',
        '/api/exams/e1/unpublish',
        '/api/exams/e1/cancel',
      ]);
      expect(requests.where((r) => r.method == 'POST').every((r) => r.body.isEmpty), isTrue);
    });

    test('a refused publish keeps the server\'s own explanation and code', () async {
      final repository = repositoryAnswering(
        (_) => http.Response(
          jsonEncode({
            'status': 409,
            'code': 'exam_not_publishable',
            'detail': 'Question 2 needs exactly one correct option.',
          }),
          409,
          headers: {'content-type': 'application/problem+json'},
        ),
      );
      final failure = err(await repository.publish('e1')) as ConflictFailure;
      expect(failure.code, 'exam_not_publishable');
      expect(failure.serverDetail, 'Question 2 needs exactly one correct option.');
    });

    test('deleting a draft is a DELETE', () async {
      final repository = repositoryAnswering((_) => http.Response('', 204));
      ok(await repository.deleteDraft('e1'));
      expect((requests.single.method, requests.single.url.path), ('DELETE', '/api/exams/e1'));
    });
  });

  group('questions', () {
    test(
      'a new single-choice question is POSTed as Mcq with its options in order, then the exam is read again',
      () async {
        final repository = repositoryAnswering(
          (request) => request.method == 'POST' ? json(mcqJson(), 201) : routes(request),
        );
        ok(
          await repository.saveQuestion(
            'e1',
            singleChoice(id: 'client-id', text: ' Capital? ', marks: 2, options: const ['Cairo', 'Rome'], correct: 0),
          ),
        );
        final post = requests.firstWhere((r) => r.method == 'POST');
        expect(post.url.path, '/api/exams/e1/questions');
        expect(jsonDecode(post.body), {
          'type': 'Mcq',
          'text': 'Capital?',
          'marks': 2,
          'modelAnswer': null,
          'options': [
            {'text': 'Cairo', 'isCorrect': true},
            {'text': 'Rome', 'isCorrect': false},
          ],
        });
      },
    );

    test('an existing question (its id is in the exam\'s list) is PUT to /api/questions/{id}', () async {
      final repository = repositoryAnswering((request) => request.method == 'PUT' ? json(mcqJson()) : routes(request));
      ok(await repository.saveQuestion('e1', singleChoice(id: 'q1')));
      final put = requests.firstWhere((r) => r.method == 'PUT');
      expect(put.url.path, '/api/questions/q1');
    });

    test('short text is an Essay with no options', () async {
      final repository = repositoryAnswering(
        (request) => request.method == 'POST' ? json(essayJson(), 201) : routes(request),
      );
      ok(await repository.saveQuestion('e1', shortText(id: 'new')));
      final body = jsonDecode(requests.firstWhere((r) => r.method == 'POST').body) as Map<String, Object?>;
      expect(body['type'], 'Essay');
      expect(body['options'], isEmpty);
      expect(body['modelAnswer'], 'A function calling itself.');
    });

    test('multiple choice, batch add and reordering are refused by name', () async {
      final repository = repositoryAnswering((_) => fail('no request expected'));
      expect(
        (err(await repository.saveQuestion('e1', multipleChoice())) as EndpointMissingFailure).endpoint,
        MissingEndpoints.multipleChoiceQuestions.endpoint,
      );
      expect(
        (err(await repository.addQuestions('e1', [singleChoice()])) as EndpointMissingFailure).endpoint,
        MissingEndpoints.addQuestionsBatch.endpoint,
      );
      expect(
        (err(await repository.moveQuestion('e1', 'q1', 0)) as EndpointMissingFailure).endpoint,
        MissingEndpoints.reorderQuestions.endpoint,
      );
      expect(requests, isEmpty);
    });

    test('deleting a question is a DELETE of /api/questions/{id}', () async {
      final repository = repositoryAnswering(
        (request) => request.method == 'DELETE' ? http.Response('', 204) : routes(request),
      );
      ok(await repository.deleteQuestion('e1', 'q1'));
      expect(requests.first.method, 'DELETE');
      expect(requests.first.url.path, '/api/questions/q1');
    });

    test('an unrecognised question type from the server is a parse error, never a default type', () async {
      final repository = repositoryAnswering((request) {
        if (request.url.path.endsWith('/questions')) {
          return json({
            'items': [mcqJson()..['type'] = 'TrueFalse'],
          });
        }
        return routes(request);
      });
      expect((err(await repository.getExam('e1')) as ParseFailure).field, contains('type'));
    });
  });

  test('every missing endpoint is in the one handover list, with no duplicates', () {
    final names = MissingEndpoints.all.map((e) => e.endpoint).toList();
    expect(names.toSet().length, names.length);
    for (final needed in [
      MissingEndpoints.createStudentAccount,
      MissingEndpoints.createDraftExam,
      MissingEndpoints.examExtendedFields,
      MissingEndpoints.availabilityWindow,
      MissingEndpoints.multipleChoiceQuestions,
      MissingEndpoints.addQuestionsBatch,
      MissingEndpoints.reorderQuestions,
      MissingEndpoints.listExamsByPhase,
    ]) {
      expect(MissingEndpoints.all, contains(needed));
      expect(needed.reason, isNotEmpty);
    }
  });
}
