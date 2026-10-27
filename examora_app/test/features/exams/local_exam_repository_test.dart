import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_auth_repository.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exams/data/local_exam_repository.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';
import '../../support/test_harness.dart';

void main() {
  late TestEnvironment env;
  late LocalAccountStore accounts;
  late LocalAuthRepository auth;
  late LocalSessionStore sessions;
  late JsonCollectionStore<Exam> store;
  late LocalExamRepository exams;
  var hasAttempts = false;

  final opens = DateTime.utc(2026, 11, 1, 9);
  final closes = DateTime.utc(2026, 11, 1, 12);

  LocalExamRepository buildRepository() => LocalExamRepository(
    exams: store,
    caller: LocalCaller(accounts: accounts, sessions: sessions, clock: env.clock),
    clock: env.clock,
    hasAttempts: (_) async => hasAttempts,
  );

  setUp(() async {
    env = TestEnvironment(now: DateTime.utc(2026, 10, 27, 9));
    hasAttempts = false;
    accounts = LocalAccountStore(store: env.keyValueStore, hasher: TestEnvironment.fastHasher, clock: env.clock);
    sessions = LocalSessionStore(env.secureStore);
    auth = LocalAuthRepository(
      accounts: accounts,
      sessions: sessions,
      hasher: TestEnvironment.fastHasher,
      clock: env.clock,
    );
    store = JsonCollectionStore<Exam>(
      store: env.keyValueStore,
      key: 'local.exams.v1',
      fromJson: Exam.fromJson,
      toJson: (exam) => exam.toJson(),
    );
    exams = buildRepository();
    ok(await auth.signIn(email: 'instructor@examora.app', password: 'Examora#2026'));
  });

  /// Moves the clock and signs in again (a session lasts 12 hours, so a long jump ends it).
  Future<void> travelTo(DateTime moment) async {
    env.clock.setTo(moment);
    await auth.signOut();
    ok(await auth.signIn(email: 'instructor@examora.app', password: 'Examora#2026'));
  }

  Future<Exam> readyDraft() async {
    final created = ok(await exams.createExam(details()));
    ok(await exams.saveQuestion(created.id, singleChoice(), confirmsAnswerKey: true));
    return ok(await exams.updateSchedule(created.id, opensAt: opens, closesAt: closes));
  }

  Future<void> signInAnotherInstructor() async {
    final hash = await TestEnvironment.fastHasher.hash('Examora#2026');
    await accounts.mutate((all) {
      all.add(
        StoredAccount(
          id: 'other-instructor',
          fullName: 'Other Instructor',
          email: 'other@examora.app',
          role: UserRole.instructor,
          passwordHash: hash,
          mustChangePassword: false,
          status: AccountStatus.active,
          createdAt: env.clock.now(),
        ),
      );
    });
    await auth.signOut();
    ok(await auth.signIn(email: 'other@examora.app', password: 'Examora#2026'));
  }

  group('who may use it', () {
    test('students and administrators are forbidden, and a signed-out caller has no session', () async {
      for (final email in ['student@examora.app', 'admin@examora.app']) {
        await auth.signOut();
        ok(await auth.signIn(email: email, password: 'Examora#2026'));
        expect(err(await exams.listExams()), isA<ForbiddenFailure>(), reason: email);
        expect(err(await exams.createExam(details())), isA<ForbiddenFailure>(), reason: email);
      }
      await auth.signOut();
      expect(err(await exams.listExams()), isA<SessionExpiredFailure>());
    });

    test(
      'an instructor cannot read, change, publish or delete another instructor\'s exam: it is "not found"',
      () async {
        final mine = await readyDraft();
        await signInAnotherInstructor();

        expect(err(await exams.getExam(mine.id)), isA<NotFoundFailure>());
        expect(err(await exams.updateDetails(mine.id, details(title: 'Hijacked'))), isA<NotFoundFailure>());
        expect(err(await exams.saveQuestion(mine.id, singleChoice(id: 'evil'))), isA<NotFoundFailure>());
        expect(err(await exams.deleteQuestion(mine.id, 'q1')), isA<NotFoundFailure>());
        expect(err(await exams.publish(mine.id)), isA<NotFoundFailure>());
        expect(err(await exams.deleteDraft(mine.id)), isA<NotFoundFailure>());
        expect(ok(await exams.listExams()).items, isEmpty);

        // Nothing about the exam changed.
        await auth.signOut();
        ok(await auth.signIn(email: 'instructor@examora.app', password: 'Examora#2026'));
        final still = ok(await exams.getExam(mine.id));
        expect(still.title, 'Algorithms midterm');
        expect(still.questions.length, 1);
        expect(still.lifecycle, ExamLifecycle.draft);
      },
    );
  });

  group('creating and listing', () {
    test('creates a draft with the documented defaults and version 1', () async {
      final exam = ok(await exams.createExam(details(title: '  Midterm  ')));
      expect(exam.title, 'Midterm');
      expect(exam.lifecycle, ExamLifecycle.draft);
      expect(exam.version, 1);
      expect(exam.questions, isEmpty);
      expect(exam.settings, const ExamSettings());
      expect(exam.opensAt, isNull);
      expect(exam.statusAt(env.clock.now()), ExamStatus.draft);
      expect((await accounts.findByEmail('instructor@examora.app'))!.id, exam.ownerId);
    });

    test('refuses invalid details by field and saves nothing', () async {
      final failure = err(await exams.createExam(details(title: '', minutes: 0)));
      expect((failure as ValidationFailure).fields.keys, unorderedEquals(['title', 'durationMinutes']));
      expect(ok(await exams.listExams()).totalCount, 0);
    });

    test('lists only my exams, newest first, filtered by derived status, and paged', () async {
      final first = ok(await exams.createExam(details(title: 'First')));
      env.clock.advance(const Duration(minutes: 1));
      final second = ok(await exams.createExam(details(title: 'Second')));
      env.clock.advance(const Duration(minutes: 1));
      ok(await exams.createExam(details(title: 'Third')));

      final all = ok(await exams.listExams());
      expect(all.items.map((e) => e.title), ['Third', 'Second', 'First']);
      expect(all.items.first.questionCount, 0);

      expect(ok(await exams.listExams(pageSize: 2)).items.map((e) => e.title), ['Third', 'Second']);
      expect(ok(await exams.listExams(page: 2, pageSize: 2)).items.map((e) => e.title), ['First']);
      expect(ok(await exams.listExams(page: 2, pageSize: 2)).totalCount, 3);
      expect(err(await exams.listExams(page: 0)), isA<ValidationFailure>());

      ok(await exams.saveQuestion(second.id, singleChoice(), confirmsAnswerKey: true));
      ok(await exams.updateSchedule(second.id, opensAt: opens, closesAt: closes));
      ok(await exams.publish(second.id));
      expect(ok(await exams.listExams(status: ExamStatus.draft)).items.map((e) => e.title), ['Third', 'First']);
      expect(ok(await exams.listExams(status: ExamStatus.scheduled)).items.map((e) => e.title), ['Second']);
      expect(ok(await exams.listExams(status: ExamStatus.ongoing)).items, isEmpty);

      await travelTo(opens.add(const Duration(minutes: 1)));
      expect(ok(await exams.listExams(status: ExamStatus.ongoing)).items.map((e) => e.title), ['Second']);
      await travelTo(closes);
      expect(ok(await exams.listExams(status: ExamStatus.completed)).items.map((e) => e.title), ['Second']);
      expect(first.id, isNotEmpty);
    });

    test('an exam survives a restart: it is read back from storage', () async {
      final exam = await readyDraft();
      final fresh = buildRepository();
      expect(ok(await fresh.getExam(exam.id)).toJson(), ok(await exams.getExam(exam.id)).toJson());
    });
  });

  group('questions', () {
    late Exam exam;
    setUp(() async => exam = ok(await exams.createExam(details())));

    test('adds, replaces in place, moves and deletes', () async {
      ok(await exams.saveQuestion(exam.id, singleChoice(id: 'a', text: 'First'), confirmsAnswerKey: true));
      ok(await exams.saveQuestion(exam.id, singleChoice(id: 'b', text: 'Second'), confirmsAnswerKey: true));
      ok(await exams.saveQuestion(exam.id, multipleChoice(id: 'c', text: 'Third'), confirmsAnswerKey: true));
      expect(ok(await exams.getExam(exam.id)).questions.map((q) => q.text), ['First', 'Second', 'Third']);

      ok(await exams.saveQuestion(exam.id, singleChoice(id: 'b', text: 'Second, edited'), confirmsAnswerKey: true));
      expect(ok(await exams.getExam(exam.id)).questions.map((q) => q.text), ['First', 'Second, edited', 'Third']);

      final moved = ok(await exams.moveQuestion(exam.id, 'c', 0));
      expect(moved.questions.map((q) => q.id), ['c', 'a', 'b']);
      expect(err(await exams.moveQuestion(exam.id, 'c', 3)), isA<ValidationFailure>());
      expect(err(await exams.moveQuestion(exam.id, 'zzz', 0)), isA<NotFoundFailure>());

      final after = ok(await exams.deleteQuestion(exam.id, 'a'));
      expect(after.questions.map((q) => q.id), ['c', 'b']);
      expect(err(await exams.deleteQuestion(exam.id, 'a')), isA<NotFoundFailure>());
    });

    test('refuses an invalid question with every problem, and saves nothing', () async {
      final bad = singleChoice(text: '', marks: 0, options: const ['x']);
      final failure = err(await exams.saveQuestion(exam.id, bad));
      expect(
        (failure as QuestionInvalidFailure).problems,
        containsAll([QuestionProblem.noText, QuestionProblem.invalidMarks, QuestionProblem.tooFewOptions]),
      );
      expect(ok(await exams.getExam(exam.id)).questions, isEmpty);
    });

    test('trims text, drops a blank model answer and clears options from a short-text question', () async {
      final saved = ok(
        await exams.saveQuestion(
          exam.id,
          shortText(id: 's').copyWith(
            text: '  Explain.  ',
            modelAnswer: (value: '   '),
            explanation: (value: ' Because. '),
            options: singleChoice().options,
          ),
        ),
      );
      final question = saved.questions.single;
      expect(question.text, 'Explain.');
      expect(question.modelAnswer, isNull);
      expect(question.explanation, 'Because.');
      expect(question.options, isEmpty);
    });

    test('keeps option ids stable across an edit', () async {
      ok(await exams.saveQuestion(exam.id, singleChoice(), confirmsAnswerKey: true));
      final edited = singleChoice().copyWith(text: 'New wording');
      final saved = ok(await exams.saveQuestion(exam.id, edited, confirmsAnswerKey: true));
      expect(saved.questions.single.options.map((o) => o.id), singleChoice().options.map((o) => o.id));
    });

    test('flags a stale answer key when options change under a fixed answer, and a confirmation clears it', () async {
      ok(await exams.saveQuestion(exam.id, singleChoice(), confirmsAnswerKey: true));
      final original = singleChoice();
      final reworded = original.copyWith(
        options: [
          original.options[0],
          original.options[1].copyWith(text: 'four'),
          ...original.options.skip(2),
        ],
      );

      var saved = ok(await exams.saveQuestion(exam.id, reworded));
      expect(saved.questions.single.answerKeyStale, isTrue);

      // Saving the same stale question again does not clear it.
      saved = ok(await exams.saveQuestion(exam.id, saved.questions.single.copyWith(text: 'Still stale?')));
      expect(saved.questions.single.answerKeyStale, isTrue);

      saved = ok(await exams.saveQuestion(exam.id, saved.questions.single, confirmsAnswerKey: true));
      expect(saved.questions.single.answerKeyStale, isFalse);
    });

    test('addQuestions is all-or-nothing and refuses an id that already exists', () async {
      ok(await exams.saveQuestion(exam.id, singleChoice(id: 'a'), confirmsAnswerKey: true));
      final bad = singleChoice(id: 'bad', text: '');
      expect(err(await exams.addQuestions(exam.id, [singleChoice(id: 'ok1'), bad])), isA<QuestionInvalidFailure>());
      expect(ok(await exams.getExam(exam.id)).questions.length, 1);
      expect(err(await exams.addQuestions(exam.id, [singleChoice(id: 'a')])).code, 'question_exists');

      final added = ok(await exams.addQuestions(exam.id, [singleChoice(id: 'n1'), shortText(id: 'n2')]));
      expect(added.questions.map((q) => q.id), ['a', 'n1', 'n2']);
    });
  });

  group('settings and schedule', () {
    test('settings are validated and saved', () async {
      final exam = ok(await exams.createExam(details()));
      const settings = ExamSettings(randomizeOptions: true, calculatorEnabled: true, sustainedThresholdSeconds: 20);
      expect(ok(await exams.updateSettings(exam.id, settings)).settings, settings);
      expect(err(await exams.updateSettings(exam.id, const ExamSettings(maxWarnings: 99))), isA<ValidationFailure>());
      expect(ok(await exams.getExam(exam.id)).settings, settings);
    });

    test('the window must be at least the duration, and is stored in UTC', () async {
      final exam = ok(await exams.createExam(details()));
      expect(
        err(await exams.updateSchedule(exam.id, opensAt: opens, closesAt: opens.add(const Duration(minutes: 30)))),
        isA<ValidationFailure>(),
      );
      final saved = ok(await exams.updateSchedule(exam.id, opensAt: opens.toLocal(), closesAt: closes.toLocal()));
      expect(saved.opensAt, opens);
      expect(saved.opensAt!.isUtc, isTrue);
    });
  });

  group('publishing', () {
    test('publishes a ready exam, records when, and keeps version 1', () async {
      final ready = await readyDraft();
      final published = ok(await exams.publish(ready.id));
      expect(published.lifecycle, ExamLifecycle.published);
      expect(published.publishedAt, env.clock.now());
      expect(published.version, 1);
      expect(published.statusAt(env.clock.now()), ExamStatus.scheduled);
    });

    test('refuses with EVERY reason: nothing in the exam is ready', () async {
      final exam = ok(await exams.createExam(details()));
      final failure = err(await exams.publish(exam.id)) as ExamNotPublishableFailure;
      expect(failure.problems, [isA<NoQuestionsProblem>(), isA<ScheduleMissingProblem>()]);
      expect(ok(await exams.getExam(exam.id)).lifecycle, ExamLifecycle.draft);
    });

    test('refuses a flagged question, a stale answer key and a start time that has passed, each by name', () async {
      final exam = ok(await exams.createExam(details()));
      ok(await exams.addQuestions(exam.id, [singleChoice(id: 'a', needsReview: true)]));
      ok(await exams.saveQuestion(exam.id, singleChoice(id: 'b'), confirmsAnswerKey: true));
      final original = singleChoice(id: 'b');
      ok(
        await exams.saveQuestion(
          exam.id,
          original.copyWith(
            options: [
              original.options[0],
              original.options[1].copyWith(text: 'four'),
              ...original.options.skip(2),
            ],
          ),
        ),
      );
      ok(await exams.updateSchedule(exam.id, opensAt: opens, closesAt: closes));
      await travelTo(opens.add(const Duration(minutes: 5)));

      final failure = err(await exams.publish(exam.id)) as ExamNotPublishableFailure;
      final problems = failure.problems;
      expect(problems.whereType<QuestionPublishProblem>().map((p) => (p.position, p.problem)), [
        (1, QuestionProblem.flaggedForReview),
        (2, QuestionProblem.answerKeyStale),
      ]);
      expect(problems.whereType<StartTimePassedProblem>(), hasLength(1));
    });

    test('opening a flagged question and saving it clears the flag, so the exam can then be published', () async {
      final exam = ok(await exams.createExam(details()));
      ok(await exams.addQuestions(exam.id, [singleChoice(needsReview: true)]));
      ok(await exams.updateSchedule(exam.id, opensAt: opens, closesAt: closes));
      expect(err(await exams.publish(exam.id)), isA<ExamNotPublishableFailure>());
      ok(await exams.saveQuestion(exam.id, singleChoice(), confirmsAnswerKey: true));
      expect(ok(await exams.publish(exam.id)).lifecycle, ExamLifecycle.published);
    });

    test('cannot be published twice or after archiving', () async {
      final ready = await readyDraft();
      ok(await exams.publish(ready.id));
      expect(err(await exams.publish(ready.id)).code, 'exam_already_published');
      ok(await exams.archive(ready.id));
      expect(err(await exams.publish(ready.id)).code, 'exam_archived');
    });

    test('unpublish returns it to a draft only before it opens and while it has no attempts', () async {
      final ready = await readyDraft();
      ok(await exams.publish(ready.id));

      hasAttempts = true;
      expect(err(await exams.unpublish(ready.id)).code, 'exam_not_unpublishable');
      hasAttempts = false;

      final back = ok(await exams.unpublish(ready.id));
      expect(back.lifecycle, ExamLifecycle.draft);
      expect(back.publishedAt, isNull);

      ok(await exams.publish(ready.id));
      await travelTo(opens);
      expect(err(await exams.unpublish(ready.id)).code, 'exam_not_unpublishable');
    });

    test('a draft cannot be archived; only a published exam can', () async {
      final ready = await readyDraft();
      expect(err(await exams.archive(ready.id)).code, 'exam_not_archivable');
      ok(await exams.publish(ready.id));
      final archived = ok(await exams.archive(ready.id));
      expect(archived.statusAt(env.clock.now()), ExamStatus.archived);
      expect(archived.archivedAt, env.clock.now());
    });
  });

  group('editing after publishing', () {
    late Exam published;
    setUp(() async {
      published = await readyDraft();
      published = ok(await exams.publish(published.id));
    });

    test('before it opens, a change a student sees raises the version by one', () async {
      final changed = ok(await exams.updateDetails(published.id, details(title: 'Algorithms midterm (revised)')));
      expect(changed.version, 2);
      final again = ok(
        await exams.saveQuestion(
          published.id,
          singleChoice(text: 'What is 2 + 3?', correct: 2),
          confirmsAnswerKey: true,
        ),
      );
      expect(again.version, 3);
    });

    test('a save that changes nothing a student sees leaves the version alone', () async {
      final same = ok(await exams.updateDetails(published.id, details()));
      expect(same.version, 1);
      final schedule = ok(await exams.updateSchedule(published.id, opensAt: opens, closesAt: closes));
      expect(schedule.version, 1);
    });

    test('changing the settings or the schedule counts as a student-visible change', () async {
      expect(ok(await exams.updateSettings(published.id, const ExamSettings(calculatorEnabled: true))).version, 2);
      expect(
        ok(
          await exams.updateSchedule(
            published.id,
            opensAt: opens.add(const Duration(hours: 1)),
            closesAt: closes.add(const Duration(hours: 1)),
          ),
        ).version,
        3,
      );
    });

    test('while it is a draft, edits never change the version', () async {
      final draft = await readyDraft();
      ok(await exams.updateDetails(draft.id, details(title: 'A')));
      ok(await exams.updateDetails(draft.id, details(title: 'B')));
      expect(ok(await exams.getExam(draft.id)).version, 1);
    });

    test('once it has opened or been archived, nothing can change it', () async {
      await travelTo(opens.add(const Duration(minutes: 1)));
      expect(err(await exams.updateDetails(published.id, details(title: 'Late'))).code, 'exam_not_editable');
      expect(err(await exams.saveQuestion(published.id, singleChoice(id: 'late'))).code, 'exam_not_editable');
      expect(err(await exams.updateSettings(published.id, const ExamSettings())).code, 'exam_not_editable');
      expect(ok(await exams.getExam(published.id)).title, 'Algorithms midterm');

      await travelTo(DateTime.utc(2026, 10, 28));
      ok(await exams.archive(published.id));
      expect(err(await exams.updateDetails(published.id, details(title: 'Archived edit'))).code, 'exam_not_editable');
    });
  });

  group('deleting', () {
    test('a draft is deleted with its questions; a published exam never is', () async {
      final draft = await readyDraft();
      ok(await exams.deleteDraft(draft.id));
      expect(err(await exams.getExam(draft.id)), isA<NotFoundFailure>());

      final published = ok(await exams.publish((await readyDraft()).id));
      expect(err(await exams.deleteDraft(published.id)).code, 'exam_not_deletable');
      expect(ok(await exams.getExam(published.id)).lifecycle, ExamLifecycle.published);
    });

    test('an unknown id is not found', () async {
      expect(err(await exams.deleteDraft('nope')), isA<NotFoundFailure>());
    });
  });

  test('storage trouble is a StorageFailure, never an exception', () async {
    env.keyValueStore.values['local.exams.v1'] = 'not json at all';
    expect(err(await exams.listExams()), isA<StorageFailure>());
  });

  test('two simultaneous question saves both land', () async {
    final exam = ok(await exams.createExam(details()));
    await Future.wait([
      exams.saveQuestion(exam.id, singleChoice(id: 'a'), confirmsAnswerKey: true),
      exams.saveQuestion(exam.id, singleChoice(id: 'b'), confirmsAnswerKey: true),
      exams.saveQuestion(exam.id, shortText(id: 'c')),
    ]);
    expect((await exams.getExam(exam.id)).valueOrNull!.questions.map((q) => q.id), unorderedEquals(['a', 'b', 'c']));
  });

  test('marks add up across question types', () async {
    final exam = ok(await exams.createExam(details()));
    ok(await exams.addQuestions(exam.id, [singleChoice(marks: 1.5), multipleChoice(marks: 2.25), shortText(marks: 5)]));
    expect(ok(await exams.getExam(exam.id)).totalMarks, closeTo(8.75, 1e-9));
  });
}
