import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/network/missing_endpoints.dart';
import 'package:examora_app/features/exam_session/data/api_exam_session_repositories.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/proctoring/data/api_incident_repositories.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';
import '../../support/session_scenario.dart';

void main() {
  late SessionScenario s;
  late Exam exam;

  const instructor = 'instructor@examora.app';

  Future<StudentAttemptSession> takeExam(String email, {bool submit = true, bool typedAnswer = true}) async {
    await s.openWindowAndConsent(exam.id, student: email);
    final session = ok(await s.attempts.startAttempt(exam.id));
    ok(
      await s.attempts.saveAnswer(
        session.attemptId,
        session.questions[0].id,
        ChoiceAnswer({exam.questions[0].correctOptionIds.first}),
      ),
    );
    if (typedAnswer) {
      ok(
        await s.attempts.saveAnswer(
          session.attemptId,
          session.questions[2].id,
          const TextAnswer('Recursion is when a function calls itself.'),
        ),
      );
    }
    if (submit) ok(await s.attempts.submit(session.attemptId));
    return session;
  }

  setUp(() async {
    s = await SessionScenario.create();
    exam = await s.publishedExam();
  });

  group('the list of attempts at an exam', () {
    test('lists every student\'s attempt with status, marks so far and incident count', () async {
      final mine = await takeExam('student@examora.app');
      final theirs = await takeExam('student2@examora.app', submit: false);
      ok(
        await s.recorder.record(
          NewIncident(
            attemptId: theirs.attemptId,
            category: IncidentCategory.clipboardAttempt,
            occurredAt: s.env.clock.now(),
          ),
        ),
      );
      await s.signInAs(instructor);

      final list = ok(await s.instructorAttempts.listForExam(exam.id));
      expect(list, hasLength(2));
      final submitted = list.firstWhere((a) => a.attemptId == mine.attemptId);
      expect(submitted.studentName, 'Malk Mostafa');
      expect(submitted.status, AttemptStatus.submitted);
      expect(submitted.result!.awardedMarks, 1);
      expect(submitted.result!.pendingManualCount, 1);
      expect(submitted.incidentCount, 0);
      final open = list.firstWhere((a) => a.attemptId == theirs.attemptId);
      expect(open.status, AttemptStatus.inProgress);
      expect(open.result, isNull);
      expect(open.incidentCount, 1);
    });

    test('an exam with no attempts has an empty list (not an error)', () async {
      await s.signInAs(instructor);
      expect(ok(await s.instructorAttempts.listForExam(exam.id)), isEmpty);
    });
  });

  group('reviewing one attempt', () {
    test('shows every question with the answer, the answer key and the marks', () async {
      final session = await takeExam('student@examora.app');
      await s.signInAs(instructor);
      final review = ok(await s.instructorAttempts.getReview(session.attemptId));
      expect(review.studentName, 'Malk Mostafa');
      expect(review.questions, hasLength(3));
      expect(review.questions[0].result.outcome, QuestionOutcome.correct);
      expect(
        review.questions[0].question.correctOptionIds,
        isNotEmpty,
        reason: 'the instructor owns the exam and may see its key',
      );
      expect(review.questions[1].result.outcome, QuestionOutcome.unanswered);
      expect(review.questions[2].result.outcome, QuestionOutcome.pendingManual);
      expect(review.questions[2].answer, const TextAnswer('Recursion is when a function calls itself.'));
      expect(review.result.isFinal, isFalse);
    });
  });

  group('manual marking of typed answers', () {
    test('marks the answer, updates the total, and makes the result final', () async {
      final session = await takeExam('student@examora.app');
      await s.signInAs(instructor);
      final typed = session.questions[2].id;
      final review = ok(await s.instructorAttempts.markShortAnswer(session.attemptId, typed, 4));
      expect(review.questions[2].result.outcome, QuestionOutcome.markedManually);
      expect(review.questions[2].result.marksAwarded, 4);
      expect(review.result.awardedMarks, 5);
      expect(review.result.isFinal, isTrue);
      expect(review.result.passed, isTrue, reason: '5 of 8 is above the 50% pass mark');
    });

    test('the marks are CLAMPED to what the question offers', () async {
      final session = await takeExam('student@examora.app');
      await s.signInAs(instructor);
      final typed = session.questions[2].id;
      expect(
        ok(await s.instructorAttempts.markShortAnswer(session.attemptId, typed, 99)).questions[2].result.marksAwarded,
        5,
      );
      expect(
        ok(await s.instructorAttempts.markShortAnswer(session.attemptId, typed, -3)).questions[2].result.marksAwarded,
        0,
      );
      expect(
        ok(await s.instructorAttempts.markShortAnswer(session.attemptId, typed, 2.5)).questions[2].result.marksAwarded,
        2.5,
      );
    });

    test('marks can be corrected later', () async {
      final session = await takeExam('student@examora.app');
      await s.signInAs(instructor);
      final typed = session.questions[2].id;
      ok(await s.instructorAttempts.markShortAnswer(session.attemptId, typed, 1));
      final changed = ok(await s.instructorAttempts.markShortAnswer(session.attemptId, typed, 4));
      expect(changed.result.awardedMarks, 5);
    });

    test('only typed questions can be marked by hand; choice questions are marked by the app', () async {
      final session = await takeExam('student@examora.app');
      await s.signInAs(instructor);
      expect(
        err(await s.instructorAttempts.markShortAnswer(session.attemptId, session.questions[0].id, 5)),
        isA<ValidationFailure>(),
      );
      final review = ok(await s.instructorAttempts.getReview(session.attemptId));
      expect(review.questions[0].result.marksAwarded, 1);
    });

    test('an attempt still in progress cannot be marked', () async {
      final session = await takeExam('student@examora.app', submit: false);
      await s.signInAs(instructor);
      expect(
        err(await s.instructorAttempts.markShortAnswer(session.attemptId, session.questions[2].id, 1)).code,
        'attempt_not_submitted',
      );
    });

    test('an unknown question is not found', () async {
      final session = await takeExam('student@examora.app');
      await s.signInAs(instructor);
      expect(err(await s.instructorAttempts.markShortAnswer(session.attemptId, 'nope', 1)), isA<NotFoundFailure>());
    });

    test('the student sees the new marks in their result', () async {
      final session = await takeExam('student@examora.app');
      await s.signInAs(instructor);
      ok(await s.instructorAttempts.markShortAnswer(session.attemptId, session.questions[2].id, 3));
      await s.signInAs('student@examora.app');
      final result = ok(await s.attempts.getResult(session.attemptId)).result!;
      expect(result.awardedMarks, 4);
      expect(result.isFinal, isTrue);
    });
  });

  group('SECURITY: an instructor cannot touch another instructor\'s exam or its attempts', () {
    test('everything is "not found" for the other instructor, and nothing changes', () async {
      final session = await takeExam('student@examora.app');
      await s.signInAs('instructor2@examora.app');
      expect(err(await s.instructorAttempts.listForExam(exam.id)), isA<NotFoundFailure>());
      expect(err(await s.instructorAttempts.getReview(session.attemptId)), isA<NotFoundFailure>());
      expect(
        err(await s.instructorAttempts.markShortAnswer(session.attemptId, session.questions[2].id, 5)),
        isA<NotFoundFailure>(),
      );
      await s.signInAs(instructor);
      expect(ok(await s.instructorAttempts.getReview(session.attemptId)).result.isFinal, isFalse);
    });

    test('students and administrators cannot use the instructor views', () async {
      final session = await takeExam('student@examora.app');
      for (final email in ['student@examora.app', 'admin@examora.app']) {
        await s.signInAs(email);
        expect(err(await s.instructorAttempts.listForExam(exam.id)), isA<ForbiddenFailure>(), reason: email);
        expect(err(await s.instructorAttempts.getReview(session.attemptId)), isA<ForbiddenFailure>(), reason: email);
      }
    });
  });

  group('an exam with attempts can no longer be returned to a draft', () {
    test('even before it opens', () async {
      final scenario = await SessionScenario.create();
      final published = await scenario.publishedExam();
      // An attempt exists (created straight in storage, as if the window had been open).
      await scenario.openWindowAndConsent(published.id);
      ok(await scenario.attempts.startAttempt(published.id));
      await scenario.signInAs(instructor);
      scenario.env.clock.setTo(DateTime.utc(2026, 10, 27, 9));
      expect(err(await scenario.exams.unpublish(published.id)).code, 'exam_not_unpublishable');
    });
  });

  group('the Api implementations refuse by name and send nothing', () {
    test('students\' exam list, attempts and results', () async {
      const exams = ApiStudentExamRepository();
      const attempts = ApiAttemptRepository();
      expect(
        (err(await exams.listExams()) as EndpointMissingFailure).endpoint,
        MissingEndpoints.studentExamList.endpoint,
      );
      expect(
        (err(await exams.getExam('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.studentExamBriefing.endpoint,
      );
      expect(
        (err(await attempts.recordConsent('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.recordConsent.endpoint,
      );
      expect(
        (err(await attempts.startAttempt('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.startAttempt.endpoint,
      );
      expect(
        (err(await attempts.getSession('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.attemptSession.endpoint,
      );
      expect(
        (err(await attempts.saveAnswer('x', 'q', null)) as EndpointMissingFailure).endpoint,
        MissingEndpoints.saveAnswer.endpoint,
      );
      expect(
        (err(await attempts.saveProgress('x', 1)) as EndpointMissingFailure).endpoint,
        MissingEndpoints.saveProgress.endpoint,
      );
      expect(
        (err(await attempts.submit('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.submitAttempt.endpoint,
      );
      expect(
        (err(await attempts.getResult('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.attemptResult.endpoint,
      );
      expect(
        (err(await attempts.listResults()) as EndpointMissingFailure).endpoint,
        MissingEndpoints.studentResults.endpoint,
      );
    });

    test('the instructor\'s attempts and incident review', () async {
      const attempts = ApiInstructorAttemptRepository();
      expect(
        (err(await attempts.listForExam('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.instructorAttempts.endpoint,
      );
      expect(
        (err(await attempts.getReview('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.attemptReview.endpoint,
      );
      expect(
        (err(await attempts.markShortAnswer('x', 'q', 1)) as EndpointMissingFailure).endpoint,
        MissingEndpoints.markShortAnswer.endpoint,
      );

      const recorder = ApiIncidentRecorder();
      const review = ApiIncidentReviewRepository();
      expect(
        (err(
          await recorder.record(
            NewIncident(attemptId: 'a', category: IncidentCategory.networkLost, occurredAt: DateTime.utc(2026)),
          ),
        ) as EndpointMissingFailure).endpoint,
        MissingEndpoints.recordIncident.endpoint,
      );
      expect(
        (err(await review.listQueue()) as EndpointMissingFailure).endpoint,
        MissingEndpoints.incidentQueue.endpoint,
      );
      expect(
        (err(await review.getIncident('x')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.incidentDetail.endpoint,
      );
      expect(
        (err(await review.decide('x', ReviewDecision.noViolation, '')) as EndpointMissingFailure).endpoint,
        MissingEndpoints.incidentDecision.endpoint,
      );
    });

    test('every missing endpoint has a reason and a unique name', () {
      final names = MissingEndpoints.all.map((e) => e.endpoint).toList();
      expect(names.toSet().length, names.length);
      for (final entry in MissingEndpoints.all) {
        expect(entry.reason, isNotEmpty);
        expect(entry.neededFor, isNotEmpty);
      }
    });
  });
}
