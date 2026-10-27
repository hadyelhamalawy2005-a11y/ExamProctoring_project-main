import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';

ChoiceAnswer choice(Question question, Iterable<int> indexes) =>
    ChoiceAnswer({for (final index in indexes) question.options[index].id});

QuestionResult only(AttemptResult result) => result.questions.single;

void main() {
  group('single choice', () {
    final question = singleChoice(marks: 2, correct: 1);

    test('the correct option earns full marks', () {
      final result = only(
        Grader.grade(
          questions: [question],
          answers: {
            'q1': choice(question, [1]),
          },
        ),
      );
      expect(result.outcome, QuestionOutcome.correct);
      expect(result.marksAwarded, 2);
    });

    test('a wrong option earns nothing', () {
      final result = only(
        Grader.grade(
          questions: [question],
          answers: {
            'q1': choice(question, [0]),
          },
        ),
      );
      expect(result.outcome, QuestionOutcome.incorrect);
      expect(result.marksAwarded, 0);
    });

    test('choosing the right option AND another is wrong', () {
      final result = only(
        Grader.grade(
          questions: [question],
          answers: {
            'q1': choice(question, [1, 2]),
          },
        ),
      );
      expect(result.outcome, QuestionOutcome.incorrect);
      expect(result.marksAwarded, 0);
    });

    test('an answer naming an option that does not exist earns nothing', () {
      final result = only(
        Grader.grade(
          questions: [question],
          answers: {
            'q1': const ChoiceAnswer({'ghost'}),
          },
        ),
      );
      expect(result.outcome, QuestionOutcome.incorrect);
    });

    test('no answer, or an empty one, is "unanswered" with no marks', () {
      for (final answers in [
        <String, AnswerValue>{},
        {'q1': const ChoiceAnswer({})},
      ]) {
        final result = only(Grader.grade(questions: [question], answers: answers));
        expect(result.outcome, QuestionOutcome.unanswered);
        expect(result.marksAwarded, 0);
      }
    });

    test('a text answer to a choice question earns nothing', () {
      final result = only(Grader.grade(questions: [question], answers: {'q1': const TextAnswer('B')}));
      expect(result.outcome, QuestionOutcome.unanswered);
    });
  });

  group('multiple choice is ALL OR NOTHING', () {
    final question = multipleChoice(marks: 3, correct: {0, 2});

    test('exactly the correct options earn full marks, in any order', () {
      expect(
        only(
          Grader.grade(
            questions: [question],
            answers: {
              'm1': choice(question, [0, 2]),
            },
          ),
        ).marksAwarded,
        3,
      );
      expect(
        only(
          Grader.grade(
            questions: [question],
            answers: {
              'm1': choice(question, [2, 0]),
            },
          ),
        ).marksAwarded,
        3,
      );
    });

    test('one correct option missing earns NOTHING (no partial credit)', () {
      final result = only(
        Grader.grade(
          questions: [question],
          answers: {
            'm1': choice(question, [0]),
          },
        ),
      );
      expect(result.outcome, QuestionOutcome.incorrect);
      expect(result.marksAwarded, 0);
    });

    test('one extra option earns NOTHING', () {
      final result = only(
        Grader.grade(
          questions: [question],
          answers: {
            'm1': choice(question, [0, 2, 3]),
          },
        ),
      );
      expect(result.outcome, QuestionOutcome.incorrect);
      expect(result.marksAwarded, 0);
    });

    test('only wrong options earn nothing', () {
      expect(
        only(
          Grader.grade(
            questions: [question],
            answers: {
              'm1': choice(question, [1, 3]),
            },
          ),
        ).marksAwarded,
        0,
      );
    });

    test('when every option is correct, choosing all of them is the only way to score', () {
      final all = multipleChoice(correct: {0, 1, 2, 3});
      expect(
        only(
          Grader.grade(
            questions: [all],
            answers: {
              'm1': choice(all, [0, 1, 2, 3]),
            },
          ),
        ).marksAwarded,
        2,
      );
      expect(
        only(
          Grader.grade(
            questions: [all],
            answers: {
              'm1': choice(all, [0, 1, 2]),
            },
          ),
        ).marksAwarded,
        0,
      );
    });
  });

  group('short text is never marked by the app', () {
    final question = shortText(marks: 5);

    test('a typed answer waits for the instructor and has NO marks yet (not zero, not a guess)', () {
      final result = only(
        Grader.grade(questions: [question], answers: {'s1': const TextAnswer('A function calling itself.')}),
      );
      expect(result.outcome, QuestionOutcome.pendingManual);
      expect(result.marksAwarded, isNull);
    });

    test('an answer identical to the model answer is STILL not marked automatically', () {
      final result = only(Grader.grade(questions: [question], answers: {'s1': TextAnswer(question.modelAnswer!)}));
      expect(result.outcome, QuestionOutcome.pendingManual);
      expect(result.marksAwarded, isNull);
    });

    test('a blank answer is unanswered and worth nothing', () {
      for (final text in ['', '   ', '\n']) {
        final result = only(Grader.grade(questions: [question], answers: {'s1': TextAnswer(text)}));
        expect(result.outcome, QuestionOutcome.unanswered);
        expect(result.marksAwarded, 0);
      }
    });

    test('marks given by the instructor are used', () {
      final result = only(
        Grader.grade(questions: [question], answers: {'s1': const TextAnswer('x')}, manualMarks: {'s1': 3.5}),
      );
      expect(result.outcome, QuestionOutcome.markedManually);
      expect(result.marksAwarded, 3.5);
    });

    test('marks are CLAMPED to what the question offers: never more, never below zero', () {
      expect(only(Grader.grade(questions: [question], answers: {}, manualMarks: {'s1': 9})).marksAwarded, 5);
      expect(only(Grader.grade(questions: [question], answers: {}, manualMarks: {'s1': -2})).marksAwarded, 0);
      expect(only(Grader.grade(questions: [question], answers: {}, manualMarks: {'s1': double.nan})).marksAwarded, 0);
      expect(
        only(Grader.grade(questions: [question], answers: {}, manualMarks: {'s1': double.infinity})).marksAwarded,
        0,
      );
      expect(Grader.clamp(5, 5), 5);
      expect(Grader.clamp(0, 5), 0);
    });

    test('manual marks for a CHOICE question are ignored: the app marks those itself', () {
      final single = singleChoice();
      final result = only(
        Grader.grade(
          questions: [single],
          answers: {
            'q1': choice(single, [0]),
          },
          manualMarks: {'q1': 99},
        ),
      );
      expect(result.marksAwarded, 0);
    });
  });

  group('the whole attempt', () {
    final single = singleChoice(id: 'a', marks: 1, correct: 0);
    final multiple = multipleChoice(id: 'b', marks: 2, correct: {0, 1});
    final text = shortText(id: 'c', marks: 5);
    final questions = [single, multiple, text];

    AttemptResult grade(
      Map<String, AnswerValue> answers, {
      Map<String, double> manual = const {},
      double? passMark = 50,
    }) => Grader.grade(questions: questions, answers: answers, manualMarks: manual, passMarkPercent: passMark);

    test('totals, pending questions and percentage', () {
      final result = grade({
        'a': choice(single, [0]),
        'b': choice(multiple, [0, 1]),
        'c': const TextAnswer('essay'),
      });
      expect(result.totalMarks, 8);
      expect(result.awardedMarks, 3, reason: 'the typed answer counts for nothing until it is marked');
      expect(result.pendingManualCount, 1);
      expect(result.isFinal, isFalse);
      expect(result.percentage, closeTo(37.5, 1e-9));
    });

    test('while a typed answer is pending, the app does NOT say passed or failed', () {
      final result = grade({
        'a': choice(single, [0]),
        'b': choice(multiple, [0, 1]),
        'c': const TextAnswer('essay'),
      });
      expect(result.passed, isNull);
    });

    test('once everything is marked: passed at or above the pass mark, failed below', () {
      final answers = {
        'a': choice(single, [0]),
        'b': choice(multiple, [0, 1]),
        'c': const TextAnswer('essay'),
      };
      expect(grade(answers, manual: {'c': 1}).passed, isTrue, reason: '4 of 8 is exactly 50%');
      expect(grade(answers, manual: {'c': 0.5}).passed, isFalse, reason: '3.5 of 8 is below 50%');
      expect(grade(answers, manual: {'c': 5}).passed, isTrue);
    });

    test('an exam with no pass mark never says passed or failed', () {
      final result = grade({}, passMark: null);
      expect(result.isFinal, isTrue);
      expect(result.passed, isNull);
    });

    test('an attempt with no answers scores zero and is final when there are no typed answers to mark', () {
      final result = Grader.grade(questions: [single, multiple], answers: const {}, passMarkPercent: 50);
      expect(result.awardedMarks, 0);
      expect(result.isFinal, isTrue);
      expect(result.passed, isFalse);
    });

    test('an exam worth nothing does not divide by zero', () {
      const empty = AttemptResult(questions: [], totalMarks: 0, passMarkPercent: 50);
      expect(empty.percentage, 0);
    });

    test('round-trips through JSON', () {
      final result = grade(
        {
          'a': choice(single, [0]),
        },
        manual: {'c': 2},
      );
      final back = AttemptResult.fromJson(JsonReader.of(result.toJson()));
      expect(back.toJson(), result.toJson());
    });
  });

  group('PROCTORING NEVER CHANGES A MARK', () {
    test('the grader has no way to be told about an incident: the same inputs always give the same marks', () {
      final single = singleChoice(marks: 4, correct: 0);
      final answers = {
        'q1': choice(single, [0]),
      };
      final calm = Grader.grade(questions: [single], answers: answers, passMarkPercent: 50);
      // A student with twenty warnings and a flagged attempt answers the same way:
      final flagged = Grader.grade(questions: [single], answers: answers, passMarkPercent: 50);
      expect(flagged.toJson(), calm.toJson());
      expect(flagged.awardedMarks, 4);
    });
  });

  group('answers refer to option IDS, never positions', () {
    test('a shuffled option order grades exactly like the original order', () {
      final question = singleChoice(correct: 2, options: const ['a', 'b', 'c', 'd']);
      final correctId = question.options[2].id;
      // The student is shown c, a, d, b. They tick the first thing on screen, which is "c".
      final shown = [question.options[2], question.options[0], question.options[3], question.options[1]];
      final answer = ChoiceAnswer({shown.first.id});
      expect(answer.optionIds, {correctId});
      final shuffled = Grader.grade(questions: [question], answers: {'q1': answer});
      final ordered = Grader.grade(
        questions: [question],
        answers: {
          'q1': ChoiceAnswer({question.options[2].id}),
        },
      );
      expect(shuffled.toJson(), ordered.toJson());
      expect(only(shuffled).marksAwarded, 1);
    });
  });

  group('answers', () {
    test('JSON round-trips, and an unknown kind is a parse error', () {
      const choiceAnswer = ChoiceAnswer({'b', 'a'});
      expect(AnswerValue.fromJson(JsonReader.of(choiceAnswer.toJson())), choiceAnswer);
      expect(choiceAnswer.toJson()['optionIds'], ['a', 'b'], reason: 'sorted, so the stored form is stable');
      const textAnswer = TextAnswer('hello');
      expect(AnswerValue.fromJson(JsonReader.of(textAnswer.toJson())), textAnswer);
      expect(() => AnswerValue.fromJson(JsonReader.of({'kind': 'voice'})), throwsA(isA<Exception>()));
    });
  });

  group('AttemptTimer: the clock is recomputed from the deadline, never counted down', () {
    final deadline = DateTime.utc(2026, 10, 27, 10);

    test('what is left is the deadline minus now, whenever it is asked', () {
      final timer = AttemptTimer(deadline: deadline, seenUpTo: DateTime.utc(2026, 10, 27, 9));
      expect(timer.remaining(DateTime.utc(2026, 10, 27, 9, 30)), const Duration(minutes: 30));
      expect(timer.remaining(DateTime.utc(2026, 10, 27, 9, 59, 59)), const Duration(seconds: 1));
      expect(timer.remaining(DateTime.utc(2026, 10, 27, 10)), Duration.zero);
      expect(timer.isOver(DateTime.utc(2026, 10, 27, 10)), isTrue);
      // A fresh timer: this one has already seen 10:00 and never goes back (see the rewound-clock test below).
      final fresh = AttemptTimer(deadline: deadline, seenUpTo: DateTime.utc(2026, 10, 27, 9));
      expect(fresh.isOver(DateTime.utc(2026, 10, 27, 9, 59, 59)), isFalse);
    });

    test('BACKGROUNDING gains nothing: an hour away is an hour gone, however few times it was asked meanwhile', () {
      final timer = AttemptTimer(deadline: deadline, seenUpTo: DateTime.utc(2026, 10, 27, 9));
      timer.remaining(DateTime.utc(2026, 10, 27, 9, 5)); // last look before leaving
      // ... the app is suspended; no ticks run ... it comes back 50 minutes later
      expect(timer.remaining(DateTime.utc(2026, 10, 27, 9, 55)), const Duration(minutes: 5));
    });

    test('turning the device clock BACK gains nothing: the latest moment ever seen is the floor', () {
      final timer = AttemptTimer(deadline: deadline, seenUpTo: DateTime.utc(2026, 10, 27, 9));
      expect(timer.remaining(DateTime.utc(2026, 10, 27, 9, 40)), const Duration(minutes: 20));
      // The student sets the clock back to 09:00:
      expect(
        timer.remaining(DateTime.utc(2026, 10, 27, 9)),
        const Duration(minutes: 20),
        reason: 'still 20 minutes, not 60',
      );
      expect(timer.seenUpTo, DateTime.utc(2026, 10, 27, 9, 40));
      // Time then moves on normally from the rewound clock; it only counts once it passes what was already seen.
      expect(timer.remaining(DateTime.utc(2026, 10, 27, 9, 50)), const Duration(minutes: 10));
    });

    test('KILLING the app gains nothing: the floor is stored with the attempt and a new timer starts from it', () {
      final first = AttemptTimer(deadline: deadline, seenUpTo: DateTime.utc(2026, 10, 27, 9));
      first.observe(DateTime.utc(2026, 10, 27, 9, 45));
      final afterRestart = AttemptTimer(deadline: deadline, seenUpTo: first.seenUpTo);
      expect(afterRestart.remaining(DateTime.utc(2026, 10, 27, 9, 10)), const Duration(minutes: 15));
    });

    test('the deadline is absolute: a clock reading in another time zone changes nothing', () {
      final timer = AttemptTimer(deadline: deadline, seenUpTo: DateTime.utc(2026, 10, 27, 9));
      final local = DateTime.utc(2026, 10, 27, 9, 30).toLocal();
      expect(timer.remaining(local), const Duration(minutes: 30));
    });

    test('once over it stays over', () {
      final timer = AttemptTimer(deadline: deadline, seenUpTo: DateTime.utc(2026, 10, 27, 9));
      expect(timer.isOver(DateTime.utc(2026, 10, 27, 10, 5)), isTrue);
      expect(
        timer.isOver(DateTime.utc(2026, 10, 27, 8)),
        isTrue,
        reason: 'rewinding the clock does not reopen the exam',
      );
    });
  });
}
