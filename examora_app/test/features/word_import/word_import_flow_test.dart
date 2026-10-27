import 'dart:io';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/features/exams/data/exam_providers.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/word_import/data/word_file_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/docx_builder.dart';
import '../../support/exam_fixtures.dart';
import '../../support/exam_repo.dart';
import '../../support/stored_session.dart';
import '../../support/test_harness.dart';

/// A file chooser that hands the test a prepared file, and records what the app did with it.
final class FakeWordFileSource implements WordFileSource {
  PickedWordFile? next;
  bool bytesRead = false;
  int picks = 0;
  bool saveWorks = true;
  final List<String> saved = [];

  void offer(String name, Uint8List bytes, {int? sizeOverride}) {
    next = PickedWordFile(
      name: name,
      size: sizeOverride ?? bytes.length,
      read: () async {
        bytesRead = true;
        return bytes;
      },
    );
  }

  @override
  Future<PickedWordFile?> pick() async {
    picks++;
    return next;
  }

  @override
  Future<bool> save({required String fileName, required Uint8List bytes}) async {
    if (!saveWorks) throw StateError('no dialog here');
    saved.add(fileName);
    return true;
  }
}

List<String> goodQuestion(int n, {String answer = 'A', String? marks = '1', String tag = 'MCQ'}) => [
  'Question $n [$tag]',
  'Text of question $n?',
  'A. first',
  'B. second',
  'Correct Answer: $answer',
  if (marks != null) 'Marks: $marks',
];

