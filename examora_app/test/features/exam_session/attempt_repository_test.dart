import 'dart:math';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';
import '../../support/session_scenario.dart';

void main() {
  late SessionScenario s;

  setUp(() async => s = await SessionScenario.create());

  const student = 'student@examora.app';
  const other = 'student2@examora.app';

  Future<StudentAttemptSession> begin(Exam exam, {String email = student}) async {
    await s.openWindowAndConsent(exam.id, student: email);
    return ok(await s.attempts.startAttempt(exam.id));
  }

  ChoiceAnswer pick(StudentAttemptSession session, int questionIndex, Iterable<int> optionIndexes) {
    final question = session.questions[questionIndex];
    return ChoiceAnswer({for (final index in optionIndexes) question.options[index].id});
  }

  group('what a student can see', () {
    test('only PUBLISHED exams are listed; a draft is invisible and "not found"', () async {
      final published = await s.publishedExam();
      final draft = ok(await s.exams.createExam(details(title: 'Secret draft')));
      await s.signInAs(student);
      final list = ok(await s.studentExams.listExams());
      expect(list.map((e) => e.id), [published.id]);
      expect(err(await s.studentExams.getExam(draft.id)), isA<NotFoundFailure>());
    });

    test('an archived exam is not shown', () async {
      final exam = await s.publishedExam();
      ok(await s.exams.archive(exam.id));
      await s.signInAs(student);
      expect(ok(await s.studentExams.listExams()), isEmpty);
      expect(err(await s.studentExams.getExam(exam.id)), isA<NotFoundFailure>());
    });

    test(
      'the briefing has the exam\'s rules in the student\'s own type, and inactive rules are listed separately',
      () async {
        final exam = await s.publishedExam(
          settings: const ExamSettings(
            calculatorEnabled: true,
            allowBackwardNavigation: false,
            randomizeOptions: true,
            enabledRules: {IncidentCategory.appBackgrounded, IncidentCategory.gazeAway},
          ),
        );
        await s.signInAs(student);
        final info = ok(await s.studentExams.getExam(exam.id));
        expect(info.calculatorEnabled, isTrue);
        expect(info.allowBackwardNavigation, isFalse);
        expect(info.randomizeOptions, isTrue);
        expect(info.questionCount, 3);
        expect(info.totalMarks, 8);
        expect(info.activeRules, {IncidentCategory.appBackgrounded});
        expect(info.inactiveRules, {IncidentCategory.gazeAway});
        expect(info.attemptState, AttemptState.notStarted);
        expect(info.status, ExamStatus.scheduled);
      },
    );

    test('instructors and administrators cannot use the student repositories', () async {
      final exam = await s.publishedExam();
      for (final email in ['instructor@examora.app', 'admin@examora.app']) {
        await s.signInAs(email);
        expect(err(await s.studentExams.listExams()), isA<ForbiddenFailure>(), reason: email);
        expect(err(await s.attempts.startAttempt(exam.id)), isA<ForbiddenFailure>(), reason: email);
        expect(err(await s.attempts.listResults()), isA<ForbiddenFailure>(), reason: email);
      }
    });
  });

  group('starting an attempt', () {
    test('needs the window to be open: not before it opens', () async {
      final exam = await s.publishedExam();
      await s.signInAs(student);
      ok(await s.attempts.recordConsent(exam.id));
      expect(err(await s.attempts.startAttempt(exam.id)).code, 'exam_not_open_yet');
    });

    test('needs the window to be open: not after it closed', () async {
      final exam = await s.publishedExam();
      await s.travelTo(s.opens.add(const Duration(minutes: 5)), email: student);
      ok(await s.attempts.recordConsent(exam.id));
      await s.travelTo(s.closes, email: student);
      expect(err(await s.attempts.startAttempt(exam.id)).code, 'exam_closed');
    });

    test('needs the student\'s CONSENT first', () async {
      final exam = await s.publishedExam();
      await s.travelTo(s.opens.add(const Duration(minutes: 5)), email: student);
      expect(ok(await s.attempts.hasConsent(exam.id)), isFalse);
      expect(err(await s.attempts.startAttempt(exam.id)).code, 'consent_required');
      ok(await s.attempts.recordConsent(exam.id));
      expect(ok(await s.attempts.hasConsent(exam.id)), isTrue);
      ok(await s.attempts.startAttempt(exam.id));
    });

    test('consent is the student\'s own: another student\'s consent does not count', () async {
      final exam = await s.publishedExam();
      await s.openWindowAndConsent(exam.id, student: other);
      await s.signInAs(student);
      expect(ok(await s.attempts.hasConsent(exam.id)), isFalse);
      expect(err(await s.attempts.startAttempt(exam.id)).code, 'consent_required');
    });

    test('begins with the deadline = start + duration, no answers, and the first question', () async {
      final exam = await s.publishedExam(minutes: 45);
      final session = await begin(exam);
      expect(session.startedAt, s.env.clock.now());
      expect(session.deadline, s.env.clock.now().add(const Duration(minutes: 45)));
      expect(session.answers, isEmpty);
      expect(session.currentIndex, 0);
      expect(session.status, AttemptStatus.inProgress);
      expect(session.questions, hasLength(3));
    });

    test('the deadline never goes past the window closing', () async {
      final exam = await s.publishedExam(minutes: 60);
      await s.travelTo(s.closes.subtract(const Duration(minutes: 10)), email: student);
      ok(await s.attempts.recordConsent(exam.id));
      final session = ok(await s.attempts.startAttempt(exam.id));
      expect(session.deadline, s.closes);
    });

    test('starting twice is one attempt (a double tap, or two windows)', () async {
      final exam = await s.publishedExam();
      await s.openWindowAndConsent(exam.id);
      final results = await Future.wait([s.attempts.startAttempt(exam.id), s.attempts.startAttempt(exam.id)]);
      expect(ok(results[0]).attemptId, ok(results[1]).attemptId);
      expect(await s.attemptStore.all(), hasLength(1));
    });

    test('RESUMING keeps the answers and the ORIGINAL deadline; it never extends the exam', () async {
      final exam = await s.publishedExam(minutes: 60);
      final first = await begin(exam);
      ok(await s.attempts.saveAnswer(first.attemptId, first.questions[0].id, pick(first, 0, [1])));
      ok(await s.attempts.saveProgress(first.attemptId, 2));

      s.env.clock.advance(const Duration(minutes: 20));
      await s.signInAs(student); // the app was closed and reopened
      final resumed = ok(await s.attempts.startAttempt(exam.id));
      expect(resumed.attemptId, first.attemptId);
      expect(resumed.deadline, first.deadline, reason: 'the deadline is fixed when the attempt begins');
      expect(resumed.answers[first.questions[0].id], pick(first, 0, [1]));
      expect(resumed.currentIndex, 2);
      expect(resumed.startedAt, first.startedAt);
    });

    test('a SUBMITTED attempt cannot be started again', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      ok(await s.attempts.submit(session.attemptId));
      expect(err(await s.attempts.startAttempt(exam.id)).code, 'attempt_already_submitted');
    });

    test(
      'an attempt can still be resumed after the window closed (so it can be finished off), but no new one can start',
      () async {
        final exam = await s.publishedExam();
        final session = await begin(exam);
        await s.travelTo(s.closes.add(const Duration(minutes: 1)), email: student);
        expect(ok(await s.attempts.startAttempt(exam.id)).attemptId, session.attemptId);
        await s.signInAs(other);
        expect(err(await s.attempts.startAttempt(exam.id)).code, anyOf('exam_closed', 'consent_required'));
      },
    );
  });

  group('the student\'s own types cannot carry an answer key', () {
    test('questions and options have no correct flag, model answer or explanation', () async {
      final exam = await s.publishedExam(
        questions: [
          singleChoice().copyWith(explanation: (value: 'because')),
          shortText(),
        ],
      );
      final session = await begin(exam);
      // StudentQuestion / StudentOption only have these members, none of which carries the key:
      final question = session.questions.first;
      expect(question.id, isNotEmpty);
      expect(question.options.map((o) => o.text), ['3', '4', '5', '6']);
      final text =
          '${session.questions.map((q) => '${q.id}${q.text}${q.type}${q.marks}${q.options.map((o) => '${o.id}${o.text}')}')}';
      expect(text.contains('because'), isFalse);
      expect(text.contains('A function calling itself'), isFalse, reason: 'the short-text model answer');
    });

    test('a student cannot reach the instructor-side exam repository or the instructor attempt views', () async {
      final exam = await s.publishedExam();
      await s.signInAs(student);
      expect(err(await s.exams.getExam(exam.id)), isA<ForbiddenFailure>());
      expect(err(await s.instructorAttempts.listForExam(exam.id)), isA<ForbiddenFailure>());
      expect(err(await s.instructorAttempts.getReview('whatever')), isA<ForbiddenFailure>());
      expect(err(await s.review.listQueue()), isA<ForbiddenFailure>());
    });
  });

  group('answers', () {
    test('every answer is saved at once and survives a restart', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      ok(await s.attempts.saveAnswer(session.attemptId, session.questions[0].id, pick(session, 0, [2])));
      ok(await s.attempts.saveAnswer(session.attemptId, session.questions[2].id, const TextAnswer('recursion is...')));
      final reloaded = ok(await s.attempts.getSession(session.attemptId));
      expect(reloaded.answers[session.questions[0].id], pick(session, 0, [2]));
      expect(reloaded.answers[session.questions[2].id], const TextAnswer('recursion is...'));
      expect(reloaded.answeredCount, 2);
      expect(reloaded.isAnswered(session.questions[1].id), isFalse);
    });

    test('an answer can be changed and cleared', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      final id = session.questions[0].id;
      ok(await s.attempts.saveAnswer(session.attemptId, id, pick(session, 0, [0])));
      ok(await s.attempts.saveAnswer(session.attemptId, id, pick(session, 0, [3])));
      expect(ok(await s.attempts.getSession(session.attemptId)).answers[id], pick(session, 0, [3]));
      ok(await s.attempts.saveAnswer(session.attemptId, id, null));
      expect(ok(await s.attempts.getSession(session.attemptId)).answers.containsKey(id), isFalse);
    });

    test(
      'answers are validated: unknown options, several options for single choice, the wrong kind, too long',
      () async {
        final exam = await s.publishedExam();
        final session = await begin(exam);
        final single = session.questions[0];
        expect(
          err(await s.attempts.saveAnswer(session.attemptId, single.id, const ChoiceAnswer({'ghost'}))),
          isA<ValidationFailure>(),
        );
        expect(
          err(await s.attempts.saveAnswer(session.attemptId, single.id, pick(session, 0, [0, 1]))),
          isA<ValidationFailure>(),
        );
        expect(
          err(await s.attempts.saveAnswer(session.attemptId, single.id, const TextAnswer('x'))),
          isA<ValidationFailure>(),
        );
        final text = session.questions[2];
        expect(
          err(await s.attempts.saveAnswer(session.attemptId, text.id, const ChoiceAnswer({'a'}))),
          isA<ValidationFailure>(),
        );
        expect(
          err(await s.attempts.saveAnswer(session.attemptId, text.id, TextAnswer('x' * (TextAnswer.maxLength + 1)))),
          isA<ValidationFailure>(),
        );
        expect(
          err(await s.attempts.saveAnswer(session.attemptId, 'no-such-question', const TextAnswer('x'))),
          isA<NotFoundFailure>(),
        );
        expect(ok(await s.attempts.getSession(session.attemptId)).answers, isEmpty);
      },
    );

    test('a multiple-choice answer may name several options', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      ok(await s.attempts.saveAnswer(session.attemptId, session.questions[1].id, pick(session, 1, [0, 2])));
    });

    test('answers are refused after the deadline', () async {
      final exam = await s.publishedExam(minutes: 30);
      final session = await begin(exam);
      s.env.clock.advance(const Duration(minutes: 30));
      expect(
        err(await s.attempts.saveAnswer(session.attemptId, session.questions[0].id, pick(session, 0, [1]))).code,
        'attempt_time_over',
      );
      expect(ok(await s.attempts.getSession(session.attemptId)).answers, isEmpty);
    });

    test('answers are refused after submitting', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      ok(await s.attempts.submit(session.attemptId));
      expect(
        err(await s.attempts.saveAnswer(session.attemptId, session.questions[0].id, pick(session, 0, [1]))).code,
        'attempt_already_submitted',
      );
    });

    test('progress is clamped to the questions that exist', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      ok(await s.attempts.saveProgress(session.attemptId, 99));
      expect(ok(await s.attempts.getSession(session.attemptId)).currentIndex, 2);
      ok(await s.attempts.saveProgress(session.attemptId, -4));
      expect(ok(await s.attempts.getSession(session.attemptId)).currentIndex, 0);
    });
  });

  group('the timer, at the repository: the deadline is the deadline', () {
    test('BACKGROUNDING gains nothing: coming back later, the attempt ends at the same instant', () async {
      final exam = await s.publishedExam(minutes: 60);
      final session = await begin(exam);
      ok(await s.attempts.saveProgress(session.attemptId, 0));
      s.env.clock.advance(const Duration(minutes: 50)); // the app was in the background
      final back = ok(await s.attempts.getSession(session.attemptId));
      expect(back.deadline, session.deadline);
      expect(back.deadline.difference(s.env.clock.now()), const Duration(minutes: 10));
    });

    test('turning the DEVICE CLOCK BACK gains nothing: saving first records how far the clock got', () async {
      final exam = await s.publishedExam(minutes: 60);
      final session = await begin(exam);
      s.env.clock.advance(const Duration(minutes: 40));
      ok(await s.attempts.saveAnswer(session.attemptId, session.questions[0].id, pick(session, 0, [1])));
      // The student sets the clock back to the start and tries to keep going.
      s.env.clock.setTo(session.startedAt);
      ok(await s.attempts.saveAnswer(session.attemptId, session.questions[0].id, pick(session, 0, [2])));
      s.env.clock.setTo(session.startedAt.add(const Duration(minutes: 5)));
      final stored = (await s.attemptStore.all()).single;
      expect(
        stored.lastSeenAt,
        session.startedAt.add(const Duration(minutes: 40)),
        reason: 'the floor does not go back',
      );
      // 25 minutes later by the (rewound) clock is only 30 minutes by the floor: 59 minutes later passes the deadline.
      s.env.clock.setTo(session.startedAt.add(const Duration(minutes: 5 + 55)));
      expect(
        err(await s.attempts.saveAnswer(session.attemptId, session.questions[0].id, pick(session, 0, [3]))).code,
        'attempt_time_over',
      );
    });

    test(
      'a student who opens the app after the deadline gets a submission AT the deadline, marked automatic',
      () async {
        final exam = await s.publishedExam(minutes: 30);
        final session = await begin(exam);
        ok(await s.attempts.saveAnswer(session.attemptId, session.questions[0].id, pick(session, 0, [1])));
        s.env.clock.advance(const Duration(hours: 2));
        await s.signInAs(student);
        final result = ok(await s.attempts.submit(session.attemptId, auto: true));
        expect(
          result.submittedAt,
          session.deadline,
          reason: 'the attempt ended when time ran out, not when the app noticed',
        );
        expect(result.submissionKind, SubmissionKind.auto);
      },
    );

    test('pressing Submit after the deadline is still an automatic submission at the deadline', () async {
      final exam = await s.publishedExam(minutes: 30);
      final session = await begin(exam);
      s.env.clock.advance(const Duration(minutes: 31));
      final result = ok(await s.attempts.submit(session.attemptId));
      expect(result.submittedAt, session.deadline);
      expect(result.submissionKind, SubmissionKind.auto);
    });
  });

  group('submitting', () {
    test('grades once and returns the result', () async {
      final exam = await s.publishedExam(passMark: 50);
      final session = await begin(exam);
      ok(
        await s.attempts.saveAnswer(
          session.attemptId,
          session.questions[0].id,
          ChoiceAnswer({_correctId(exam, session.questions[0].id)}),
        ),
      );
      final result = ok(await s.attempts.submit(session.attemptId));
      expect(result.visible, isTrue);
      expect(result.submissionKind, SubmissionKind.manual);
      expect(result.result!.awardedMarks, 1);
      expect(result.result!.totalMarks, 8);
    });

    test('SUBMITTING TWICE returns the ORIGINAL result and never grades again', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      final correct = ChoiceAnswer({_correctId(exam, session.questions[0].id)});
      ok(await s.attempts.saveAnswer(session.attemptId, session.questions[0].id, correct));
      final first = ok(await s.attempts.submit(session.attemptId));

      s.env.clock.advance(const Duration(minutes: 3));
      final second = ok(await s.attempts.submit(session.attemptId));
      final third = ok(await s.attempts.submit(session.attemptId, auto: true));
      expect(second.submittedAt, first.submittedAt);
      expect(third.submittedAt, first.submittedAt);
      expect(
        second.submissionKind,
        SubmissionKind.manual,
        reason: 'a later auto-submit must not rewrite how it was submitted',
      );
      expect(second.result!.toJson(), first.result!.toJson());
      expect(third.result!.toJson(), first.result!.toJson());
    });

    test('two submissions at the same moment are one', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      final results = await Future.wait([
        s.attempts.submit(session.attemptId),
        s.attempts.submit(session.attemptId, auto: true),
      ]);
      expect(ok(results[0]).submittedAt, ok(results[1]).submittedAt);
      expect(ok(results[0]).submissionKind, ok(results[1]).submissionKind);
    });

    test('all-or-nothing and manual marking are applied: typed answers wait, the pass/fail is withheld', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      ok(await s.attempts.saveAnswer(session.attemptId, session.questions[2].id, const TextAnswer('an essay')));
      final result = ok(await s.attempts.submit(session.attemptId)).result!;
      expect(result.pendingManualCount, 1);
      expect(result.passed, isNull);
    });

    test(
      'a held-back result: when the exam does not show results at once, nothing of it is sent until the window closes',
      () async {
        final exam = await s.publishedExam(
          settings: const ExamSettings(showResultImmediately: false, showExplanations: true),
        );
        final session = await begin(exam);
        final held = ok(await s.attempts.submit(session.attemptId));
        expect(held.visible, isFalse);
        expect(held.result, isNull, reason: 'a held-back result is not sent to the screen at all');
        expect(held.questionTexts, isEmpty);
        expect(held.explanations, isEmpty);
        expect(held.releaseAt, s.closes);

        await s.travelTo(s.closes, email: student);
        final released = ok(await s.attempts.getResult(session.attemptId));
        expect(released.visible, isTrue);
        expect(released.result, isNotNull);
      },
    );

    test('explanations travel with a visible result only when the exam shows them', () async {
      final question = singleChoice().copyWith(explanation: (value: 'Because 2 + 2 is 4.'));
      for (final shows in [true, false]) {
        final scenario = await SessionScenario.create();
        final exam = await scenario.publishedExam(
          questions: [question],
          settings: ExamSettings(showExplanations: shows),
        );
        await scenario.openWindowAndConsent(exam.id);
        final session = ok(await scenario.attempts.startAttempt(exam.id));
        final result = ok(await scenario.attempts.submit(session.attemptId));
        expect(result.explanations.isNotEmpty, shows);
      }
    });

    test('the result never shows which option was correct', () async {
      final exam = await s.publishedExam(questions: [singleChoice()]);
      final session = await begin(exam);
      final result = ok(await s.attempts.submit(session.attemptId));
      final dump = '${result.result!.toJson()}${result.questionTexts}${result.explanations}';
      for (final option in singleChoice().options) {
        expect(dump.contains(option.id), isFalse, reason: 'no option id is in a student\'s result');
      }
    });
  });

  group('results', () {
    test('listResults returns only this student\'s submitted attempts, newest first', () async {
      final first = await s.publishedExam();
      final second = await s.publishedExam();
      await s.openWindowAndConsent(first.id);
      ok(await s.attempts.recordConsent(second.id));
      final a = ok(await s.attempts.startAttempt(first.id));
      s.env.clock.advance(const Duration(minutes: 1));
      final b = ok(await s.attempts.startAttempt(second.id));
      ok(await s.attempts.submit(a.attemptId));
      s.env.clock.advance(const Duration(minutes: 1));
      ok(await s.attempts.submit(b.attemptId));
      expect(ok(await s.attempts.listResults()).map((r) => r.attemptId), [b.attemptId, a.attemptId]);

      await s.signInAs(other);
      expect(ok(await s.attempts.listResults()), isEmpty);
    });

    test('an attempt still in progress has no result', () async {
      final exam = await s.publishedExam();
      final session = await begin(exam);
      expect(err(await s.attempts.getResult(session.attemptId)), isA<NotFoundFailure>());
    });
  });

  group('SECURITY: a student cannot read or touch another student\'s attempt', () {
    test('every call on someone else\'s attempt answers "not found"', () async {
      final exam = await s.publishedExam();
      final mine = await begin(exam);
      ok(await s.attempts.saveAnswer(mine.attemptId, mine.questions[0].id, pick(mine, 0, [1])));
      ok(await s.attempts.submit(mine.attemptId));

      await s.signInAs(other);
      expect(err(await s.attempts.getSession(mine.attemptId)), isA<NotFoundFailure>());
      expect(err(await s.attempts.getResult(mine.attemptId)), isA<NotFoundFailure>());
      expect(err(await s.attempts.saveAnswer(mine.attemptId, mine.questions[0].id, null)), isA<NotFoundFailure>());
      expect(err(await s.attempts.saveProgress(mine.attemptId, 1)), isA<NotFoundFailure>());
      expect(err(await s.attempts.submit(mine.attemptId)), isA<NotFoundFailure>());
      expect(ok(await s.attempts.listResults()), isEmpty);
    });

    test('someone else\'s answers are not changed by a failed attempt to change them', () async {
      final exam = await s.publishedExam();
      final mine = await begin(exam);
      ok(await s.attempts.saveAnswer(mine.attemptId, mine.questions[0].id, pick(mine, 0, [1])));
      await s.signInAs(other);
      err(await s.attempts.saveAnswer(mine.attemptId, mine.questions[0].id, pick(mine, 0, [3])));
      await s.signInAs(student);
      expect(ok(await s.attempts.getSession(mine.attemptId)).answers[mine.questions[0].id], pick(mine, 0, [1]));
    });

    test('the second student starts their own attempt, independent of the first', () async {
      final exam = await s.publishedExam();
      final mine = await begin(exam);
      final theirs = await begin(exam, email: other);
      expect(theirs.attemptId, isNot(mine.attemptId));
    });
  });

  group('randomisation', () {
    test(
      'question order and option order are chosen once, kept for the attempt, and differ between students',
      () async {
        final questions = [for (var i = 0; i < 8; i++) singleChoice(id: 'q$i', text: 'Q$i')];
        final exam = await s.publishedExam(
          questions: questions,
          settings: const ExamSettings(randomizeQuestions: true, randomizeOptions: true),
        );
        final a = await begin(exam);
        final again = ok(await s.attempts.startAttempt(exam.id));
        expect(again.questions.map((q) => q.id), a.questions.map((q) => q.id), reason: 'stable for one attempt');
        expect(
          again.questions.map((q) => q.options.map((o) => o.id).toList()),
          a.questions.map((q) => q.options.map((o) => o.id).toList()),
        );

        final b = await begin(exam, email: other);
        final sameOrder =
            a.questions.map((q) => q.id).toList().toString() == b.questions.map((q) => q.id).toList().toString();
        final sameOptions =
            a.questions.map((q) => q.options.map((o) => o.id).toList()).toString() ==
            b.questions.map((q) => q.options.map((o) => o.id).toList()).toString();
        expect(sameOrder && sameOptions, isFalse, reason: 'two students see different orders');
        expect(a.questions.map((q) => q.id).toSet(), {
          for (final q in questions) q.id,
        }, reason: 'nothing is lost or repeated');
      },
    );

    test('a RANDOMISED attempt grades IDENTICALLY to an ordered one when the same options are chosen', () async {
      final questions = [
        for (var i = 0; i < 6; i++) singleChoice(id: 'q$i', correct: i % 4, text: 'Q$i'),
        multipleChoice(id: 'm0', correct: {0, 3}),
      ];
      final ordered = await s.publishedExam(questions: questions);
      final orderedSession = await begin(ordered);
      // Answer every question correctly, by option id.
      for (final question in orderedSession.questions) {
        final source = questions.firstWhere((q) => q.id == question.id);
        ok(await s.attempts.saveAnswer(orderedSession.attemptId, question.id, ChoiceAnswer(source.correctOptionIds)));
      }
      final orderedResult = ok(await s.attempts.submit(orderedSession.attemptId)).result!;

      final shuffledScenario = await SessionScenario.create(random: Random(7));
      final shuffled = await shuffledScenario.publishedExam(
        questions: questions,
        settings: const ExamSettings(randomizeQuestions: true, randomizeOptions: true),
      );
      await shuffledScenario.openWindowAndConsent(shuffled.id);
      final shuffledSession = ok(await shuffledScenario.attempts.startAttempt(shuffled.id));
      expect(shuffledSession.questions.map((q) => q.id), isNot(orderedSession.questions.map((q) => q.id)));
      for (final question in shuffledSession.questions) {
        final source = questions.firstWhere((q) => q.id == question.id);
        // The student ticks the options whose TEXT is the correct one, wherever it happens to be on screen.
        final correctTexts = {
          for (final o in source.options)
            if (o.isCorrect) o.text,
        };
        final ids = {
          for (final o in question.options)
            if (correctTexts.contains(o.text)) o.id,
        };
        ok(await shuffledScenario.attempts.saveAnswer(shuffledSession.attemptId, question.id, ChoiceAnswer(ids)));
      }
      final shuffledResult = ok(await shuffledScenario.attempts.submit(shuffledSession.attemptId)).result!;

      expect(shuffledResult.awardedMarks, orderedResult.awardedMarks);
      expect(shuffledResult.totalMarks, orderedResult.totalMarks);
      expect(shuffledResult.awardedMarks, shuffledResult.totalMarks);
    });
  });

  group('the answer key is a snapshot: editing the exam later cannot change an attempt', () {
    test('an edit to the published exam after the attempt began does not change how it is graded', () async {
      final exam = await s.publishedExam(questions: [singleChoice(correct: 1)]);
      final session = await begin(exam);
      ok(
        await s.attempts.saveAnswer(
          session.attemptId,
          session.questions[0].id,
          ChoiceAnswer({exam.questions[0].options[1].id}),
        ),
      );

      // The instructor "fixes" the key afterwards (possible only through storage here, as the window has opened).
      await s.examStore.mutate((all) {
        final edited = singleChoice(correct: 2);
        all[0] = all[0].copyWith(questions: [edited]);
      });

      final result = ok(await s.attempts.submit(session.attemptId)).result!;
      expect(result.awardedMarks, 1, reason: 'graded against the key as it was when the attempt began');
    });
  });

  group('storage trouble', () {
    test('a broken store is a StorageFailure, never an exception', () async {
      s.env.keyValueStore.values['local.attempts.v1'] = 'not json';
      await s.signInAs(student);
      expect(err(await s.studentExams.listExams()), isA<StorageFailure>());
    });
  });
}

String _correctId(Exam exam, String questionId) =>
    exam.questions.firstWhere((q) => q.id == questionId).correctOptionIds.first;
