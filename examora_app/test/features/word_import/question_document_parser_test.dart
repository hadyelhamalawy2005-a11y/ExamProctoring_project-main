import 'dart:io';

import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/word_import/data/docx_reader.dart';
import 'package:examora_app/features/word_import/data/question_document_parser.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/docx_builder.dart';
import '../../support/exam_fixtures.dart';

ImportPreview parseLines(List<String> lines) => QuestionDocumentParser.parse(
  ExtractedDocument(lines: [for (var i = 0; i < lines.length; i++) SourceLine(i + 1, lines[i])], skipped: const []),
);

Set<ImportIssueCode> codes(ParsedQuestion question) => {for (final issue in question.issues) issue.code};

void main() {
  group('the documented template', () {
    final template = [
      'Question 1 [MCQ]',
      'Which layer of the OSI model routes packets between networks?',
      'A. Physical',
      'B. Network',
      'C. Transport',
      'D. Session',
      'Correct Answer: B',
      'Marks: 1',
      'Difficulty: Easy',
      'Topic: Networking',
      'Question 2 [Multiple]',
      'Which of the following are prime numbers?',
      'A. 2',
      'B. 4',
      'C. 5',
      'D. 9',
      'Correct Answer: A, C',
      'Marks: 2',
      'Question 3 [Short]',
      'Explain recursion.',
      'Model Answer: A function that calls itself.',
      'Marks: 5',
    ];

    test('is read into three questions with nothing left to chance', () {
      final preview = parseLines(template);
      expect(preview.questions.length, 3);
      expect(preview.unattached, isEmpty);

      final mcq = preview.questions[0];
      expect(mcq.number, 1);
      expect(mcq.type, QuestionType.singleChoice);
      expect(mcq.text, 'Which layer of the OSI model routes packets between networks?');
      expect(mcq.options.map((o) => '${o.label}:${o.text}'), ['A:Physical', 'B:Network', 'C:Transport', 'D:Session']);
      expect(mcq.correctLabels, {'B'});
      expect(mcq.marks, 1);
      expect(mcq.difficulty, 'Easy');
      expect(mcq.topic, 'Networking');
      expect(mcq.issues, isEmpty);

      final multiple = preview.questions[1];
      expect(multiple.type, QuestionType.multipleChoice);
      expect(multiple.correctLabels, {'A', 'C'});
      expect(multiple.marks, 2);
      expect(multiple.issues, isEmpty);

      final shortText = preview.questions[2];
      expect(shortText.type, QuestionType.shortText);
      expect(shortText.options, isEmpty);
      expect(shortText.modelAnswer, 'A function that calls itself.');
      expect(shortText.marks, 5);
      expect(shortText.issues, isEmpty);
    });

    test('the question text may sit on the same line as the number and tag', () {
      final preview = parseLines(['Question 1 [MCQ]: What is 2 + 2?', 'A. 3', 'B. 4', 'Correct Answer: B', 'Marks: 1']);
      expect(preview.questions.single.text, 'What is 2 + 2?');
      expect(preview.questions.single.issues, isEmpty);
    });

    test('a question text may run over several lines before the options', () {
      final preview = parseLines([
        'Question 1 [MCQ]',
        'First line.',
        'Second line.',
        'A. x',
        'B. y',
        'Correct Answer: A',
        'Marks: 1',
      ]);
      expect(preview.questions.single.text, 'First line.\nSecond line.');
    });

    test('the SHIPPED template asset reads into three questions that are all ready', () {
      final bytes = File('assets/templates/examora_question_template.docx').readAsBytesSync();
      final document = ok(DocxReader.read(fileName: 'examora_question_template.docx', bytes: bytes));
      final preview = QuestionDocumentParser.parse(document);
      expect(preview.questions.length, 3);
      expect(preview.questions.expand((q) => q.issues), isEmpty);
      expect(preview.documentTitle, startsWith('Replace this'));
      expect(preview.unattached, isEmpty);
      expect(preview.questions.map((q) => q.type), [
        QuestionType.singleChoice,
        QuestionType.multipleChoice,
        QuestionType.shortText,
      ]);
    });
  });

  group('ordinary writing styles', () {
    test('the sample file style: Q1:, section headings, Points:, Arabic questions and letters', () {
      final preview = parseLines([
        'Examora – Word Import Test Questions',
        'Instructions: Upload this file using the Instructor account.',
        'Section 1: Multiple Choice Questions',
        'Q1: What does CPU stand for?',
        'A) Central Processing Unit',
        'B) Computer Personal Unit',
        'Correct Answer: A',
        'Points: 1',
        'Section 2: Essay Question',
        'Q11: Explain the difference between a stack and a queue.',
        'Type: Essay',
        'Model Answer: A stack is LIFO; a queue is FIFO.',
        'Points: 5',
        'Section 3: Arabic Multiple Choice Questions',
        'س12: ما الوظيفة الأساسية لنظام إدارة قواعد البيانات؟',
        'أ) تخزين البيانات وتنظيمها',
        'ب) تصميم الصور فقط',
        'Correct Answer: أ',
        'Points: 1',
      ]);
      expect(preview.questions.map((q) => q.number), [1, 11, 12]);
      expect(preview.questions.map((q) => q.type), [
        QuestionType.singleChoice,
        QuestionType.shortText,
        QuestionType.singleChoice,
      ]);
      expect(
        preview.questions.expand((q) => q.issues),
        isEmpty,
        reason: 'every kind came from a heading or a Type line',
      );
      expect(preview.questions[2].options.map((o) => o.label), ['A', 'B']);
      expect(preview.questions[2].correctLabels, {'A'});
      expect(preview.questions[2].text, 'ما الوظيفة الأساسية لنظام إدارة قواعد البيانات؟');
      // The title line and the instructions are reported; nothing disappears.
      expect(preview.unattached.map((l) => l.text), [
        'Examora – Word Import Test Questions',
        'Instructions: Upload this file using the Instructor account.',
      ]);
      expect(preview.ignored.map((l) => l.text).first, 'Section 1: Multiple Choice Questions');
    });

    test('question numbers: Q1., Question 2 -, bare 3. and 4), and Arabic-Indic digits', () {
      final preview = parseLines([
        'Q1. First',
        'A. a',
        'B. b',
        'Answer: A',
        'Marks: 1',
        'Question 2 - Second',
        'A. a',
        'B. b',
        'Answer: B',
        'Marks: 1',
        '3. Third',
        'A. a',
        'B. b',
        'Answer: A',
        'Marks: 1',
        '4) Fourth',
        'A. a',
        'B. b',
        'Answer: B',
        'Marks: 1',
        'السؤال ٥: Fifth',
        'A. a',
        'B. b',
        'Answer: A',
        'Marks: ١',
      ]);
      expect(preview.questions.map((q) => q.number), [1, 2, 3, 4, 5]);
      expect(preview.questions.map((q) => q.text), ['First', 'Second', 'Third', 'Fourth', 'Fifth']);
      expect(preview.questions.last.marks, 1);
    });

    test(
      'a bare number only starts a question when it follows on, so numbered lines elsewhere stay where they are',
      () {
        final preview = parseLines([
          'Question 1 [Short]',
          'Describe the steps.',
          'Model Answer: First:',
          '2. Then the second thing.',
          'Marks: 3',
        ]);
        expect(preview.questions.length, 1);
        expect(preview.questions.single.modelAnswer, contains('Then the second thing.'));
      },
    );

    test('options written side by side on one line, separated by tabs or wide spaces', () {
      final preview = parseLines(['Q1: Capital of France?', 'A) Paris\tB) London   C) Rome', 'Answer: A', 'Marks: 1']);
      expect(preview.questions.single.options.map((o) => '${o.label}:${o.text}'), ['A:Paris', 'B:London', 'C:Rome']);
    });

    test('options in parentheses, with colons and in Arabic letters', () {
      final preview = parseLines(['Q1: x?', '(A) one', 'B: two', 'ج) three', 'Answer: ج', 'Marks: 1']);
      final question = preview.questions.single;
      expect(question.options.map((o) => o.label), ['A', 'B', 'C']);
      expect(question.correctLabels, {'C'});
    });

    test('a correct option marked on the option itself (leading star, trailing tick or "(correct)")', () {
      final preview = parseLines(['Q1: x?', 'A) one', '*B) two', 'C) three ✓', 'Marks: 1']);
      expect(preview.questions.single.correctLabels, {'B', 'C'});
      final single = parseLines(['Q1 [MCQ]: x?', 'A) one', 'B) two (correct)', 'Marks: 1']);
      expect(single.questions.single.correctLabels, {'B'});
      expect(single.questions.single.options[1].text, 'two');
    });

    test('marks: "Marks:", "Points:", a decimal, a comma, Arabic digits and a unit, and a "(2 points)" suffix', () {
      expect(QuestionDocumentParser.parseMarks('1'), 1);
      expect(QuestionDocumentParser.parseMarks('1.5'), 1.5);
      expect(QuestionDocumentParser.parseMarks('2,5'), 2.5);
      expect(QuestionDocumentParser.parseMarks('٣'), 3);
      expect(QuestionDocumentParser.parseMarks('٢٫٥'), 2.5);
      expect(QuestionDocumentParser.parseMarks('4 points'), 4);
      expect(QuestionDocumentParser.parseMarks('1 mark'), 1);
      expect(QuestionDocumentParser.parseMarks('3 درجات'), 3);
      for (final bad in ['', 'abc', '1e3', '-1', '1..2', 'NaN', '1 apple']) {
        expect(QuestionDocumentParser.parseMarks(bad), isNull, reason: bad);
      }
      final suffix = parseLines(['Q1: What is 2 + 2? (2 points)', 'A) 3', 'B) 4', 'Answer: B']);
      expect(suffix.questions.single.marks, 2);
      expect(suffix.questions.single.text, 'What is 2 + 2?');
    });

    test('an explanation, a topic and a difficulty are kept as labels', () {
      final preview = parseLines([
        'Question 1 [MCQ]',
        'x?',
        'A. a',
        'B. b',
        'Correct Answer: A',
        'Marks: 1',
        'Explanation: Because a.',
        'Topic: Logic',
        'Difficulty: Hard',
      ]);
      final question = preview.questions.single;
      expect(question.explanation, 'Because a.');
      expect(question.topic, 'Logic');
      expect(question.difficulty, 'Hard');
    });
  });

  group('nothing is invented: a gap is flagged, never filled', () {
    test('NO "Marks:" line leaves the marks empty and raises a visible issue', () {
      final question = parseLines(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Correct Answer: A']).questions.single;
      expect(question.marks, isNull);
      expect(codes(question), {ImportIssueCode.missingMarks});
    });

    test('marks that are not a number are kept as an issue with what was written', () {
      final question = parseLines(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Correct Answer: A', 'Marks: lots'])
          .questions
          .single;
      expect(question.marks, isNull);
      final issue = question.issues.single;
      expect(issue.code, ImportIssueCode.marksUnreadable);
      expect(issue.detail, 'lots');
    });

    test('NO answer line leaves every option unmarked: the key is never guessed', () {
      final question = parseLines(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Marks: 1']).questions.single;
      expect(question.correctLabels, isEmpty);
    });

    test('an answer letter with no such option is reported and not used', () {
      final question = parseLines(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Correct Answer: E', 'Marks: 1'])
          .questions
          .single;
      expect(question.correctLabels, isEmpty);
      expect(question.issues.single.code, ImportIssueCode.unknownAnswerLabel);
      expect(question.issues.single.detail, 'E');
    });

    test('an answer written as words is not matched to an option by guessing', () {
      final question = parseLines([
        'Question 1 [MCQ]',
        'x?',
        'A. Paris',
        'B. London',
        'Correct Answer: Paris',
        'Marks: 1',
      ]).questions.single;
      expect(question.correctLabels, isEmpty);
      expect(codes(question), contains(ImportIssueCode.unknownAnswerLabel));
    });

    test(
      'several correct answers on a single-choice question are all kept, flagged, and the type stays as declared',
      () {
        final question = parseLines([
          'Question 1 [MCQ]',
          'x?',
          'A. a',
          'B. b',
          'C. c',
          'Correct Answer: A, C',
          'Marks: 1',
        ]).questions.single;
        expect(question.type, QuestionType.singleChoice);
        expect(question.correctLabels, {'A', 'C'});
        expect(codes(question), contains(ImportIssueCode.severalAnswersForSingle));
      },
    );

    test('two answer lines that disagree are flagged', () {
      final question = parseLines([
        'Question 1 [MCQ]',
        'x?',
        'A. a',
        'B. b',
        'Correct Answer: A',
        'Answer: B',
        'Marks: 1',
      ]).questions.single;
      expect(codes(question), contains(ImportIssueCode.conflictingAnswerLines));
    });

    test('an option marked in place that disagrees with the answer line is flagged', () {
      final question = parseLines(['Q1 [MCQ]: x?', 'A) a', '*B) b', 'Correct Answer: A', 'Marks: 1']).questions.single;
      expect(codes(question), contains(ImportIssueCode.conflictingAnswerLines));
    });

    test('a question with no type is read by its shape, and flagged because that is a guess', () {
      final choice = parseLines(['Q1: x?', 'A) a', 'B) b', 'Answer: A', 'Marks: 1']).questions.single;
      expect(choice.type, QuestionType.singleChoice);
      expect(codes(choice), {ImportIssueCode.typeInferred});

      final several = parseLines(['Q1: x?', 'A) a', 'B) b', 'C) c', 'Answer: A, C', 'Marks: 1']).questions.single;
      expect(several.type, QuestionType.multipleChoice);
      expect(codes(several), {ImportIssueCode.typeInferred});

      final typed = parseLines(['Q1: Explain x.', 'Marks: 3']).questions.single;
      expect(typed.type, QuestionType.shortText);
      expect(codes(typed), {ImportIssueCode.typeInferred});
    });

    test('an unknown [tag] is reported, and the kind is then guessed and flagged too', () {
      final question = parseLines(['Question 1 [Quiz]', 'x?', 'A. a', 'B. b', 'Answer: A', 'Marks: 1'])
          .questions
          .single;
      expect(codes(question), containsAll([ImportIssueCode.unknownTypeTag, ImportIssueCode.typeInferred]));
      expect(question.issues.firstWhere((i) => i.code == ImportIssueCode.unknownTypeTag).detail, 'Quiz');
    });

    test('True/False is not a supported tag, so it is flagged instead of getting invented options', () {
      final question = parseLines(['Question 1 [TF]', 'The sky is blue.', 'Marks: 1']).questions.single;
      expect(question.options, isEmpty);
      expect(codes(question), contains(ImportIssueCode.unknownTypeTag));
    });

    test('"Correct Answer" on a question without options is kept as the model answer, and flagged', () {
      final question = parseLines(['Question 1 [Short]', 'Name a prime.', 'Correct Answer: 7', 'Marks: 1'])
          .questions
          .single;
      expect(question.modelAnswer, '7');
      expect(codes(question), {ImportIssueCode.answerTreatedAsModel});
    });

    test('a question number used twice, and an option letter used twice, are flagged', () {
      final preview = parseLines([
        'Question 1 [MCQ]',
        'one',
        'A. a',
        'A. again',
        'Correct Answer: A',
        'Marks: 1',
        'Question 1 [MCQ]',
        'two',
        'A. a',
        'B. b',
        'Correct Answer: A',
        'Marks: 1',
      ]);
      expect(codes(preview.questions[0]), contains(ImportIssueCode.duplicateOptionLabel));
      expect(codes(preview.questions[1]), contains(ImportIssueCode.duplicateQuestionNumber));
    });
  });

  group('text that belongs to no question is listed', () {
    test('lines before the first question and after the last are reported with their numbers, and flag nothing', () {
      final preview = parseLines([
        'Course: CS201',
        'Read each question carefully.',
        'Question 1 [MCQ]',
        'x?',
        'A. a',
        'B. b',
        'Correct Answer: A',
        'Marks: 1',
        'Good luck!',
      ]);
      expect(preview.unattached.map((l) => (l.number, l.text)), [
        (1, 'Course: CS201'),
        (2, 'Read each question carefully.'),
        (9, 'Good luck!'),
      ]);
      expect(preview.questions.single.issues, isEmpty, reason: 'a closing remark is not a defect of the last question');
    });

    test('a stray line in the middle of the document is listed AND flags the question it interrupted', () {
      final preview = parseLines([
        'Question 1 [MCQ]',
        'x?',
        'A. a',
        'B. b',
        'Correct Answer: A',
        'Marks: 1',
        'Please turn the page.',
        'Question 2 [MCQ]',
        'y?',
        'A. a',
        'B. b',
        'Correct Answer: B',
        'Marks: 1',
      ]);
      expect(preview.unattached.single.text, 'Please turn the page.');
      final issue = preview.questions[0].issues.single;
      expect(issue.code, ImportIssueCode.strayText);
      expect(issue.detail, 'Please turn the page.');
      expect(preview.questions[1].issues, isEmpty);
    });

    test('a document with no questions at all lists everything it read', () {
      final preview = parseLines(['Just some notes.', 'Nothing here is a question.']);
      expect(preview.questions, isEmpty);
      expect(preview.unattached.length, 2);
    });

    test('titles and headings are read but unused, and reported as such', () {
      final preview = parseLines([
        'Exam Title: Midterm',
        'Section 1: Easy',
        'Part B',
        'Question 1 [Short]',
        'x?',
        'Marks: 1',
      ]);
      expect(preview.documentTitle, 'Midterm');
      expect(preview.ignored.map((l) => l.text), ['Exam Title: Midterm', 'Section 1: Easy', 'Part B']);
      expect(preview.unattached, isEmpty);
    });

    test('each question keeps its source lines exactly as written, with their document line numbers', () {
      final preview = parseLines(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Correct Answer: A', 'Marks: 1']);
      expect(preview.questions.single.sourceLines.map((l) => (l.number, l.text)), [
        (1, 'Question 1 [MCQ]'),
        (2, 'x?'),
        (3, 'A. a'),
        (4, 'B. b'),
        (5, 'Correct Answer: A'),
        (6, 'Marks: 1'),
      ]);
      expect(preview.questions.single.startLine, 1);
    });
  });

  group('end to end through a real .docx', () {
    test('split runs, a tracked deletion and a table are all handled in one document', () {
      final bytes = buildDocx(
        bodyXml: [
          splitPara(['Ques', 'tion 1 [M', 'CQ]']),
          para('Which is right?'),
          para('A. wrong'),
          para('B. right'),
          trackedPara(kept: 'Correct Answer: ', inserted: 'B', deleted: 'A'),
          para('Marks: 1'),
          tablePart('A table of values'),
        ].join(),
      );
      final document = ok(DocxReader.read(fileName: 'x.docx', bytes: bytes));
      final preview = QuestionDocumentParser.parse(document);
      final question = preview.questions.single;
      expect(question.correctLabels, {'B'}, reason: 'the deleted "A" must not count');
      expect(question.issues, isEmpty);
      expect(preview.skipped.single.kind, SkippedKind.table);
    });
  });
}