void main() {
  late TestEnvironment env;
  late FakeWordFileSource files;
  late String examId;

  setUp(() async {
    env = TestEnvironment(now: DateTime.utc(2026, 10, 27, 9));
    files = FakeWordFileSource();
    await startSignedIn(env, 'instructor@examora.app');
    examId = ok(await examRepositoryFor(env).createExam(details())).id;
  });

  Future<void> openImport(WidgetTester tester) async {
    await pumpExamora(
      tester,
      env,
      initialLocation: RoutePaths.instructorExamImport(examId),
      extra: [wordFileSourceProvider.overrideWithValue(files)],
    );
  }

  Future<void> choose(WidgetTester tester, String name, Uint8List bytes, {int? sizeOverride}) async {
    files.offer(name, bytes, sizeOverride: sizeOverride);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Choose a .docx file'));
  }

  String summary(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('import-summary'))).data!;

  Future<List<Question>> storedQuestions(WidgetTester tester) async =>
      (await containerOf(tester).read(localExamStoreProvider).all()).single.questions;

  group('the start screen', () {
    testWidgets('explains what happens and offers to choose a file; nothing is imported yet', (tester) async {
      await openImport(tester);
      expect(find.text('Import from Word'), findsOneWidget);
      expect(
        find.textContaining('Nothing is added to the exam until you have reviewed every question'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Choose a .docx file'), findsOneWidget);
      expect(files.picks, 0);
    });

    testWidgets('cancelling the chooser changes nothing', (tester) async {
      await openImport(tester);
      files.next = null;
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Choose a .docx file'));
      expect(find.widgetWithText(FilledButton, 'Choose a .docx file'), findsOneWidget);
      expect(files.picks, 1);
    });

    testWidgets('the help button shows the rules and the shipped template, and can copy and save it', (tester) async {
      String? clipboard;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await openImport(tester);
      await tester.tap(find.byTooltip('Template and rules'));
      await tester.pumpAndSettle();
      expect(find.text('The Examora question template'), findsOneWidget);
      expect(find.textContaining('Each question starts with "Question 1 [MCQ]"'), findsOneWidget);
      final template = tester.widget<SelectableText>(find.byKey(const Key('template-text'))).data!;
      expect(template, contains('Question 1 [MCQ]'));
      expect(template, contains('Correct Answer: A, C'));
      expect(template, contains('Marks: 5'));

      await tapVisible(tester, find.text('Copy template text'));
      expect(clipboard, template);
      expect(find.text('Template text copied.'), findsOneWidget);

      await tapVisible(tester, find.text('Save template (.docx)'));
      expect(files.saved, ['examora_question_template.docx']);
      expect(find.text('Template saved.'), findsOneWidget);

      files.saveWorks = false;
      await tapVisible(tester, find.text('Save template (.docx)'));
      expect(find.text('The template could not be saved here. Copy its text instead.'), findsOneWidget);
    });
  });

  group('files that cannot be imported say why, and can be replaced', () {
    Future<void> expectRejected(WidgetTester tester, String name, Uint8List bytes, String message, {int? size}) async {
      await choose(tester, name, bytes, sizeOverride: size);
      expect(find.textContaining(message), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Choose a .docx file'),
        findsOneWidget,
        reason: 'the person can try another file',
      );
      expect(await storedQuestions(tester), isEmpty);
    }

    testWidgets('an older .doc', (tester) async {
      await openImport(tester);
      await expectRejected(tester, 'old.doc', Uint8List.fromList([1, 2, 3]), 'This is an older Word file (.doc)');
    });

    testWidgets('a PDF renamed to .docx', (tester) async {
      await openImport(tester);
      await expectRejected(
        tester,
        'looks-like-word.docx',
        Uint8List.fromList('%PDF-1.7 hello'.codeUnits),
        'This is a PDF, even if its name ends in .docx',
      );
    });

    testWidgets('some other file', (tester) async {
      await openImport(tester);
      await expectRejected(
        tester,
        'photo.png',
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]),
        'Only Word documents saved as .docx',
      );
    });

    testWidgets('a file over 10 MB is refused BEFORE its content is read', (tester) async {
      await openImport(tester);
      await expectRejected(tester, 'huge.docx', Uint8List(10), 'larger than 10 MB', size: 10 * 1024 * 1024 + 1);
      expect(files.bytesRead, isFalse, reason: 'the size is checked before anything is read or parsed');
    });

    testWidgets('a rejected file followed by a good one works', (tester) async {
      await openImport(tester);
      await choose(tester, 'old.doc', Uint8List.fromList([1]));
      await choose(tester, 'ok.docx', buildDocx(paragraphs: goodQuestion(1)));
      expect(summary(tester), '1 found · 1 ready · 0 need attention · 0 not imported');
      expect(find.textContaining('older Word file'), findsNothing);
    });
  });

  group('the review', () {
    testWidgets('a clean document: every question ready, the summary says so, and Continue adds them all', (
      tester,
    ) async {
      await openImport(tester);
      await choose(
        tester,
        'exam.docx',
        buildDocx(
          paragraphs: [
            ...goodQuestion(1),
            ...goodQuestion(2, answer: 'B'),
            ...goodQuestion(3, tag: 'Multiple', answer: 'A, B'),
          ],
        ),
      );
      expect(summary(tester), '3 found · 3 ready · 0 need attention · 0 not imported');
      expect(find.text('Ready'), findsNWidgets(3));
      expect(find.text('File: exam.docx'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add to the exam (3)'));
      final stored = await storedQuestions(tester);
      expect(stored.map((q) => q.text), ['Text of question 1?', 'Text of question 2?', 'Text of question 3?']);
      expect(stored.every((q) => q.source == QuestionSource.wordImport), isTrue);
      expect(stored.every((q) => !q.needsReview), isTrue);
      expect(stored[1].correctOptionIds, {stored[1].options[1].id});
      expect(stored[2].type, QuestionType.multipleChoice);
      expect(
        routerOf(tester).location,
        isNot(RoutePaths.instructorExamImport(examId)),
        reason: 'back out of the importer',
      );
    });

    testWidgets(
      'NO Marks: line: the question needs attention, nothing is invented, and Continue stays disabled until marks are typed',
      (tester) async {
        await openImport(tester);
        await choose(tester, 'exam.docx', buildDocx(paragraphs: [...goodQuestion(1), ...goodQuestion(2, marks: null)]));
        expect(summary(tester), '2 found · 1 ready · 1 need attention · 0 not imported');
        expect(find.text('Needs attention'), findsOneWidget);
        expect(find.textContaining('There is no "Marks:" line'), findsOneWidget);

        final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add to the exam (1)'));
        expect(button.onPressed, isNull);
        expect(find.textContaining('Fix the questions that cannot be added yet'), findsOneWidget);

        // Typing the marks is the person's choice, and settles the issue.
        final marksField = find.widgetWithText(TextField, 'Marks').last;
        await tester.ensureVisible(marksField);
        await tester.enterText(marksField, '2.5');
        await tester.pumpAndSettle();
        expect(summary(tester), '2 found · 2 ready · 0 need attention · 0 not imported');
        expect(find.textContaining('There is no "Marks:" line'), findsNothing);

        await tapVisible(tester, find.widgetWithText(FilledButton, 'Add to the exam (2)'));
        expect((await storedQuestions(tester)).last.marks, 2.5);
      },
    );

    testWidgets('the filter shows only the questions that need attention', (tester) async {
      await openImport(tester);
      await choose(
        tester,
        'exam.docx',
        buildDocx(paragraphs: [...goodQuestion(1), ...goodQuestion(2, marks: null), ...goodQuestion(3)]),
      );
      expect(find.byType(Card), findsNWidgets(3));
      await tapVisible(tester, find.widgetWithText(SwitchListTile, 'Only questions needing attention'));
      expect(find.text('Question 2 · line 7'), findsOneWidget);
      expect(find.text('Question 1 · line 1'), findsNothing);
      expect(find.text('Question 3 · line 13'), findsNothing);
    });

    testWidgets('a missing answer is flagged and never guessed', (tester) async {
      await openImport(tester);
      await choose(tester, 'exam.docx', buildDocx(paragraphs: ['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Marks: 1']));
      expect(summary(tester), '1 found · 0 ready · 1 need attention · 0 not imported');
      expect(find.text('No option is marked as correct.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add to the exam (0)')).onPressed, isNull);
    });

    testWidgets('an ambiguous answer (several for single choice, or an unknown letter) is flagged', (tester) async {
      await openImport(tester);
      await choose(
        tester,
        'exam.docx',
        buildDocx(
          paragraphs: [
            ...goodQuestion(1, answer: 'A, B'),
            ...goodQuestion(2, answer: 'E'),
          ],
        ),
      );
      expect(summary(tester), '2 found · 0 ready · 2 need attention · 0 not imported');
      expect(find.textContaining('Several options are marked correct'), findsOneWidget);
      expect(find.textContaining('The correct answer "E" does not match any option'), findsOneWidget);
    });

    testWidgets('a guess about the type needs the instructor to confirm they checked it', (tester) async {
      await openImport(tester);
      await choose(tester, 'exam.docx', buildDocx(paragraphs: ['Q1: x?', 'A) a', 'B) b', 'Answer: A', 'Marks: 1']));
      expect(summary(tester), '1 found · 0 ready · 1 need attention · 0 not imported');
      expect(find.textContaining('guessed from its shape'), findsOneWidget);
      // It can still be added (it is valid), but it comes in flagged for review.
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'I checked this question'));
      expect(summary(tester), '1 found · 1 ready · 0 need attention · 0 not imported');
      expect(find.text('Checked'), findsOneWidget);
    });

    testWidgets(
      'an unconfirmed doubt is added to the exam flagged for review, which blocks publishing until it is opened',
      (tester) async {
        await openImport(tester);
        await choose(tester, 'exam.docx', buildDocx(paragraphs: ['Q1: x?', 'A) a', 'B) b', 'Answer: A', 'Marks: 1']));
        await tapVisible(tester, find.widgetWithText(FilledButton, 'Add to the exam (1)'));
        final question = (await storedQuestions(tester)).single;
        expect(question.needsReview, isTrue);
        expect(question.source, QuestionSource.wordImport);
      },
    );

    testWidgets('questions can be left out and brought back; with none kept, Continue is disabled and says why', (
      tester,
    ) async {
      await openImport(tester);
      await choose(tester, 'exam.docx', buildDocx(paragraphs: [...goodQuestion(1), ...goodQuestion(2)]));
      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Do not import').first);
      expect(summary(tester), '2 found · 1 ready · 0 need attention · 1 not imported');
      expect(find.text('Not imported'), findsOneWidget);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Do not import').first);
      expect(summary(tester), '2 found · 0 ready · 0 need attention · 2 not imported');
      expect(find.text('Keep at least one question to continue.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add to the exam (0)')).onPressed, isNull);

      await tapVisible(tester, find.widgetWithText(OutlinedButton, 'Import this question').first);
      expect(summary(tester), '2 found · 1 ready · 0 need attention · 1 not imported');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add to the exam (1)'));
      expect((await storedQuestions(tester)).map((q) => q.text), ['Text of question 1?']);
    });

    testWidgets('edits are made on screen: the text, an option, the answer and the type', (tester) async {
      await openImport(tester);
      await choose(tester, 'exam.docx', buildDocx(paragraphs: goodQuestion(1)));
      await tester.enterText(find.widgetWithText(TextField, 'Question').first, 'Reworded?');
      await tester.enterText(find.widgetWithText(TextField, 'Option 2'), 'second, fixed');
      await tapVisible(tester, find.byTooltip('Correct answer').at(1));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add to the exam (1)'));
      final question = (await storedQuestions(tester)).single;
      expect(question.text, 'Reworded?');
      expect(question.options[1].text, 'second, fixed');
      expect(question.correctOptionIds, {question.options[1].id});
    });

    testWidgets('"As written in the document" shows the file\'s own words, even after an edit', (tester) async {
      await openImport(tester);
      await choose(tester, 'exam.docx', buildDocx(paragraphs: goodQuestion(1)));
      await tester.enterText(find.widgetWithText(TextField, 'Question').first, 'Reworded?');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('As written in the document'));
      expect(find.text('1: Question 1 [MCQ]'), findsOneWidget);
      expect(find.text('2: Text of question 1?'), findsOneWidget);
      expect(find.text('5: Correct Answer: A'), findsOneWidget);
    });

    testWidgets('text that belongs to no question, and content that cannot be imported, are listed', (tester) async {
      await openImport(tester);
      await choose(
        tester,
        'exam.docx',
        buildDocx(
          bodyXml: [
            para('Read each question carefully.'),
            ...goodQuestion(1).map(para),
            imagePara(),
            tablePart('Table of constants'),
            para('Good luck!'),
          ].join(),
        ),
      );
      expect(find.text('Text that belongs to no question'), findsOneWidget);
      expect(find.text('1: Read each question carefully.'), findsOneWidget);
      expect(find.text('8: Good luck!'), findsOneWidget);
      expect(find.text('Content that could not be imported'), findsOneWidget);
      expect(find.text('A picture or drawing after line 7'), findsOneWidget);
      expect(find.text('A table after line 7'), findsOneWidget);
      expect(find.text('Table of constants'), findsOneWidget);
    });

    testWidgets('a document with no questions says so and lists what it did read', (tester) async {
      await openImport(tester);
      await choose(tester, 'notes.docx', buildDocx(paragraphs: ['Just some notes.']));
      expect(find.textContaining('No questions were found in this document'), findsOneWidget);
      expect(summary(tester), '0 found · 0 ready · 0 need attention · 0 not imported');
      expect(find.text('1: Just some notes.'), findsOneWidget);
    });

    testWidgets('split runs and tracked deletions in a real document come through as the person sees them', (
      tester,
    ) async {
      await openImport(tester);
      await choose(
        tester,
        'exam.docx',
        buildDocx(
          bodyXml: [
            splitPara(['Ques', 'tion 1 [MC', 'Q]']),
            para('Which is right?'),
            para('A. wrong'),
            para('B. right'),
            trackedPara(kept: 'Correct Answer: ', inserted: 'B', deleted: 'A'),
            para('Marks: 1'),
          ].join(),
        ),
      );
      expect(summary(tester), '1 found · 1 ready · 0 need attention · 0 not imported');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add to the exam (1)'));
      final question = (await storedQuestions(tester)).single;
      expect(question.correctOptionIds, {question.options[1].id}, reason: 'the deleted "A" must not count');
    });

    testWidgets('the shipped template imports as three ready questions', (tester) async {
      await openImport(tester);
      await choose(
        tester,
        'examora_question_template.docx',
        File('assets/templates/examora_question_template.docx').readAsBytesSync(),
      );
      expect(summary(tester), '3 found · 3 ready · 0 need attention · 0 not imported');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add to the exam (3)'));
      final stored = await storedQuestions(tester);
      expect(stored.map((q) => q.type), [
        QuestionType.singleChoice,
        QuestionType.multipleChoice,
        QuestionType.shortText,
      ]);
      expect(stored.map((q) => q.marks), [1, 2, 5]);
      expect(stored.first.topic, 'Networking');
      expect(stored.first.difficulty, 'Easy');
    });
  });

  group('from the wizard', () {
    testWidgets('"Import from Word" asks for the details FIRST, then opens the importer for the saved exam', (
      tester,
    ) async {
      await pumpExamora(
        tester,
        env,
        initialLocation: RoutePaths.instructorNewExam(RoutePaths.methodWord),
        extra: [wordFileSourceProvider.overrideWithValue(files)],
      );
      expect(find.text('Step 1 of 5 · Details'), findsOneWidget);
      await enterField(tester, 'Exam title', 'Imported exam');
      await enterField(tester, 'Course name', 'CS101');
      await enterField(tester, 'Duration (minutes)', '45');
      await enterField(tester, 'Pass mark (% of the total marks)', '60');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save and continue'));

      final created = (await containerOf(
        tester,
      ).read(localExamStoreProvider).all()).firstWhere((e) => e.title == 'Imported exam');
      expect(routerOf(tester).location, RoutePaths.instructorExamImport(created.id));
      expect(find.text('Import from Word'), findsWidgets);

      await choose(tester, 'exam.docx', buildDocx(paragraphs: goodQuestion(1)));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Add to the exam (1)'));

      // Back in the wizard, on the questions step, with the imported question showing as WORD.
      expect(find.text('Step 2 of 5 · Questions'), findsOneWidget);
      expect(find.text('Text of question 1?'), findsOneWidget);
      expect(find.text('WORD'), findsOneWidget);
    });
  });

  group('Arabic', () {
    testWidgets('the importer and its messages are Arabic', (tester) async {
      env = TestEnvironment(language: 'ar', now: DateTime.utc(2026, 10, 27, 9));
      await startSignedIn(env, 'instructor@examora.app');
      examId = ok(await examRepositoryFor(env).createExam(details())).id;
      await openImport(tester);
      expect(find.text('استيراد من Word'), findsOneWidget);
      files.offer('old.doc', Uint8List.fromList([1]));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'اختر ملف docx'));
      expect(find.textContaining('ملف Word قديم'), findsOneWidget);
      await choose2(tester, files);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> choose2(WidgetTester tester, FakeWordFileSource files) async {
  files.offer('ok.docx', buildDocx(paragraphs: goodQuestion(1)));
  await tapVisible(tester, find.widgetWithText(FilledButton, 'اختر ملف docx'));
  expect(find.textContaining('جاهز'), findsWidgets);
}
