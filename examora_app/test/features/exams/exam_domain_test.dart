import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/exam_validation.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/exam_fixtures.dart';

Exam anExam({
  List<Question>? questions,
  DateTime? opensAt,
  DateTime? closesAt,
  ExamLifecycle lifecycle = ExamLifecycle.draft,
  double? passMark = 50,
  String title = 'Algorithms midterm',
  ExamSettings settings = const ExamSettings(),
}) => Exam(
  id: 'e1',
  ownerId: 'i1',
  title: title,
  courseName: 'CS201',
  description: '',
  instructions: '',
  durationMinutes: 60,
  passMarkPercent: passMark,
  opensAt: opensAt,
  closesAt: closesAt,
  settings: settings,
  version: 1,
  lifecycle: lifecycle,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
  questions: questions ?? [singleChoice()],
);

void main() {
  final now = DateTime.utc(2026, 10, 27, 9);

  group('status is derived from the lifecycle and the clock', () {
    final opens = DateTime.utc(2026, 11, 1, 9);
    final closes = DateTime.utc(2026, 11, 1, 12);

    test('a draft is a draft whatever the clock says', () {
      expect(anExam(opensAt: opens, closesAt: closes).statusAt(opens.add(const Duration(days: 9))), ExamStatus.draft);
    });

    test('published: scheduled before the window, ongoing inside it, completed from the closing instant', () {
      final exam = anExam(lifecycle: ExamLifecycle.published, opensAt: opens, closesAt: closes);
      expect(exam.statusAt(opens.subtract(const Duration(seconds: 1))), ExamStatus.scheduled);
      expect(exam.statusAt(opens), ExamStatus.ongoing);
      expect(exam.statusAt(closes.subtract(const Duration(seconds: 1))), ExamStatus.ongoing);
      expect(exam.statusAt(closes), ExamStatus.completed);
    });

    test('archived stays archived', () {
      expect(
        anExam(lifecycle: ExamLifecycle.archived, opensAt: opens, closesAt: closes).statusAt(now),
        ExamStatus.archived,
      );
    });
  });

  group('the deadline', () {
    test('is the duration after the start, but never later than the window closes', () {
      final exam = anExam(opensAt: DateTime.utc(2026, 11, 1, 9), closesAt: DateTime.utc(2026, 11, 1, 10, 30));
      expect(exam.deadlineFor(DateTime.utc(2026, 11, 1, 9, 5)), DateTime.utc(2026, 11, 1, 10, 5));
      expect(exam.deadlineFor(DateTime.utc(2026, 11, 1, 10)), DateTime.utc(2026, 11, 1, 10, 30));
    });
  });

  group('details validation', () {
    test('accepts valid details', () => expect(ExamValidation.details(details()), isEmpty));

    test('requires a title and a course, and limits their length', () {
      expect(ExamValidation.details(details(title: '  '))['title'], const KnownFieldProblem(FieldReason.required));
      expect(ExamValidation.details(details(course: ''))['courseName'], const KnownFieldProblem(FieldReason.required));
      expect(ExamValidation.details(details(title: 'x' * 201))['title'], const KnownFieldProblem(FieldReason.tooLong));
      expect(ExamValidation.details(details(title: 'x' * 200)), isEmpty);
    });

    test('duration is 1 to 360 minutes', () {
      expect(
        ExamValidation.details(details(minutes: 0))['durationMinutes'],
        const KnownFieldProblem(FieldReason.outOfRange),
      );
      expect(
        ExamValidation.details(details(minutes: 361))['durationMinutes'],
        const KnownFieldProblem(FieldReason.outOfRange),
      );
      expect(ExamValidation.details(details(minutes: 1)), isEmpty);
      expect(ExamValidation.details(details(minutes: 360)), isEmpty);
    });

    test('pass mark is 0 to 100 percent and never NaN', () {
      expect(ExamValidation.details(details(passMark: -1))['passMarkPercent'], isNotNull);
      expect(ExamValidation.details(details(passMark: 100.5))['passMarkPercent'], isNotNull);
      expect(ExamValidation.details(details(passMark: double.nan))['passMarkPercent'], isNotNull);
      expect(ExamValidation.details(details(passMark: 0)), isEmpty);
      expect(ExamValidation.details(details(passMark: 100)), isEmpty);
    });
  });

  group('settings validation', () {
    test('defaults are valid and as documented', () {
      const settings = ExamSettings();
      expect(ExamValidation.settings(settings), isEmpty);
      expect(settings.sustainedThresholdSeconds, 10);
      expect(settings.evidenceBufferSeconds, 3);
      expect(settings.maxWarnings, 20);
      expect(settings.randomizeQuestions, isFalse);
      expect(settings.randomizeOptions, isFalse);
      expect(settings.allowBackwardNavigation, isTrue);
    });

    test('by default only rules that can really fire are on, and the AI-only rules are off', () {
      const rules = ExamSettings.defaultRules;
      expect(rules.every((rule) => rule.hasDetector), isTrue);
      expect(rules, contains(IncidentCategory.appBackgrounded));
      expect(rules, contains(IncidentCategory.clipboardAttempt));
    });

    test('out-of-range numbers are reported by name', () {
      expect(
        ExamValidation.settings(
          const ExamSettings(sustainedThresholdSeconds: 2, evidenceBufferSeconds: 99, maxWarnings: 0),
        ).keys,
        unorderedEquals(['sustainedThresholdSeconds', 'evidenceBufferSeconds', 'maxWarnings']),
      );
    });

    test('round-trips through JSON, and an unknown rule is a parse error', () {
      const settings = ExamSettings(randomizeOptions: true, calculatorEnabled: true, sustainedThresholdSeconds: 15);
      final back = ExamSettings.fromJson(JsonReader.of(settings.toJson()));
      expect(back, settings);
      final broken = settings.toJson()..['enabledRules'] = ['telepathy'];
      expect(() => ExamSettings.fromJson(JsonReader.of(broken)), throwsA(isA<JsonParseException>()));
    });
  });

  group('schedule validation', () {
    final opens = DateTime.utc(2026, 11, 1, 9);
    test('needs both times', () {
      expect(
        ExamValidation.schedule(opensAt: null, closesAt: null, durationMinutes: 60).keys,
        unorderedEquals(['opensAt', 'closesAt']),
      );
    });
    test('the window must be at least as long as the duration', () {
      expect(
        ExamValidation.schedule(
          opensAt: opens,
          closesAt: opens.add(const Duration(minutes: 59)),
          durationMinutes: 60,
        )['closesAt'],
        const KnownFieldProblem(FieldReason.windowTooShort),
      );
      expect(
        ExamValidation.schedule(opensAt: opens, closesAt: opens.add(const Duration(minutes: 60)), durationMinutes: 60),
        isEmpty,
      );
    });
  });

  group('question validation', () {
    test('a valid question of each type has no problems', () {
      expect(ExamValidation.questionStructure(singleChoice()), isEmpty);
      expect(ExamValidation.questionStructure(multipleChoice()), isEmpty);
      expect(ExamValidation.questionStructure(shortText()), isEmpty);
    });

    test('marks: above 0, at most 9999.99, at most two decimals', () {
      for (final good in [0.01, 1, 1.5, 2.25, 9999.99]) {
        expect(ExamValidation.marksAreValid(good.toDouble()), isTrue, reason: '$good');
      }
      for (final bad in [0.0, -1.0, 9999.995, 10000.0, 1.005, double.nan, double.infinity]) {
        expect(ExamValidation.marksAreValid(bad), isFalse, reason: '$bad');
      }
    });

    test('no text and over-long text', () {
      expect(ExamValidation.questionStructure(singleChoice(text: '  ')), contains(QuestionProblem.noText));
      expect(ExamValidation.questionStructure(singleChoice(text: 'x' * 4001)), contains(QuestionProblem.textTooLong));
    });

    test('option count: at least 2 and at most 8', () {
      expect(
        ExamValidation.questionStructure(singleChoice(options: const ['only'], correct: 0)),
        contains(QuestionProblem.tooFewOptions),
      );
      expect(
        ExamValidation.questionStructure(singleChoice(options: [for (var i = 0; i < 9; i++) 'o$i'])),
        contains(QuestionProblem.tooManyOptions),
      );
      expect(ExamValidation.questionStructure(singleChoice(options: [for (var i = 0; i < 8; i++) 'o$i'])), isEmpty);
    });

    test('empty and duplicate options (ignoring case and spaces)', () {
      expect(
        ExamValidation.questionStructure(singleChoice(options: const ['a', ' ', 'c'])),
        contains(QuestionProblem.optionEmpty),
      );
      expect(
        ExamValidation.questionStructure(singleChoice(options: const ['Same', ' same ', 'c'], correct: 2)),
        contains(QuestionProblem.duplicateOptionTexts),
      );
    });

    test('single choice needs exactly one correct option; multiple choice needs at least one', () {
      final none = singleChoice().copyWith(
        options: [for (final o in singleChoice().options) o.copyWith(isCorrect: false)],
      );
      expect(ExamValidation.questionStructure(none), contains(QuestionProblem.noCorrectAnswer));
      final two = singleChoice().copyWith(
        options: [for (final o in singleChoice().options) o.copyWith(isCorrect: true)],
      );
      expect(ExamValidation.questionStructure(two), contains(QuestionProblem.severalCorrectForSingle));
      expect(
        ExamValidation.questionStructure(multipleChoice(correct: const {})),
        contains(QuestionProblem.noCorrectAnswer),
      );
      expect(ExamValidation.questionStructure(multipleChoice(correct: const {0, 1, 2, 3})), isEmpty);
    });

    test('short text may not have options', () {
      final bad = shortText().copyWith(options: singleChoice().options);
      expect(ExamValidation.questionStructure(bad), [QuestionProblem.optionsOnShortText]);
    });

    test('flagged and stale questions are only a problem for publishing', () {
      final flagged = singleChoice(needsReview: true, answerKeyStale: true);
      expect(ExamValidation.questionStructure(flagged), isEmpty);
      expect(ExamValidation.questionForPublishing(flagged), [
        QuestionProblem.flaggedForReview,
        QuestionProblem.answerKeyStale,
      ]);
      // A short-text question has no answer key to go stale.
      expect(ExamValidation.questionForPublishing(shortText().copyWith(answerKeyStale: true)), isEmpty);
    });
  });

  group('the answer key goes stale when the options change under a fixed answer', () {
    final before = singleChoice();

    test('editing an option text without re-choosing the answer makes it stale', () {
      final edited = before.copyWith(
        options: [
          before.options[0],
          before.options[1].copyWith(text: 'four'),
          ...before.options.skip(2),
        ],
      );
      expect(AnswerKey.staleAfterEdit(before, edited, confirmed: false), isTrue);
    });

    test('adding or removing an option does too', () {
      final added = before.copyWith(
        options: [
          ...before.options,
          const QuestionOption(id: 'new', text: '7', isCorrect: false),
        ],
      );
      expect(AnswerKey.staleAfterEdit(before, added, confirmed: false), isTrue);
      final removed = before.copyWith(options: before.options.take(3).toList());
      expect(AnswerKey.staleAfterEdit(before, removed, confirmed: false), isTrue);
    });

    test('confirming, or choosing a different correct option, keeps it fresh', () {
      final edited = before.copyWith(
        options: [
          before.options[0],
          before.options[1].copyWith(text: 'four'),
          ...before.options.skip(2),
        ],
      );
      expect(AnswerKey.staleAfterEdit(before, edited, confirmed: true), isFalse);
      final rechosen = edited.copyWith(
        options: [for (final o in edited.options) o.copyWith(isCorrect: o.id == edited.options[2].id)],
      );
      expect(AnswerKey.staleAfterEdit(before, rechosen, confirmed: false), isFalse);
    });

    test('an edit that leaves the options alone keeps whatever state it had', () {
      expect(AnswerKey.staleAfterEdit(before, before.copyWith(text: 'New wording'), confirmed: false), isFalse);
      final stale = before.copyWith(answerKeyStale: true);
      expect(AnswerKey.staleAfterEdit(stale, stale.copyWith(text: 'New wording'), confirmed: false), isTrue);
    });

    test('short text never has a stale key', () {
      expect(AnswerKey.staleAfterEdit(shortText(), shortText().copyWith(text: 'Other'), confirmed: false), isFalse);
    });
  });

  group('publishing rules', () {
    final opens = DateTime.utc(2026, 11, 1, 9);
    final closes = DateTime.utc(2026, 11, 1, 12);

    Exam ready() => anExam(opensAt: opens, closesAt: closes);

    test(
      'a complete exam in the future can be published',
      () => expect(ExamValidation.publishing(ready(), now), isEmpty),
    );

    test('no questions', () {
      expect(ExamValidation.publishing(ready().copyWith(questions: const []), now), [isA<NoQuestionsProblem>()]);
    });

    test('a question with no correct answer is named by its position', () {
      final bad = singleChoice(id: 'x')
          .copyWith(options: [for (final o in singleChoice().options) o.copyWith(isCorrect: false)]);
      final problems = ExamValidation.publishing(ready().copyWith(questions: [singleChoice(), bad]), now);
      final problem = problems.single as QuestionPublishProblem;
      expect(problem.position, 2);
      expect(problem.problem, QuestionProblem.noCorrectAnswer);
    });

    test('a question flagged for review, and one with a stale key', () {
      final problems = ExamValidation.publishing(
        ready().copyWith(
          questions: [
            singleChoice(needsReview: true),
            singleChoice(id: 'b', answerKeyStale: true),
          ],
        ),
        now,
      );
      expect(problems.map((p) => (p as QuestionPublishProblem).problem), [
        QuestionProblem.flaggedForReview,
        QuestionProblem.answerKeyStale,
      ]);
    });

    test('the start time has passed (including exactly now)', () {
      expect(
        ExamValidation.publishing(anExam(opensAt: now.subtract(const Duration(minutes: 1)), closesAt: closes), now),
        [isA<StartTimePassedProblem>()],
      );
      expect(ExamValidation.publishing(anExam(opensAt: now, closesAt: closes), now), [isA<StartTimePassedProblem>()]);
    });

    test('no schedule, and a window shorter than the duration', () {
      expect(ExamValidation.publishing(anExam(), now), [isA<ScheduleMissingProblem>()]);
      expect(ExamValidation.publishing(anExam(opensAt: opens, closesAt: opens.add(const Duration(minutes: 10))), now), [
        isA<WindowTooShortProblem>(),
      ]);
    });

    test('details out of range, including a missing pass mark', () {
      final problems = ExamValidation.publishing(anExam(opensAt: opens, closesAt: closes, passMark: null), now);
      expect((problems.single as DetailsIncompleteProblem).fields, ['passMarkPercent']);
    });

    test('every problem is reported, in order, not just the first', () {
      final problems = ExamValidation.publishing(anExam(questions: const []), now);
      expect(problems, [isA<NoQuestionsProblem>(), isA<ScheduleMissingProblem>()]);
    });
  });

  group('version bookkeeping', () {
    test('the content fingerprint ignores bookkeeping but notices anything a student sees or is graded on', () {
      final base = anExam(opensAt: DateTime.utc(2026, 11, 1, 9), closesAt: DateTime.utc(2026, 11, 1, 12));
      expect(base.copyWith(version: 9, updatedAt: DateTime.utc(2030)).contentFingerprint, base.contentFingerprint);
      expect(base.copyWith(title: 'Other').contentFingerprint, isNot(base.contentFingerprint));
      expect(base.copyWith(durationMinutes: 61).contentFingerprint, isNot(base.contentFingerprint));
      expect(
        base.copyWith(settings: const ExamSettings(calculatorEnabled: true)).contentFingerprint,
        isNot(base.contentFingerprint),
      );
      final flipped = singleChoice(correct: 2);
      expect(base.copyWith(questions: [flipped]).contentFingerprint, isNot(base.contentFingerprint));
    });
  });

  group('JSON', () {
    test('an exam round-trips with its questions, settings and nulls', () {
      final exam = anExam(
        questions: [singleChoice(), multipleChoice(), shortText()],
        opensAt: DateTime.utc(2026, 11, 1, 9),
        closesAt: DateTime.utc(2026, 11, 1, 12),
        passMark: null,
      );
      final back = Exam.fromJson(JsonReader.of(exam.toJson()));
      expect(back.toJson(), exam.toJson());
      expect(back.passMarkPercent, isNull);
      expect(back.questions.map((q) => q.type), [
        QuestionType.singleChoice,
        QuestionType.multipleChoice,
        QuestionType.shortText,
      ]);
      expect(back.totalMarks, 1 + 2 + 5);
    });

    test('an unrecognised question type or lifecycle is a hard parse error', () {
      final json = anExam().toJson();
      (json['questions']! as List<Object?>).cast<Map<String, Object?>>().first['type'] = 'essay';
      expect(() => Exam.fromJson(JsonReader.of(json)), throwsA(isA<JsonParseException>()));
      final lifecycle = anExam().toJson()..['lifecycle'] = 'live';
      expect(() => Exam.fromJson(JsonReader.of(lifecycle)), throwsA(isA<JsonParseException>()));
    });
  });
}
