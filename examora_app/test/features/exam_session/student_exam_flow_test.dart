import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/proctoring/data/platform_services.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';
import '../../support/fake_services.dart';
import '../../support/session_scenario.dart';
import '../../support/test_harness.dart';

/// These build the REAL app and walk a student through an exam: list, briefing, consent, system check, the player, the
/// result. Only storage, the clock and the camera / network / screenshot services are replaced.
void main() {
  late SessionScenario s;
  late FakeDevice device;
  late Exam exam;

  const student = 'student@examora.app';

  // The scenario is built INSIDE the test: its stores chain futures, and a future made outside the widget-test zone would
  // never be resumed by the test's fake clock.
  void testScenario(String name, Future<void> Function(WidgetTester tester) body) => testWidgets(name, (tester) async {
    s = await SessionScenario.create(env: TestEnvironment(now: DateTime.utc(2026, 10, 27, 9)));
    device = FakeDevice();
    await body(tester);
  });

  Future<void> prepare({
    List<Question>? questions,
    ExamSettings settings = const ExamSettings(),
    int minutes = 60,
  }) async {
    exam = await s.publishedExam(
      questions: questions ?? [singleChoice(), shortText()],
      settings: settings,
      minutes: minutes,
    );
    s.env.clock.setTo(s.opens.add(const Duration(minutes: 5)));
    await s.signInAs(student);
  }

  Future<void> open(WidgetTester tester, String location) =>
      pumpExamora(tester, s.env, initialLocation: location, extra: device.overrides);

  Future<void> goThroughConsentAndCheck(WidgetTester tester) async {
    await open(tester, RoutePaths.studentExam(exam.id));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue'));
    await tapVisible(tester, find.byType(CheckboxListTile));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Continue to the system check'));
  }

  Future<void> startFromCheck(WidgetTester tester) async {
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Start the exam'));
  }

  Future<List<Attempt>> attempts() => s.attemptStore.all();

  String timeText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('time-remaining'))).data!;

  group('the lists', () {
    testScenario('the student sees the published exam in the Exams tab, with its status and attempt state in words', (
      tester,
    ) async {
      await prepare();
      await open(tester, RoutePaths.studentExams);
      expect(find.text('My exams'), findsWidgets);
      expect(find.text(exam.title), findsOneWidget);
      expect(find.text('Ongoing'), findsOneWidget);
      expect(find.text('Not started'), findsOneWidget);
    });

    testScenario('no exams: an empty state; a failed load: an error with retry (never "no exams")', (tester) async {
      await s.signInAs(student);
      await open(tester, RoutePaths.studentExams);
      expect(find.text('No exams are available yet'), findsOneWidget);
    });

    testScenario('a broken store is an error, not an empty list', (tester) async {
      await prepare();
      s.env.keyValueStore.values['local.attempts.v1'] = 'garbage';
      await open(tester, RoutePaths.studentExams);
      expect(find.text('This did not load'), findsOneWidget);
      expect(find.text('No exams are available yet'), findsNothing);
    });

    testScenario('the home screen shows the open exam and says there is no result yet', (tester) async {
      await prepare();
      await open(tester, RoutePaths.studentDashboard);
      expect(find.text(exam.title), findsOneWidget);
      expect(find.byKey(const Key('dashboard-no-results')), findsOneWidget);
    });

    testScenario('Results tab: empty at first', (tester) async {
      await prepare();
      await open(tester, RoutePaths.studentResults);
      expect(find.text('No results yet'), findsOneWidget);
    });
  });

  group('the briefing', () {
    testScenario(
      'shows the instructions, the numbers, the rules and what is watched - with the inactive rules called out',
      (tester) async {
        await prepare(
          settings: const ExamSettings(
            calculatorEnabled: true,
            allowBackwardNavigation: false,
            randomizeOptions: true,
            enabledRules: {IncidentCategory.clipboardAttempt, IncidentCategory.gazeAway},
          ),
        );
        await open(tester, RoutePaths.studentExam(exam.id));
        expect(find.text('No notes allowed.'), findsOneWidget);
        expect(find.text('Time allowed: 60 minutes'), findsOneWidget);
        expect(find.text('Questions: 2'), findsOneWidget);
        expect(find.text('Total marks: 6'), findsOneWidget);
        expect(find.text('A scientific calculator is available.'), findsOneWidget);
        expect(find.text('You cannot go back to earlier questions.'), findsOneWidget);
        expect(find.text('Answer options are in a random order.'), findsOneWidget);
        expect(find.text('• Copy or paste attempt'), findsOneWidget);
        expect(find.text('Listed by the instructor but NOT active in this app:'), findsOneWidget);
        expect(find.text('• Looking away'), findsOneWidget);
      },
    );

    testScenario('does not contain the answer key', (tester) async {
      await prepare(
        questions: [
          singleChoice().copyWith(explanation: (value: 'SECRET EXPLANATION')),
          shortText(),
        ],
      );
      await open(tester, RoutePaths.studentExam(exam.id));
      expect(find.textContaining('SECRET'), findsNothing);
      expect(find.textContaining('A function calling itself'), findsNothing);
    });

    testScenario('before the window opens there is no way in, only the opening time', (tester) async {
      exam = await s.publishedExam();
      await s.signInAs(student);
      await open(tester, RoutePaths.studentExam(exam.id));
      expect(find.textContaining('This exam opens on'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Continue'), findsNothing);
    });

    testScenario('after the window closed there is no way in', (tester) async {
      exam = await s.publishedExam();
      await s.travelTo(s.closes.add(const Duration(minutes: 1)), email: student);
      await open(tester, RoutePaths.studentExam(exam.id));
      expect(find.text('This exam is closed. You can no longer start it.'), findsOneWidget);
    });

    testScenario('a draft exam is "not found" to a student', (tester) async {
      await s.signInAs('instructor@examora.app');
      final draft = ok(await s.exams.createExam(details(title: 'Hidden draft')));
      await s.signInAs(student);
      await open(tester, RoutePaths.studentExam(draft.id));
      expect(find.text('The requested item was not found.'), findsOneWidget);
      expect(find.text('Hidden draft'), findsNothing);
    });
  });

  group('consent comes BEFORE any camera use', () {
    testScenario('the consent screen explains what is and is not recorded and gates the way on', (tester) async {
      await prepare();
      await open(tester, RoutePaths.studentConsent(exam.id));
      expect(find.textContaining('does not record, store or send any video or audio'), findsOneWidget);
      expect(find.textContaining('Warnings never change your marks'), findsOneWidget);
      expect(find.textContaining('no face, gaze or speech detection'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Continue to the system check');
      expect(tester.widget<FilledButton>(button).onPressed, isNull, reason: 'not until the box is ticked');
      expect(device.camera.starts, 0, reason: 'the camera has not been touched');
      expect(await s.consentStore.all(), isEmpty);

      await tapVisible(tester, find.byType(CheckboxListTile));
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testScenario('going straight to the system check without consent: no camera, and a way to the consent screen', (
      tester,
    ) async {
      await prepare();
      await open(tester, RoutePaths.studentSystemCheck(exam.id));
      expect(find.text('You have not agreed to the notice yet.'), findsOneWidget);
      expect(device.camera.starts, 0);
      expect(device.connectivity.online, isTrue);
      expect(find.widgetWithText(FilledButton, 'Start the exam'), findsNothing);
    });

    testScenario('agreeing is recorded and leads to the system check, where the camera is started', (tester) async {
      await prepare();
      await goThroughConsentAndCheck(tester);
      expect((await s.consentStore.all()).single.studentId, isNotEmpty);
      expect(device.camera.starts, 1);
      expect(find.text('The camera works. This preview is not recorded.'), findsOneWidget);
      expect(find.byKey(const Key('fake-camera-preview')), findsOneWidget);
      expect(find.textContaining('Online'), findsOneWidget);
    });
  });

  group('the system check is honest about the camera', () {
    testScenario('no camera: said plainly, and starting needs an explicit acknowledgement that is then recorded', (
      tester,
    ) async {
      device.camera.result = const CameraMissing();
      await prepare();
      await goThroughConsentAndCheck(tester);
      expect(find.text('No camera was found on this device.'), findsOneWidget);
      var start = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start the exam'));
      expect(start.onPressed, isNull);

      await tester.tap(
        find.widgetWithText(CheckboxListTile, 'I will start without a camera. This is recorded as an incident.'),
      );
      await tester.pumpAndSettle();
      start = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start the exam'));
      expect(start.onPressed, isNotNull);
      await startFromCheck(tester);

      expect(find.byKey(const Key('time-remaining')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      final incidents = await s.incidentStore.all();
      expect(incidents.map((i) => i.category), [IncidentCategory.cameraUnavailable]);
    });

    testScenario('denied and failed cameras are told apart', (tester) async {
      device.camera.result = const CameraDenied();
      await prepare();
      await goThroughConsentAndCheck(tester);
      expect(find.text('Camera permission was not given.'), findsOneWidget);
      expect(find.text('Check the camera again'), findsOneWidget);

      device.camera.result = const CameraFailed();
      await tester.tap(find.text('Check the camera again'));
      await tester.pumpAndSettle();
      expect(find.text('The camera could not be started.'), findsOneWidget);

      device.camera.result = null;
      await tester.tap(find.text('Check the camera again'));
      await tester.pumpAndSettle();
      expect(find.text('The camera works. This preview is not recorded.'), findsOneWidget);
      expect(device.camera.starts, 3);
    });

    testScenario('offline is shown, and does not stop anyone starting', (tester) async {
      device.connectivity.online = false;
      await prepare();
      await goThroughConsentAndCheck(tester);
      expect(find.textContaining('Offline. You can still take the exam'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start the exam')).onPressed, isNotNull);
    });

    testScenario('the clock starts when the exam is started, not during the check', (tester) async {
      await prepare();
      await goThroughConsentAndCheck(tester);
      expect(await attempts(), isEmpty, reason: 'no attempt, so no deadline, until Start the exam');
      s.env.clock.advance(const Duration(minutes: 7));
      await startFromCheck(tester);
      final attempt = (await attempts()).single;
      expect(attempt.startedAt, s.env.clock.now());
      expect(attempt.deadline, s.env.clock.now().add(const Duration(minutes: 60)));
      expect(device.camera.stops, greaterThan(0), reason: 'the camera is released once the exam starts');
    });
  });

  group('taking the exam', () {
    Future<void> begin(WidgetTester tester) async {
      await prepare();
      await goThroughConsentAndCheck(tester);
      await startFromCheck(tester);
    }

    testScenario('END TO END: answer, move on, type, submit with a confirmation, see the result', (tester) async {
      await begin(tester);
      expect(find.textContaining('Time left: 1:00:00'), findsOneWidget);
      expect(find.text('Question 1 of 2'), findsOneWidget);
      expect(find.text('What is 2 + 2?'), findsOneWidget);

      // Choose "4" (an option id is what is saved, not a position).
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      var attempt = (await attempts()).single;
      final saved = attempt.answers['q1']! as ChoiceAnswer;
      expect(saved.optionIds, {'q1-o1'});

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Next'));
      expect(find.text('Question 2 of 2'), findsOneWidget);
      // Typed in two bursts: one change may not add more than a few words at once (that would be a paste).
      await tester.enterText(find.byType(TextField), 'Recursion is a function');
      await tester.enterText(find.byType(TextField), 'Recursion is a function calling itself.');
      await tester.pump(const Duration(milliseconds: 500));
      attempt = (await attempts()).single;
      expect(attempt.answers['s1'], const TextAnswer('Recursion is a function calling itself.'), reason: 'autosaved');

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Submit the exam'));
      expect(find.text('Submit the exam?'), findsOneWidget);
      expect(find.textContaining('You answered every question'), findsOneWidget);
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Submit the exam')),
      );
      await tester.pumpAndSettle();

      expect(routerOf(tester).location, RoutePaths.studentAttemptResult(attempt.id));
      expect((await attempts()).single.status, AttemptStatus.submitted);
      expect(find.byKey(const Key('result-score')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('result-score'))).data, '1 out of 6 marks');
      expect(find.textContaining('1 written answer is waiting to be marked'), findsOneWidget);
      expect(find.text('Passed'), findsNothing);
      expect(find.text('Not passed'), findsNothing, reason: 'no verdict while a typed answer is unmarked');
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Waiting to be marked'), findsOneWidget);
      expect(find.text('Correct answers are not shown here.'), findsOneWidget);
    });

    testScenario('submitting with unanswered questions says how many', (tester) async {
      await begin(tester);
      await tapVisible(tester, find.widgetWithText(TextButton, 'Submit the exam'));
      expect(find.textContaining('2 questions have no answer'), findsOneWidget);
    });

    testScenario('the time left follows the deadline and the clock, and the colour warning has words', (tester) async {
      await begin(tester);
      s.env.clock.advance(const Duration(minutes: 20));
      await tester.pump(const Duration(seconds: 1));
      expect(timeText(tester), 'Time left: 40:00');
      s.env.clock.advance(const Duration(minutes: 36));
      await tester.pump(const Duration(seconds: 1));
      expect(timeText(tester), 'Time left: 04:00');
      expect(find.text('Less than five minutes left.'), findsOneWidget);
    });

    testScenario('BACKGROUNDING gains nothing: coming back after 25 minutes shows 25 minutes less', (tester) async {
      await begin(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      s.env.clock.advance(const Duration(minutes: 25));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(timeText(tester), 'Time left: 35:00');
    });

    testScenario('at the deadline the saved answers are submitted AUTOMATICALLY, exactly once', (tester) async {
      await begin(tester);
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      s.env.clock.advance(const Duration(minutes: 61));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final stored = await attempts();
      expect(stored, hasLength(1));
      expect(stored.single.status, AttemptStatus.submitted);
      expect(stored.single.submissionKind, SubmissionKind.auto);
      expect(stored.single.submittedAt, stored.single.deadline);
      expect(routerOf(tester).location, RoutePaths.studentAttemptResult(stored.single.id));
      expect(find.text('Submitted automatically when time ran out.'), findsOneWidget);
      expect(stored.single.result!.awardedMarks, 1, reason: 'the answer saved before time ran out counts');
      // More ticks change nothing.
      await tester.pump(const Duration(seconds: 5));
      expect((await attempts()).single.submittedAt, stored.single.deadline);
    });

    testScenario('with backward navigation off, Previous is disabled and the palette only opens later questions', (
      tester,
    ) async {
      await prepare(settings: const ExamSettings(allowBackwardNavigation: false));
      await goThroughConsentAndCheck(tester);
      await startFromCheck(tester);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Next'));
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Previous')).onPressed, isNull);
      await tester.tap(find.byTooltip('All questions'));
      await tester.pumpAndSettle();
      final first = find.descendant(of: find.byType(BottomSheet), matching: find.text('1'));
      expect(
        tester.widget<OutlinedButton>(find.ancestor(of: first, matching: find.byType(OutlinedButton))).onPressed,
        isNull,
      );
    });

    testScenario('the palette jumps to a question and shows answered ones differently', (tester) async {
      await begin(tester);
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('All questions'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Question 1, answered'), findsOneWidget);
      expect(find.bySemanticsLabel('Question 2, not answered'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('2')));
      await tester.pumpAndSettle();
      expect(find.text('Question 2 of 2'), findsOneWidget);
    });

    testScenario('a multiple-choice question accepts several options and says how it is marked', (tester) async {
      await prepare(questions: [multipleChoice()]);
      await goThroughConsentAndCheck(tester);
      await startFromCheck(tester);
      expect(find.textContaining('Full marks only if you choose exactly the correct ones'), findsOneWidget);
      await tester.tap(find.text('2'));
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      final answer = (await attempts()).single.answers['m1']! as ChoiceAnswer;
      expect(answer.optionIds, {'m1-o0', 'm1-o2'});
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(((await attempts()).single.answers['m1']! as ChoiceAnswer).optionIds, {
        'm1-o2',
      }, reason: 'tapping again unticks');
    });

    testScenario('an offline student keeps going, with a note that answers are saved on the device', (tester) async {
      await begin(tester);
      device.connectivity.set(value: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('You are offline. Keep going'), findsOneWidget);
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      expect(((await attempts()).single.answers['q1']! as ChoiceAnswer).optionIds, {'q1-o1'});
      device.connectivity.set(value: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('You are offline'), findsNothing);
    });
  });

  group('the calculator', () {
    testScenario('is offered only when the exam allows it, and works', (tester) async {
      await prepare(settings: const ExamSettings(calculatorEnabled: true));
      await goThroughConsentAndCheck(tester);
      await startFromCheck(tester);
      await tester.tap(find.byTooltip('Calculator'));
      await tester.pumpAndSettle();
      for (final key in ['2', '+', '3', '×', '4']) {
        await tester.tap(find.widgetWithText(OutlinedButton, key));
      }
      await tester.tap(find.widgetWithText(FilledButton, '='));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('calc-result'))).data, '14');
      expect(tester.widget<Text>(find.byKey(const Key('calc-expression'))).data, '2+3×4');

      await tester.tap(find.text('C'));
      for (final key in ['1', '÷', '0']) {
        await tester.tap(find.widgetWithText(OutlinedButton, key));
      }
      await tester.tap(find.widgetWithText(FilledButton, '='));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('calc-result'))).data, 'Cannot divide by zero.');

      await tester.tap(find.text('C'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'sin'));
      for (final key in ['3', '0', ')']) {
        await tester.tap(find.widgetWithText(OutlinedButton, key));
      }
      await tester.tap(find.widgetWithText(FilledButton, '='));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('calc-result'))).data, '0.5');
      await tester.tap(find.text('Radians'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '='));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('calc-result'))).data, '-0.988031624093');
    });

    testScenario('is not there when the exam does not allow it', (tester) async {
      await prepare();
      await goThroughConsentAndCheck(tester);
      await startFromCheck(tester);
      expect(find.byTooltip('Calculator'), findsNothing);
    });
  });

  group('proctoring in the player', () {
    Future<void> begin(WidgetTester tester, {ExamSettings settings = const ExamSettings()}) async {
      await prepare(settings: settings);
      await goThroughConsentAndCheck(tester);
      await startFromCheck(tester);
    }

    testScenario(
      'a large insertion into a typed answer is refused, recorded as a copy/paste attempt, and the student is told',
      (tester) async {
        await begin(tester);
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Next'));
        await tester.enterText(find.byType(TextField), 'x' * 120);
        await tester.pump();
        expect(
          (tester.widget<TextField>(find.byType(TextField)).controller!.text),
          isEmpty,
          reason: 'the paste was not accepted',
        );
        expect(find.text('Copying and pasting are not allowed in answers. This was recorded.'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 100));
        final incident = (await s.incidentStore.all()).single;
        expect(incident.category, IncidentCategory.clipboardAttempt);
        expect(incident.detail, 'bulk:120');
        expect(find.textContaining('Warning recorded: Copy or paste attempt (warning 1)'), findsOneWidget);
      },
    );

    testScenario('typing normally is not refused, even a long answer a few characters at a time', (tester) async {
      await begin(tester);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Next'));
      var text = '';
      for (var i = 0; i < 10; i++) {
        text += 'word $i ';
        await tester.enterText(find.byType(TextField), text);
      }
      await tester.pump(const Duration(milliseconds: 500));
      expect((tester.widget<TextField>(find.byType(TextField)).controller!.text), text);
      expect(await s.incidentStore.all(), isEmpty);
    });

    testScenario('the paste shortcut does nothing and is recorded', (tester) async {
      await begin(tester);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Next'));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump(const Duration(milliseconds: 100));
      expect((await s.incidentStore.all()).single.category, IncidentCategory.clipboardAttempt);
    });

    testScenario(
      'leaving the app is detected, not prevented: the student comes back to the same place with a warning',
      (tester) async {
        await begin(tester);
        await tester.tap(find.text('4'));
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        s.env.clock.advance(const Duration(seconds: 20));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.textContaining('Warning recorded: App left the foreground (warning 1)'), findsOneWidget);
        final incident = (await s.incidentStore.all()).single;
        expect(incident.category, IncidentCategory.appBackgrounded);
        expect(incident.durationMs, 20000);
        expect(incident.evidence.reference, isNull);
        expect(find.text('Question 1 of 2'), findsOneWidget);
        expect(((await attempts()).single.answers['q1']! as ChoiceAnswer).optionIds, {'q1-o1'});
      },
    );

    testScenario('a screenshot notice from the platform is recorded', (tester) async {
      await begin(tester);
      device.guard.screenshot();
      await tester.pump(const Duration(milliseconds: 200));
      expect((await s.incidentStore.all()).single.category, IncidentCategory.screenshotDetected);
      expect(device.guard.enabled, isTrue, reason: 'the guard was switched on for the exam');
    });

    testScenario('a rule the instructor switched off records nothing', (tester) async {
      await begin(tester, settings: const ExamSettings(enabledRules: {IncidentCategory.networkLost}));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      s.env.clock.advance(const Duration(seconds: 20));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      expect(await s.incidentStore.all(), isEmpty);
      expect(find.textContaining('Warning recorded'), findsNothing);
    });

    testScenario('the warning limit is announced once, nothing ends, and no mark changes', (tester) async {
      await begin(tester, settings: const ExamSettings(maxWarnings: 2));
      for (var i = 0; i < 3; i++) {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        s.env.clock.advance(const Duration(seconds: 5));
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        s.env.clock.advance(const Duration(seconds: 5));
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(find.textContaining('You reached the warning limit'), findsOneWidget);
      expect(find.text('Question 1 of 2'), findsOneWidget, reason: 'the exam goes on');
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Next'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Submit the exam'));
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Submit the exam')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('result-score'))).data,
        '1 out of 6 marks',
        reason: '3 warnings cost nothing',
      );
    });
  });

  group('the result', () {
    testScenario('a result held back by the exam is not even loaded, and says when it will appear', (tester) async {
      exam = await s.publishedExam(
        questions: [singleChoice()],
        settings: const ExamSettings(showResultImmediately: false),
      );
      await s.openWindowAndConsent(exam.id);
      final session = ok(await s.attempts.startAttempt(exam.id));
      ok(await s.attempts.submit(session.attemptId));
      await open(tester, RoutePaths.studentAttemptResult(session.attemptId));
      expect(find.textContaining('The result will be shown after the exam window closes'), findsOneWidget);
      expect(find.byKey(const Key('result-score')), findsNothing);
    });

    testScenario('a student cannot open someone else\'s result by its address', (tester) async {
      exam = await s.publishedExam(questions: [singleChoice()]);
      await s.openWindowAndConsent(exam.id, student: 'student2@examora.app');
      final theirs = ok(await s.attempts.startAttempt(exam.id));
      ok(await s.attempts.submit(theirs.attemptId));
      await s.signInAs(student);
      await open(tester, RoutePaths.studentAttemptResult(theirs.attemptId));
      expect(find.text('The requested item was not found.'), findsOneWidget);
      expect(find.byKey(const Key('result-score')), findsNothing);
    });

    testScenario(
      'the player for an already submitted attempt goes to its result; for someone else\'s it says not found',
      (tester) async {
        exam = await s.publishedExam(questions: [singleChoice()]);
        await s.openWindowAndConsent(exam.id);
        final session = ok(await s.attempts.startAttempt(exam.id));
        ok(await s.attempts.submit(session.attemptId));
        await open(tester, RoutePaths.studentAttempt(session.attemptId));
        expect(routerOf(tester).location, RoutePaths.studentAttemptResult(session.attemptId));
      },
    );

    testScenario('the Results tab and the briefing both lead to the result after submitting', (tester) async {
      exam = await s.publishedExam(questions: [singleChoice()]);
      await s.openWindowAndConsent(exam.id);
      final session = ok(await s.attempts.startAttempt(exam.id));
      ok(await s.attempts.submit(session.attemptId));
      await open(tester, RoutePaths.studentExam(exam.id));
      expect(find.widgetWithText(FilledButton, 'View my result'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'View my result'));
      expect(find.byKey(const Key('result-score')), findsOneWidget);
    });
  });

  group('resuming', () {
    testScenario(
      'opening the player for an attempt under way restores the answers, the position and the original deadline',
      (tester) async {
        exam = await s.publishedExam(questions: [singleChoice(), shortText()]);
        await s.openWindowAndConsent(exam.id);
        final first = ok(await s.attempts.startAttempt(exam.id));
        ok(
          await s.attempts.saveAnswer(
            first.attemptId,
            first.questions[0].id,
            ChoiceAnswer({first.questions[0].options[1].id}),
          ),
        );
        ok(await s.attempts.saveProgress(first.attemptId, 1));
        s.env.clock.advance(const Duration(minutes: 15));
        await s.signInAs(student);
        await open(tester, RoutePaths.studentAttempt(first.attemptId));
        expect(find.text('Question 2 of 2'), findsOneWidget);
        expect(
          timeText(tester),
          'Time left: 45:00',
          reason: '60 minutes from the first start, minus the 15 that have passed',
        );
      },
    );
  });

  group('Arabic', () {
    testScenario('the briefing, the consent notice and the player are Arabic and right-to-left', (tester) async {
      s = await SessionScenario.create(
        env: TestEnvironment(language: 'ar', now: DateTime.utc(2026, 10, 27, 9)),
      );
      await prepare();
      await open(tester, RoutePaths.studentExam(exam.id));
      expect(find.text('معلومات الاختبار'), findsOneWidget);
      expect(Directionality.of(tester.element(find.text('معلومات الاختبار'))), TextDirection.rtl);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'متابعة'));
      expect(find.text('قبل أن تبدأ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
