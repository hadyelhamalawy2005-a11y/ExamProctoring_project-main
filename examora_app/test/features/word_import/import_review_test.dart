import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/word_import/data/question_document_parser.dart';
import 'package:examora_app/features/word_import/domain/import_models.dart';
import 'package:examora_app/features/word_import/domain/import_review.dart';
import 'package:flutter_test/flutter_test.dart';

List<ImportDraft> draftsFrom(List<String> lines) {
  var counter = 0;
  final preview = QuestionDocumentParser.parse(
    ExtractedDocument(lines: [for (var i = 0; i < lines.length; i++) SourceLine(i + 1, lines[i])], skipped: const []),
  );
  return [for (final q in preview.questions) ImportDraft.fromParsed(q, newId: () => 'id${counter++}')];
}

const readyLines = ['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Correct Answer: A', 'Marks: 1'];

void main() {
  group('status is always one of three words', () {
    test('a complete question is ready', () {
      expect(ImportReview.statusOf(draftsFrom(readyLines).single), ImportStatus.ready);
    });

    test('a question with no Marks: line needs attention, and stays that way until marks are entered', () {
      var draft = draftsFrom(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Correct Answer: A']).single;
      expect(ImportReview.statusOf(draft), ImportStatus.needsAttention);
      expect(ImportReview.standingIssues(draft).single.code, ImportIssueCode.missingMarks);
      // "No Marks: line" says it better than "marks must be above 0", so only one of them is shown.
      expect(ImportReview.problems(draft), isEmpty);

      draft = draft.copyWith(marks: (value: 0));
      expect(ImportReview.statusOf(draft), ImportStatus.needsAttention, reason: 'zero marks is not valid');
      draft = draft.copyWith(marks: (value: 2));
      expect(ImportReview.statusOf(draft), ImportStatus.ready);
      expect(ImportReview.standingIssues(draft), isEmpty, reason: 'entering the marks settles the issue');
    });

    test('a question with no answer line needs attention and shows the validation problem', () {
      final draft = draftsFrom(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Marks: 1']).single;
      expect(ImportReview.statusOf(draft), ImportStatus.needsAttention);
      expect(ImportReview.problems(draft), [QuestionProblem.noCorrectAnswer]);
      expect(draft.options.any((o) => o.isCorrect), isFalse);
    });

    test('a guess about the type stays until the instructor confirms they checked the question', () {
      var draft = draftsFrom(['Q1: x?', 'A) a', 'B) b', 'Answer: A', 'Marks: 1']).single;
      expect(ImportReview.statusOf(draft), ImportStatus.needsAttention);
      draft = draft.copyWith(acknowledged: true);
      expect(ImportReview.statusOf(draft), ImportStatus.ready);
    });

    test('leaving a question out makes it "not imported", whatever else is true of it', () {
      final draft = draftsFrom(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Marks: 1']).single.copyWith(excluded: true);
      expect(ImportReview.statusOf(draft), ImportStatus.notImported);
    });

    test('editing the options and the answer in the review works like manual authoring', () {
      var draft = draftsFrom(['Question 1 [MCQ]', 'x?', 'A. a', 'B. b', 'Marks: 1']).single;
      draft = draft.copyWith(
        options: [for (var i = 0; i < draft.options.length; i++) draft.options[i].copyWith(isCorrect: i == 1)],
      );
      expect(ImportReview.statusOf(draft), ImportStatus.ready);
      draft = draft.copyWith(text: '   ');
      expect(ImportReview.problems(draft), [QuestionProblem.noText]);
    });
  });

  group('the summary and the gate', () {
    final lines = [
      ...readyLines,
      'Question 2 [MCQ]', 'y?', 'A. a', 'B. b', 'Correct Answer: B', // no marks
      'Question 3 [MCQ]', 'z?', 'A. a', 'B. b', 'Correct Answer: A', 'Marks: 1',
    ];

    test('counts found, ready, needing attention and not imported', () {
      final drafts = draftsFrom(lines);
      expect(ImportReview.summarize(drafts), (found: 3, ready: 2, attention: 1, notImported: 0));
      final left = [drafts[0], drafts[1], drafts[2].copyWith(excluded: true)];
      expect(ImportReview.summarize(left), (found: 3, ready: 1, attention: 1, notImported: 1));
    });

    test('continuing is blocked while a kept question is not valid, and when nothing is kept', () {
      final drafts = draftsFrom(lines);
      expect(ImportReview.blockOf(drafts), ImportBlock.invalidQuestions);
      expect(ImportReview.blockOf([drafts[0], drafts[1].copyWith(excluded: true), drafts[2]]), isNull);
      expect(ImportReview.blockOf([for (final d in drafts) d.copyWith(excluded: true)]), ImportBlock.nothingKept);
      expect(ImportReview.blockOf(const []), ImportBlock.nothingKept);
      expect(ImportReview.blockOf([drafts[0], drafts[1].copyWith(marks: (value: 1)), drafts[2]]), isNull);
    });

    test(
      'a retained question with an unconfirmed doubt is added flagged for review, so it cannot be published unseen',
      () {
        final drafts = draftsFrom(['Q1: x?', 'A) a', 'B) b', 'Answer: A', 'Marks: 1']);
        final questions = ImportReview.build(drafts);
        expect(questions.single.needsReview, isTrue);
        expect(questions.single.source, QuestionSource.wordImport);
        final confirmed = ImportReview.build([drafts.single.copyWith(acknowledged: true)]);
        expect(confirmed.single.needsReview, isFalse);
      },
    );

    test('only kept, valid questions are built, with the option ids and marks that were reviewed', () {
      final drafts = draftsFrom(lines);
      final built = ImportReview.build([drafts[0], drafts[1].copyWith(excluded: true), drafts[2]]);
      expect(built.map((q) => q.text), ['x?', 'z?']);
      expect(built.first.marks, 1);
      expect(built.first.options.map((o) => o.id).toSet().length, 2);
      expect(built.first.correctOptionIds, {built.first.options.first.id});
      expect(ImportReview.build([drafts[1]]), isEmpty, reason: 'a question without marks is never built');
    });

    test('topic and difficulty travel with the question as labels', () {
      final drafts = draftsFrom([...readyLines, 'Topic: Logic', 'Difficulty: Easy']);
      final question = ImportReview.build(drafts).single;
      expect(question.topic, 'Logic');
      expect(question.difficulty, 'Easy');
    });
  });
}
