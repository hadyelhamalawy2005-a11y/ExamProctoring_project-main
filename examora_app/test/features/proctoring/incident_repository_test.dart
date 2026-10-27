import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/proctoring/domain/capabilities.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';
import '../../support/session_scenario.dart';

void main() {
  late SessionScenario s;
  late Exam exam;
  late StudentAttemptSession session;

  const student = 'student@examora.app';
  const instructor = 'instructor@examora.app';

  NewIncident report(
    IncidentCategory category, {
    EvidenceStatus evidence = EvidenceStatus.unavailable,
    String? reference,
    String detail = 'x',
  }) => NewIncident(
    attemptId: session.attemptId,
    category: category,
    occurredAt: s.env.clock.now(),
    durationMs: 12000,
    detail: detail,
    evidenceStatus: evidence,
    evidenceReference: reference,
  );

  Future<void> begin({ExamSettings settings = const ExamSettings(), String examOwner = instructor}) async {
    exam = await s.publishedExam(settings: settings, owner: examOwner);
    await s.openWindowAndConsent(exam.id);
    session = ok(await s.attempts.startAttempt(exam.id));
  }

  setUp(() async => s = await SessionScenario.create());

  group('recording', () {
    test(
      'records an incident with the category\'s own severity and source, and NO evidence (stated, not invented)',
      () async {
        await begin();
        final incident = ok(await s.recorder.record(report(IncidentCategory.clipboardAttempt)));
        expect(incident.category, IncidentCategory.clipboardAttempt);
        expect(incident.severity, IncidentSeverity.medium);
        expect(incident.source, DetectionSource.appUi);
        expect(incident.evidence.status, EvidenceStatus.unavailable);
        expect(incident.evidence.reference, isNull);
        expect(incident.evidence.gap, EvidenceGap.noRetroactiveCapture);
        expect(incident.studentName, 'Malk Mostafa');
        expect(incident.examTitle, exam.title);
        expect(incident.decision, isNull);
        expect(incident.warningLimit, 20);
      },
    );

    test('EVIDENCE: "captured" without a real reference is REFUSED; with one, it is kept as given', () async {
      await begin();
      for (final blank in [null, '', '   ']) {
        final failure = err(
          await s.recorder.record(
            report(IncidentCategory.clipboardAttempt, evidence: EvidenceStatus.captured, reference: blank),
          ),
        );
        expect(failure, isA<ValidationFailure>(), reason: '"$blank"');
        expect((failure as ValidationFailure).fields.keys, ['evidence']);
      }
      expect(await s.incidentStore.all(), isEmpty, reason: 'a refused report leaves no record at all');

      final kept = ok(
        await s.recorder.record(
          report(IncidentCategory.screenshotDetected, evidence: EvidenceStatus.captured, reference: ' clip-123 '),
        ),
      );
      expect(kept.evidence.status, EvidenceStatus.captured);
      expect(kept.evidence.reference, 'clip-123');
    });

    test('the evidence buffer in this build never produces a clip', () async {
      const buffer = UnavailableEvidenceBuffer();
      final capture = await buffer.captureBefore(DateTime.utc(2026), seconds: 3);
      expect(capture, isA<EvidenceNotAvailable>());
      expect((capture as EvidenceNotAvailable).gap, EvidenceGap.noRetroactiveCapture);
    });

    test('the detector suite produces nothing and says it is inactive', () async {
      const suite = NullDetectorSuite();
      expect(suite.isActive, isFalse);
      expect(await suite.events.toList(), isEmpty);
    });

    test('a rule the exam did not switch on is refused', () async {
      await begin(settings: const ExamSettings(enabledRules: {IncidentCategory.networkLost}));
      expect(err(await s.recorder.record(report(IncidentCategory.clipboardAttempt))).code, 'rule_not_enabled');
    });

    test('a rule this build cannot notice is refused even if the exam lists it', () async {
      await begin(settings: const ExamSettings(enabledRules: {IncidentCategory.gazeAway, IncidentCategory.faceAbsent}));
      expect(err(await s.recorder.record(report(IncidentCategory.gazeAway))).code, 'rule_not_enabled');
      expect(err(await s.recorder.record(report(IncidentCategory.faceAbsent))).code, 'rule_not_enabled');
    });

    test('only for the student\'s own, still open attempt', () async {
      await begin();
      await s.signInAs('student2@examora.app');
      expect(err(await s.recorder.record(report(IncidentCategory.clipboardAttempt))), isA<NotFoundFailure>());

      await s.signInAs(student);
      ok(await s.attempts.submit(session.attemptId));
      expect(err(await s.recorder.record(report(IncidentCategory.clipboardAttempt))).code, 'attempt_already_submitted');
    });

    test('an instructor or an administrator cannot record incidents', () async {
      await begin();
      for (final email in [instructor, 'admin@examora.app']) {
        await s.signInAs(email);
        expect(
          err(await s.recorder.record(report(IncidentCategory.clipboardAttempt))),
          isA<ForbiddenFailure>(),
          reason: email,
        );
      }
    });
  });

  group('PROCTORING NEVER CHANGES A MARK', () {
    test('twenty incidents later, the attempt grades exactly as it would with none', () async {
      await begin(settings: const ExamSettings(maxWarnings: 3));
      final answer = ChoiceAnswer({exam.questions.first.correctOptionIds.first});
      ok(await s.attempts.saveAnswer(session.attemptId, session.questions.first.id, answer));
      for (var i = 0; i < 20; i++) {
        s.env.clock.advance(const Duration(seconds: 2));
        ok(await s.recorder.record(report(IncidentCategory.clipboardAttempt)));
      }
      final withIncidents = ok(await s.attempts.submit(session.attemptId)).result!;

      final clean = await SessionScenario.create();
      final cleanExam = await clean.publishedExam(settings: const ExamSettings(maxWarnings: 3));
      await clean.openWindowAndConsent(cleanExam.id);
      final cleanSession = ok(await clean.attempts.startAttempt(cleanExam.id));
      ok(
        await clean.attempts.saveAnswer(
          cleanSession.attemptId,
          cleanSession.questions.first.id,
          ChoiceAnswer({cleanExam.questions.first.correctOptionIds.first}),
        ),
      );
      final without = ok(await clean.attempts.submit(cleanSession.attemptId)).result!;

      expect(withIncidents.awardedMarks, without.awardedMarks);
      expect(withIncidents.awardedMarks, 1);
      expect(withIncidents.toJson(), without.toJson());
    });

    test('and the attempt is not ended or locked by reaching the warning limit', () async {
      await begin(settings: const ExamSettings(maxWarnings: 1));
      ok(await s.recorder.record(report(IncidentCategory.clipboardAttempt)));
      s.env.clock.advance(const Duration(seconds: 2));
      ok(await s.recorder.record(report(IncidentCategory.clipboardAttempt)));
      ok(
        await s.attempts.saveAnswer(
          session.attemptId,
          session.questions.first.id,
          ChoiceAnswer({session.questions.first.options.first.id}),
        ),
      );
    });
  });

  group('SECURITY: a student cannot review their own incidents', () {
    test('the recorder only writes, and the review repository refuses a student', () async {
      await begin();
      final incident = ok(await s.recorder.record(report(IncidentCategory.clipboardAttempt)));
      await s.signInAs(student);
      expect(err(await s.review.listQueue()), isA<ForbiddenFailure>());
      expect(err(await s.review.getIncident(incident.id)), isA<ForbiddenFailure>());
      expect(
        err(await s.review.decide(incident.id, ReviewDecision.noViolation, 'it was nothing')),
        isA<ForbiddenFailure>(),
      );
      expect((await s.incidentStore.all()).single.decision, isNull);
    });
  });

  group('the instructor\'s review', () {
    late Incident first;
    late Incident second;

    setUp(() async {
      await begin();
      first = ok(await s.recorder.record(report(IncidentCategory.clipboardAttempt, detail: 'pasted 80 characters')));
      s.env.clock.advance(const Duration(seconds: 30));
      second = ok(await s.recorder.record(report(IncidentCategory.appBackgrounded, detail: '12')));
      await s.signInAs(instructor);
    });

    test(
      'the queue lists the incidents at MY exams, newest first, and can be filtered by decided / undecided',
      () async {
        expect(ok(await s.review.listQueue()).map((i) => i.id), [second.id, first.id]);
        expect(ok(await s.review.listQueue(decided: true)), isEmpty);
        expect(ok(await s.review.listQueue(decided: false)), hasLength(2));
        ok(await s.review.decide(first.id, ReviewDecision.noViolation, 'a normal copy'));
        expect(ok(await s.review.listQueue(decided: true)).map((i) => i.id), [first.id]);
        expect(ok(await s.review.listQueue(decided: false)).map((i) => i.id), [second.id]);
      },
    );

    test(
      'the detail has the incident, the evidence status and the whole timeline of that attempt in time order',
      () async {
        final detail = ok(await s.review.getIncident(first.id));
        expect(detail.incident.id, first.id);
        expect(detail.incident.evidence.status, EvidenceStatus.unavailable);
        expect(detail.timeline.map((i) => i.id), [first.id, second.id]);
        expect(detail.warnings, 2);
        expect(detail.limitReached, isFalse);
      },
    );

    test('a decision (with notes) is saved and can be replaced', () async {
      final decided = ok(await s.review.decide(first.id, ReviewDecision.violationConfirmed, '  copied from a note  '));
      expect(decided.decision!.decision, ReviewDecision.violationConfirmed);
      expect(decided.decision!.notes, 'copied from a note');
      expect(decided.decision!.decidedAt, s.env.clock.now());
      final changed = ok(await s.review.decide(first.id, ReviewDecision.inconclusive, 'cannot tell'));
      expect(changed.decision!.decision, ReviewDecision.inconclusive);
      expect(ok(await s.review.getIncident(first.id)).incident.decision!.notes, 'cannot tell');
    });

    test('all three decisions exist, and notes are limited in length', () async {
      expect(ReviewDecision.values, [
        ReviewDecision.noViolation,
        ReviewDecision.violationConfirmed,
        ReviewDecision.inconclusive,
      ]);
      expect(err(await s.review.decide(first.id, ReviewDecision.noViolation, 'x' * 501)), isA<ValidationFailure>());
    });

    test('a decision does not change any mark', () async {
      await s.signInAs(student);
      ok(await s.attempts.submit(session.attemptId));
      final before = ok(await s.attempts.getResult(session.attemptId)).result!.toJson();
      await s.signInAs(instructor);
      ok(await s.review.decide(first.id, ReviewDecision.violationConfirmed, 'confirmed'));
      await s.signInAs(student);
      expect(ok(await s.attempts.getResult(session.attemptId)).result!.toJson(), before);
    });

    test('the warning limit is reported when reached', () async {
      final scenario = await SessionScenario.create();
      final limited = await scenario.publishedExam(settings: const ExamSettings(maxWarnings: 2));
      await scenario.openWindowAndConsent(limited.id);
      final attempt = ok(await scenario.attempts.startAttempt(limited.id));
      Incident? last;
      for (var i = 0; i < 2; i++) {
        scenario.env.clock.advance(const Duration(seconds: 2));
        last = ok(
          await scenario.recorder.record(
            NewIncident(
              attemptId: attempt.attemptId,
              category: IncidentCategory.clipboardAttempt,
              occurredAt: scenario.env.clock.now(),
            ),
          ),
        );
      }
      await scenario.signInAs(instructor);
      final detail = ok(await scenario.review.getIncident(last!.id));
      expect(detail.warnings, 2);
      expect(detail.limitReached, isTrue);
    });
  });

  group('SECURITY: an instructor cannot touch another instructor\'s incidents', () {
    test('another instructor sees an empty queue and "not found" for everything', () async {
      await begin();
      final incident = ok(await s.recorder.record(report(IncidentCategory.clipboardAttempt)));
      await s.signInAs('instructor2@examora.app');
      expect(ok(await s.review.listQueue()), isEmpty);
      expect(err(await s.review.getIncident(incident.id)), isA<NotFoundFailure>());
      expect(err(await s.review.decide(incident.id, ReviewDecision.noViolation, 'hijack')), isA<NotFoundFailure>());
      await s.signInAs(instructor);
      expect(ok(await s.review.getIncident(incident.id)).incident.decision, isNull);
    });
  });

  test('incidents round-trip through storage, evidence included', () async {
    await begin();
    ok(
      await s.recorder.record(
        report(IncidentCategory.screenshotDetected, evidence: EvidenceStatus.captured, reference: 'ref-9'),
      ),
    );
    ok(await s.recorder.record(report(IncidentCategory.networkLost)));
    final stored = await s.incidentStore.all();
    expect(stored.map((i) => i.evidence.status), [EvidenceStatus.captured, EvidenceStatus.unavailable]);
    expect(stored.first.evidence.reference, 'ref-9');
  });
}
