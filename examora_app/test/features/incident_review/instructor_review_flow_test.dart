import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';
import '../../support/fake_services.dart';
import '../../support/session_scenario.dart';
import '../../support/test_harness.dart';

/// The instructor's side, in the real app: dashboard numbers, the attempts at an exam, marking a typed answer, the incident
/// queue and an incident's detail with its decision.
void main() {
  late SessionScenario s;
  late Exam exam;
  late String attemptId;
  late Incident firstIncident;

  const instructor = 'instructor@examora.app';

  void testScenario(String name, Future<void> Function(WidgetTester tester) body) => testWidgets(name, (tester) async {
    s = await SessionScenario.create(env: TestEnvironment(now: DateTime.utc(2026, 10, 27, 9)));
    await body(tester);
  });

  /// A published exam, one student who answered both questions and submitted, and two incidents on that attempt.
  Future<void> prepare({bool withAttempt = true, bool withIncidents = true}) async {
    exam = await s.publishedExam(questions: [singleChoice(), shortText()]);
    if (withAttempt) {
      await s.openWindowAndConsent(exam.id);
      final session = ok(await s.attempts.startAttempt(exam.id));
      attemptId = session.attemptId;
      ok(
        await s.attempts.saveAnswer(
          attemptId,
          session.questions[0].id,
          ChoiceAnswer({exam.questions[0].correctOptionIds.first}),
        ),
      );
      ok(
        await s.attempts.saveAnswer(
          attemptId,
          session.questions[1].id,
          const TextAnswer('A function that calls itself.'),
        ),
      );
      if (withIncidents) {
        firstIncident = ok(
          await s.recorder.record(
            NewIncident(
              attemptId: attemptId,
              category: IncidentCategory.appBackgrounded,
              occurredAt: s.env.clock.now(),
              durationMs: 14000,
              detail: '14',
            ),
          ),
        );
        s.env.clock.advance(const Duration(seconds: 30));
        ok(
          await s.recorder.record(
            NewIncident(
              attemptId: attemptId,
              category: IncidentCategory.clipboardAttempt,
              occurredAt: s.env.clock.now(),
              detail: 'bulk:120',
            ),
          ),
        );
      }
      ok(await s.attempts.submit(attemptId));
    }
    await s.signInAs(instructor);
  }

  Future<void> open(WidgetTester tester, String location) =>
      pumpExamora(tester, s.env, initialLocation: location, extra: FakeDevice().overrides);

  group('the dashboard', () {
    testScenario('shows real numbers: exams per status, answers waiting for marks, incidents waiting for a decision', (
      tester,
    ) async {
      await prepare();
      await open(tester, RoutePaths.instructorDashboard);
      expect(find.byKey(const Key('count-scheduled')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('count-scheduled'))).data, 'Scheduled: 0');
      expect(tester.widget<Text>(find.byKey(const Key('count-ongoing'))).data, 'Ongoing: 1');
      expect(tester.widget<Text>(find.byKey(const Key('count-draft'))).data, 'Draft: 0');
      expect(
        tester.widget<Text>(find.byKey(const Key('dashboard-marking'))).data,
        '1 written answer is waiting for your marks',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('dashboard-incidents'))).data,
        '2 incidents are waiting for a decision',
      );
    });

    testScenario('with nothing to do it says so, in words', (tester) async {
      await prepare(withAttempt: false);
      await open(tester, RoutePaths.instructorDashboard);
      expect(
        tester.widget<Text>(find.byKey(const Key('dashboard-marking'))).data,
        'No written answers are waiting to be marked.',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('dashboard-incidents'))).data,
        'No incidents are waiting for a decision.',
      );
    });

    testScenario('a broken store is an error, not zeros', (tester) async {
      await prepare(withAttempt: false);
      s.env.keyValueStore.values['local.incidents.v1'] = 'garbage';
      await open(tester, RoutePaths.instructorDashboard);
      expect(find.text('This did not load'), findsWidgets);
    });
  });

  group('the attempts at an exam', () {
    testScenario('lists the student with status, marks so far, what is left to mark and the incident count', (
      tester,
    ) async {
      await prepare();
      await open(tester, RoutePaths.instructorExamAttempts(exam.id));
      expect(find.text('Malk Mostafa'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Marks so far: 1 of 6'), findsOneWidget);
      expect(find.text('1 to mark'), findsOneWidget);
      expect(find.text('2 incidents'), findsOneWidget);
    });

    testScenario('no attempts: an empty state, not an error', (tester) async {
      await prepare(withAttempt: false);
      await open(tester, RoutePaths.instructorExamAttempts(exam.id));
      expect(find.text('No attempts yet'), findsOneWidget);
    });

    testScenario('another instructor\'s exam is "not found"', (tester) async {
      await prepare();
      await s.signInAs('instructor2@examora.app');
      await open(tester, RoutePaths.instructorExamAttempts(exam.id));
      expect(find.text('The requested item was not found.'), findsOneWidget);
      expect(find.text('Malk Mostafa'), findsNothing);
    });

    testScenario('opening an attempt shows the answer key and the typed answer, and marking it updates the total', (
      tester,
    ) async {
      await prepare();
      await open(tester, RoutePaths.instructorExamAttempts(exam.id));
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();
      expect(find.text('Marks so far: 1 of 6'), findsOneWidget);
      expect(find.textContaining('✓ correct'), findsOneWidget);
      expect(find.byKey(Key('typed-answer-${exam.questions[1].id}')), findsOneWidget);
      expect(find.text('A function that calls itself.'), findsWidgets);
      expect(find.text('Waiting to be marked'), findsOneWidget);

      await enterField(tester, 'Marks (0 to 5)', '4');
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Save marks'));
      expect(find.text('Marks saved: 4'), findsOneWidget);
      expect(find.text('Marks so far: 5 of 6'), findsOneWidget);
      expect(find.text('Marked by your instructor'), findsOneWidget);
    });

    testScenario('marks above what the question offers are limited, and the screen says so', (tester) async {
      await prepare();
      await open(tester, RoutePaths.instructorExamAttempts(exam.id));
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();
      await enterField(tester, 'Marks (0 to 5)', '99');
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Save marks'));
      expect(find.text('Limited to what the question offers: 5'), findsOneWidget);
      expect(find.text('Marks so far: 6 of 6'), findsOneWidget);
    });

    testScenario('text that is not a number is refused on screen', (tester) async {
      await prepare();
      await open(tester, RoutePaths.instructorExamAttempts(exam.id));
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();
      await enterField(tester, 'Marks (0 to 5)', 'lots');
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Save marks'));
      expect(find.text('This number is outside the allowed range.'), findsOneWidget);
      expect(find.text('Marks so far: 1 of 6'), findsOneWidget);
    });

    testScenario('the student sees the marks the instructor gave', (tester) async {
      await prepare();
      await open(tester, RoutePaths.instructorExamAttempts(exam.id));
      await tester.tap(find.text('Malk Mostafa'));
      await tester.pumpAndSettle();
      await enterField(tester, 'Marks (0 to 5)', '3');
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Save marks'));
      await s.signInAs('student@examora.app');
      final result = ok(await s.attempts.getResult(attemptId)).result!;
      expect(result.awardedMarks, 4);
      expect(result.isFinal, isTrue);
    });
  });

  group('the incident queue', () {
    testScenario('lists undecided incidents first, with severity and status as words', (tester) async {
      await prepare();
      await open(tester, RoutePaths.instructorIncidents);
      expect(find.text('Incidents'), findsWidgets);
      expect(find.text('App left the foreground'), findsOneWidget);
      expect(find.text('Copy or paste attempt'), findsOneWidget);
      expect(find.text('Not decided yet'), findsNWidgets(2));
      expect(find.text('Medium'), findsNWidgets(2));
    });

    testScenario('the filters separate decided from undecided', (tester) async {
      await prepare();
      ok(await s.review.decide(firstIncident.id, ReviewDecision.noViolation, 'checked'));
      await open(tester, RoutePaths.instructorIncidents);
      expect(find.text('Copy or paste attempt'), findsOneWidget);
      expect(find.text('App left the foreground'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Decided'));
      await tester.pumpAndSettle();
      expect(find.text('App left the foreground'), findsOneWidget);
      expect(find.text('No violation'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.text('App left the foreground'), findsOneWidget);
      expect(find.text('Copy or paste attempt'), findsOneWidget);
    });

    testScenario('empty: an empty state', (tester) async {
      await prepare(withAttempt: false);
      await open(tester, RoutePaths.instructorIncidents);
      expect(find.text('No incidents'), findsOneWidget);
    });

    testScenario('another instructor sees none of them', (tester) async {
      await prepare();
      await s.signInAs('instructor2@examora.app');
      await open(tester, RoutePaths.instructorIncidents);
      expect(find.text('No incidents'), findsOneWidget);
    });

    testScenario('a broken store is an error with retry, not "no incidents"', (tester) async {
      await prepare(withAttempt: false);
      s.env.keyValueStore.values['local.incidents.v1'] = 'garbage';
      await open(tester, RoutePaths.instructorIncidents);
      expect(find.text('This did not load'), findsOneWidget);
      expect(find.text('No incidents'), findsNothing);
    });
  });

  group('one incident', () {
    testScenario('shows what happened in words, the evidence status, the whole timeline, and the warnings', (
      tester,
    ) async {
      await prepare();
      await open(tester, RoutePaths.instructorIncident(firstIncident.id));
      expect(
        tester.widget<Text>(find.byKey(const Key('incident-description'))).data,
        'The app was off screen for 14 seconds.',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('incident-evidence'))).data,
        startsWith('Unavailable. There is no recording.'),
      );
      expect(find.textContaining('(this incident)'), findsOneWidget);
      expect(find.text('A block of 120 characters was inserted at once into an answer and refused.'), findsOneWidget);
      expect(find.text('Warnings in this attempt: 2 of 20'), findsOneWidget);
      expect(find.textContaining('never changes a mark'), findsOneWidget);
    });

    testScenario('the instructor decides, with notes, and the decision is kept', (tester) async {
      await prepare();
      await open(tester, RoutePaths.instructorIncident(firstIncident.id));
      final save = find.widgetWithText(FilledButton, 'Save decision');
      await tester.ensureVisible(save);
      expect(tester.widget<FilledButton>(save).onPressed, isNull, reason: 'nothing chosen yet');

      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Violation confirmed'));
      await enterField(tester, 'Notes (optional)', 'He left for 14 seconds and then continued.');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save decision'));
      expect(find.text('Decision saved.'), findsOneWidget);
      expect(find.text('Violation confirmed'), findsWidgets);

      final stored = (await s.incidentStore.all()).firstWhere((i) => i.id == firstIncident.id);
      expect(stored.decision!.decision, ReviewDecision.violationConfirmed);
      expect(stored.decision!.notes, 'He left for 14 seconds and then continued.');
    });

    testScenario('a decision changes no mark', (tester) async {
      await prepare();
      await s.signInAs('student@examora.app');
      final before = ok(await s.attempts.getResult(attemptId)).result!.toJson();
      await s.signInAs(instructor);
      await open(tester, RoutePaths.instructorIncident(firstIncident.id));
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Violation confirmed'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save decision'));
      await s.signInAs('student@examora.app');
      expect(ok(await s.attempts.getResult(attemptId)).result!.toJson(), before);
    });

    testScenario('another instructor\'s incident is "not found"', (tester) async {
      await prepare();
      await s.signInAs('instructor2@examora.app');
      await open(tester, RoutePaths.instructorIncident(firstIncident.id));
      expect(find.text('The requested item was not found.'), findsOneWidget);
    });

    testScenario('a student cannot open an incident page, not even their own: the guard turns them away', (
      tester,
    ) async {
      await prepare();
      await s.signInAs('student@examora.app');
      await open(tester, RoutePaths.instructorIncident(firstIncident.id));
      expect(routerOf(tester).location, RoutePaths.studentDashboard);
    });

    testScenario('Arabic: the incident and its description are Arabic', (tester) async {
      s = await SessionScenario.create(
        env: TestEnvironment(language: 'ar', now: DateTime.utc(2026, 10, 27, 9)),
      );
      await prepare();
      await open(tester, RoutePaths.instructorIncident(firstIncident.id));
      expect(find.text('الحادثة'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('incident-description'))).data,
        'كان التطبيق خارج الشاشة لمدة 14 ثانية.',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
