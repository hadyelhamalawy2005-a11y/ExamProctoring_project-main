import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/data/local_exam_repository.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';
import '../../support/stored_session.dart';
import '../../support/test_harness.dart';

/// These build the REAL app and drive an instructor through creating, checking and publishing an exam.
void main() {
  late TestEnvironment env;

  setUp(() => env = TestEnvironment(now: DateTime.utc(2026, 10, 27, 9)));

  Future<void> openExamsTab(WidgetTester tester) async {
    await startSignedIn(env, 'instructor@examora.app');
    await pumpExamora(tester, env);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Exams')));
    await tester.pumpAndSettle();
  }

  Future<List<Exam>> storedExams(WidgetTester tester) async => containerOf(tester).read(localExamStoreProvider).all();

  Future<void> fillDetails(
    WidgetTester tester, {
    String title = 'Algorithms midterm',
    String course = 'CS201',
    String minutes = '60',
    String passMark = '50',
  }) async {
    await enterField(tester, 'Exam title', title);
    await enterField(tester, 'Course name', course);
    await enterField(tester, 'Duration (minutes)', minutes);
    await enterField(tester, 'Pass mark (% of the total marks)', passMark);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save and continue'));
  }

  Future<void> addSingleChoice(
    WidgetTester tester, {
    String text = 'What is 2 + 2?',
    String marks = '1',
    List<String> options = const ['3', '4'],
    int correct = 1,
  }) async {
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Add question'));
    await enterField(tester, 'Question', text);
    await enterField(tester, 'Marks', marks);
    for (var index = 0; index < options.length; index++) {
      if (index >= 2) {
        await tapVisible(tester, find.text('Add option'));
      }
      await enterField(tester, 'Option ${index + 1}', options[index]);
    }
    await tapVisible(tester, find.byTooltip('Correct answer').at(correct));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Save question'));
  }

  Future<void> pickDateTime(WidgetTester tester, {required int index, int extraDays = 0}) async {
    await tapVisible(tester, find.text('Choose date and time').at(index));
    if (extraDays > 0) {
      // Initial date is tomorrow (28th); pick later days in the calendar.
      await tester.tap(find.text('${28 + extraDays}').last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  group('the exam list', () {
    testWidgets('an instructor with no exams sees an empty state, not an error', (tester) async {
      await openExamsTab(tester);
      expect(routerOf(tester).location, RoutePaths.instructorExams);
      expect(find.text('No exams yet'), findsOneWidget);
      expect(find.text('Create your first exam to get started.'), findsOneWidget);
      expect(find.text('This did not load'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Create exam'), findsOneWidget);
    });

    testWidgets('a storage failure is an error with a retry button, never "no exams"', (tester) async {
      env.keyValueStore.values['local.exams.v1'] = 'garbage';
      await openExamsTab(tester);
      expect(find.text('This did not load'), findsOneWidget);
      expect(find.text('No exams yet'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('exams appear with their status as a word, filtered by status', (tester) async {
      await openExamsTab(tester);
      final repo = containerOf(tester).read(examRepositoryProvider);
      final a = ok(await repo.createExam(details(title: 'Draft one')));
      ok(await repo.saveQuestion(a.id, singleChoice(), confirmsAnswerKey: true));
      final b = ok(await repo.createExam(details(title: 'To be scheduled')));
      ok(await repo.saveQuestion(b.id, singleChoice(), confirmsAnswerKey: true));
      ok(
        await repo.updateSchedule(b.id, opensAt: DateTime.utc(2026, 11, 1, 9), closesAt: DateTime.utc(2026, 11, 1, 12)),
      );
      ok(await repo.publish(b.id));

      await tester.tap(find.byTooltip('Home').first, warnIfMissed: false);
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Home')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Exams')));
      await tester.pumpAndSettle();
      // The tab keeps its state, so go through the create screen and back to refresh.
      await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Draft one'), findsOneWidget);
      expect(find.text('To be scheduled'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Scheduled'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Scheduled'));
      await tester.pumpAndSettle();
      expect(find.text('To be scheduled'), findsOneWidget);
      expect(find.text('Draft one'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Ongoing'));
      await tester.pumpAndSettle();
      expect(find.text('No exam has this status.'), findsOneWidget);
    });
  });

  group('creating an exam', () {
    testWidgets('offers EXACTLY two ways, and nothing that generates exams from other material', (tester) async {
      await openExamsTab(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
      await tester.pumpAndSettle();

      expect(routerOf(tester).location, RoutePaths.instructorNewExamMethod);
      expect(find.byKey(const Key('method-manual')), findsOneWidget);
      expect(find.byKey(const Key('method-word')), findsOneWidget);
      expect(find.text('Create manually'), findsOneWidget);
      expect(find.text('Import from Word'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
      for (final forbidden in ['AI', 'generate', 'Generate', 'PDF', 'lecture']) {
        expect(find.textContaining(forbidden), findsNothing, reason: forbidden);
      }
    });

    testWidgets('both ways start with the details, so the exam has a title before anything is saved', (tester) async {
      await openExamsTab(tester);
      for (final key in ['method-manual', 'method-word']) {
        await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(routerOf(tester).location, startsWith('/instructor/exams/new/edit'), reason: key);
        expect(find.text('Step 1 of 5 · Details'), findsOneWidget, reason: key);
        expect(find.text('Exam title'), findsOneWidget, reason: key);
        expect(await storedExams(tester), isEmpty, reason: 'nothing is saved before the details are');
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the details are validated on screen, field by field', (tester) async {
      await openExamsTab(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('method-manual')));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save and continue'));
      expect(find.text('This field is required.'), findsNWidgets(4));
      expect(await storedExams(tester), isEmpty);

      await fillDetails(tester, minutes: '0', passMark: '101');
      expect(find.text('This number is outside the allowed range.'), findsNWidgets(2));
      expect(await storedExams(tester), isEmpty);
    });

    testWidgets('Arabic-Indic digits are understood in the number fields', (tester) async {
      await openExamsTab(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('method-manual')));
      await tester.pumpAndSettle();
      await fillDetails(tester, minutes: '٩٠', passMark: '٥٥٫٥');
      final saved = (await storedExams(tester)).single;
      expect(saved.durationMinutes, 90);
      expect(saved.passMarkPercent, 55.5);
    });

    testWidgets('END TO END by hand: details, three kinds of question, settings, schedule, publish', (tester) async {
      await openExamsTab(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('method-manual')));
      await tester.pumpAndSettle();

      await fillDetails(tester);
      expect((await storedExams(tester)).single.lifecycle, ExamLifecycle.draft);
      expect(find.text('Step 2 of 5 · Questions'), findsOneWidget);
      expect(find.textContaining('No questions yet'), findsOneWidget);

      // Single choice.
      await addSingleChoice(tester);
      expect(find.text('What is 2 + 2?'), findsOneWidget);
      expect(find.text('Single choice'), findsOneWidget);
      expect(find.text('1 mark'), findsOneWidget);

      // Multiple choice.
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add question'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Multiple choice'));
      await tester.pumpAndSettle();
      expect(find.textContaining('all or nothing'), findsOneWidget);
      await enterField(tester, 'Question', 'Which are prime?');
      await enterField(tester, 'Marks', '2.5');
      await enterField(tester, 'Option 1', '2');
      await enterField(tester, 'Option 2', '4');
      await tapVisible(tester, find.text('Add option'));
      await enterField(tester, 'Option 3', '5');
      await tapVisible(tester, find.byTooltip('Correct answer').at(0));
      await tapVisible(tester, find.byTooltip('Correct answer').at(2));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save question'));
      expect(find.text('Multiple choice'), findsOneWidget);

      // Short text.
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add question'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Short text'));
      await tester.pumpAndSettle();
      expect(find.textContaining('never marks it'), findsOneWidget);
      expect(find.text('Option 1'), findsNothing);
      await enterField(tester, 'Question', 'Explain recursion.');
      await enterField(tester, 'Marks', '5');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save question'));
      expect(find.text('Short text'), findsOneWidget);
      expect(find.text('3 questions · 8.5 marks in total'), findsOneWidget);

      var stored = (await storedExams(tester)).single;
      expect(stored.questions.map((q) => q.type), [
        QuestionType.singleChoice,
        QuestionType.multipleChoice,
        QuestionType.shortText,
      ]);
      expect(stored.questions[1].options.where((o) => o.isCorrect).map((o) => o.text), ['2', '5']);
      expect(stored.questions[2].options, isEmpty);

      // Reorder, then delete.
      await tapVisible(tester, find.byTooltip('Move up').last);
      stored = (await storedExams(tester)).single;
      expect(stored.questions.map((q) => q.type).last, QuestionType.multipleChoice);
      await tapVisible(tester, find.byTooltip('Delete').first);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect((await storedExams(tester)).single.questions.length, 3, reason: 'cancelling deletes nothing');

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Next'));

      // Settings.
      expect(find.text('Step 3 of 5 · Settings'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(SwitchListTile, 'Allow the scientific calculator'));
      await tapVisible(tester, find.widgetWithText(SwitchListTile, 'Shuffle the order of options'));
      // The rules that need a face, gaze or speech model are listed, off, and cannot be switched on.
      final gaze = find.widgetWithText(CheckboxListTile, 'Looking away');
      await tester.ensureVisible(gaze);
      expect(tester.widget<CheckboxListTile>(gaze).value, isFalse);
      expect(tester.widget<CheckboxListTile>(gaze).onChanged, isNull);
      expect(find.textContaining('this build has no face, gaze or speech detector'), findsWidgets);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save and continue'));
      stored = (await storedExams(tester)).single;
      expect(stored.settings.calculatorEnabled, isTrue);
      expect(stored.settings.randomizeOptions, isTrue);
      expect(stored.settings.sustainedThresholdSeconds, 10);

      // Schedule: nothing is pre-filled.
      expect(find.text('Step 4 of 5 · Schedule'), findsOneWidget);
      expect(find.text('Not set'), findsNWidgets(2));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save and continue'));
      expect(find.text('This field is required.'), findsNWidgets(2));

      await pickDateTime(tester, index: 0);
      await pickDateTime(tester, index: 1);
      // Same instant for both: shorter than the 60 minute duration.
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save and continue'));
      expect(find.text('The window must be at least as long as the exam duration.'), findsOneWidget);

      await pickDateTime(tester, index: 1, extraDays: 1);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save and continue'));
      expect(find.text('Step 5 of 5 · Review and publish'), findsOneWidget);
      stored = (await storedExams(tester)).single;
      expect(stored.closesAt!.difference(stored.opensAt!), const Duration(days: 1));

      // Review and publish.
      expect(find.text('Ready to publish'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Publish exam'));
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Publish exam')),
      );
      await tester.pumpAndSettle();
      expect((await storedExams(tester)).single.lifecycle, ExamLifecycle.published);
      expect(find.text('Scheduled'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Return to draft'), findsOneWidget);
    });

    testWidgets('publishing is refused with EVERY reason, and each one jumps to the step that fixes it', (
      tester,
    ) async {
      await openExamsTab(tester);
      final repo = containerOf(tester).read(examRepositoryProvider);
      final exam = ok(await repo.createExam(details()));
      ok(await repo.addQuestions(exam.id, [singleChoice(needsReview: true)]));
      final original = singleChoice(id: 'b');
      ok(await repo.saveQuestion(exam.id, original, confirmsAnswerKey: true));
      ok(
        await repo.saveQuestion(
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
      ok(
        await repo.updateSchedule(
          exam.id,
          opensAt: DateTime.utc(2026, 10, 27, 9),
          closesAt: DateTime.utc(2026, 10, 27, 12),
        ),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Algorithms midterm'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Review and publish'));
      await tester.pumpAndSettle();

      expect(find.text('3 things to fix before publishing'), findsOneWidget);
      expect(find.textContaining('Question 1: The question is flagged for review'), findsOneWidget);
      expect(find.textContaining('Question 2: The options changed after the correct answer was set'), findsOneWidget);
      expect(find.textContaining('The start time has already passed'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Publish exam'));
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Publish exam')),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 things to fix before publishing'), findsOneWidget);
      expect(ok(await repo.getExam(exam.id)).lifecycle, ExamLifecycle.draft);

      // A problem in the schedule jumps to the schedule step.
      await tapVisible(tester, find.textContaining('The start time has already passed'));
      expect(find.text('Step 4 of 5 · Schedule'), findsOneWidget);
    });

    testWidgets('an imported question flagged for review shows its badge and must be explicitly confirmed', (
      tester,
    ) async {
      await openExamsTab(tester);
      final repo = containerOf(tester).read(examRepositoryProvider);
      final exam = ok(await repo.createExam(details()));
      ok(
        await repo.addQuestions(exam.id, [singleChoice(needsReview: true).copyWith(source: QuestionSource.wordImport)]),
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Algorithms midterm'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Questions'));
      await tester.pumpAndSettle();
      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('WORD'), findsOneWidget);

      await tester.tap(find.text('What is 2 + 2?'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save question'));
      expect(find.text('This field is required.'), findsOneWidget, reason: 'the instructor must tick the confirmation');
      expect(ok(await repo.getExam(exam.id)).questions.single.needsReview, isTrue);

      await tapVisible(tester, find.text('I have checked which option(s) are correct'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save question'));
      expect(ok(await repo.getExam(exam.id)).questions.single.needsReview, isFalse);
      expect(find.text('Needs review'), findsNothing);
    });

    testWidgets('an invalid question lists every problem and saves nothing', (tester) async {
      await openExamsTab(tester);
      final repo = containerOf(tester).read(examRepositoryProvider);
      final exam = ok(await repo.createExam(details()));
      await tester.tap(find.widgetWithText(FilledButton, 'Create exam'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Algorithms midterm'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Questions'));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add question'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save question'));
      expect(find.text('The question has no text.'), findsOneWidget);
      expect(find.textContaining('Marks must be above 0'), findsOneWidget);
      expect(find.text('An option has no text.'), findsOneWidget);
      expect(find.text('No option is marked as correct.'), findsOneWidget);
      expect(ok(await repo.getExam(exam.id)).questions, isEmpty);
    });
  });

  group('exams that cannot be edited', () {
    testWidgets('a published exam that has opened shows a notice and every save is disabled', (tester) async {
      await startSignedIn(env, 'instructor@examora.app');
      final repo = LocalExamRepository(
        exams: JsonCollectionStore<Exam>(
          store: env.keyValueStore,
          key: 'local.exams.v1',
          fromJson: Exam.fromJson,
          toJson: (exam) => exam.toJson(),
        ),
        caller: LocalCaller(
          accounts: LocalAccountStore(store: env.keyValueStore, hasher: TestEnvironment.fastHasher, clock: env.clock),
          sessions: LocalSessionStore(env.secureStore),
          clock: env.clock,
        ),
        clock: env.clock,
      );
      final exam = ok(await repo.createExam(details()));
      ok(await repo.saveQuestion(exam.id, singleChoice(), confirmsAnswerKey: true));
      ok(
        await repo.updateSchedule(
          exam.id,
          opensAt: DateTime.utc(2026, 10, 28, 9),
          closesAt: DateTime.utc(2026, 10, 28, 12),
        ),
      );
      ok(await repo.publish(exam.id));
      env.clock.setTo(DateTime.utc(2026, 10, 28, 10));
      await startSignedIn(env, 'instructor@examora.app');

      await pumpExamora(tester, env, initialLocation: RoutePaths.instructorExamEdit(exam.id));
      expect(find.text('This exam can no longer be edited because it has opened or was archived.'), findsOneWidget);
      final save = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save and continue'));
      expect(save.onPressed, isNull);
    });
  });

  group('instructors cannot reach each other\'s exams', () {
    testWidgets('a deep link to someone else\'s exam is "not found", never its content', (tester) async {
      await startSignedIn(env, 'instructor@examora.app');
      await pumpExamora(tester, env, initialLocation: RoutePaths.instructorExamEdit('not-mine'));
      expect(find.text('The requested item was not found.'), findsOneWidget);
      expect(find.text('Exam title'), findsNothing);
    });

    testWidgets('students and administrators are sent away from the wizard routes', (tester) async {
      await startSignedIn(env, 'student@examora.app');
      await pumpExamora(tester, env, initialLocation: RoutePaths.instructorNewExamMethod);
      expect(routerOf(tester).location, RoutePaths.studentDashboard);
    });
  });

  group('Arabic', () {
    testWidgets('the exam list, the method choice and the wizard are Arabic', (tester) async {
      env = TestEnvironment(language: 'ar', now: DateTime.utc(2026, 10, 27, 9));
      await startSignedIn(env, 'instructor@examora.app');
      await pumpExamora(tester, env, initialLocation: RoutePaths.instructorExams);
      expect(find.text('الاختبارات'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'إنشاء اختبار'));
      await tester.pumpAndSettle();
      expect(find.text('إنشاء يدوي'), findsOneWidget);
      expect(find.text('استيراد من Word'), findsOneWidget);
      await tester.tap(find.byKey(const Key('method-manual')));
      await tester.pumpAndSettle();
      expect(find.text('الخطوة 1 من 5 · البيانات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
