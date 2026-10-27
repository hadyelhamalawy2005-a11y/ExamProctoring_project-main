import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';

/// The rules for exams and questions. Manual authoring, the Word importer, the repositories and publishing all call
/// these, so they can never disagree about what is valid.
abstract final class ExamValidation {
  /// Problems with the first wizard step, by field name (empty when everything is fine).
  static Map<String, FieldProblem> details(ExamDetails details) => {
    'title': ?Validators.text(details.title, maxLength: ExamLimits.titleMax),
    'courseName': ?Validators.text(details.courseName, maxLength: ExamLimits.courseNameMax),
    if (details.description.trim().length > ExamLimits.descriptionMax) 'description': _tooLong,
    if (details.instructions.trim().length > ExamLimits.instructionsMax) 'instructions': _tooLong,
    if (details.durationMinutes < ExamLimits.durationMin || details.durationMinutes > ExamLimits.durationMax)
      'durationMinutes': _outOfRange,
    if (details.passMarkPercent.isNaN || details.passMarkPercent < 0 || details.passMarkPercent > 100)
      'passMarkPercent': _outOfRange,
  };

  /// Problems with the settings step.
  static Map<String, FieldProblem> settings(ExamSettings settings) => {
    for (final field in settings.invalidFields) field: _outOfRange,
  };

  /// Problems with the availability window for an exam lasting [durationMinutes].
  static Map<String, FieldProblem> schedule({
    required DateTime? opensAt,
    required DateTime? closesAt,
    required int durationMinutes,
  }) {
    final problems = <String, FieldProblem>{};
    if (opensAt == null) problems['opensAt'] = const KnownFieldProblem(FieldReason.required);
    if (closesAt == null) problems['closesAt'] = const KnownFieldProblem(FieldReason.required);
    if (opensAt != null && closesAt != null && closesAt.isBefore(opensAt.add(Duration(minutes: durationMinutes)))) {
      problems['closesAt'] = const KnownFieldProblem(FieldReason.windowTooShort);
    }
    return problems;
  }

  /// Whether [marks] is a number above 0, at most 9999.99, with at most two decimals.
  static bool marksAreValid(double marks) {
    if (marks.isNaN || marks.isInfinite || marks <= 0 || marks > ExamLimits.marksMax) return false;
    final cents = marks * 100;
    return (cents - cents.roundToDouble()).abs() < 1e-6;
  }

  /// What is wrong with the question's own content (never empty text, a valid answer key, ...). Order is the order a
  /// person would fix them in.
  static List<QuestionProblem> questionStructure(Question question) {
    final problems = <QuestionProblem>[];
    final text = question.text.trim();
    if (text.isEmpty) problems.add(QuestionProblem.noText);
    if (text.length > ExamLimits.questionTextMax) problems.add(QuestionProblem.textTooLong);
    if (!marksAreValid(question.marks)) problems.add(QuestionProblem.invalidMarks);
    if ((question.modelAnswer?.trim().length ?? 0) > ExamLimits.modelAnswerMax) {
      problems.add(QuestionProblem.modelAnswerTooLong);
    }

    if (!question.type.hasOptions) {
      if (question.options.isNotEmpty) problems.add(QuestionProblem.optionsOnShortText);
      return problems;
    }

    final options = question.options;
    if (options.length < ExamLimits.optionsMin) problems.add(QuestionProblem.tooFewOptions);
    if (options.length > ExamLimits.optionsMax) problems.add(QuestionProblem.tooManyOptions);
    if (options.any((option) => option.text.trim().isEmpty)) problems.add(QuestionProblem.optionEmpty);
    if (options.any((option) => option.text.trim().length > ExamLimits.optionTextMax)) {
      problems.add(QuestionProblem.optionTooLong);
    }
    final texts = [for (final option in options) option.text.trim().toLowerCase()];
    if (texts.toSet().length != texts.length) problems.add(QuestionProblem.duplicateOptionTexts);

    final correct = options.where((option) => option.isCorrect).length;
    if (correct == 0) problems.add(QuestionProblem.noCorrectAnswer);
    if (question.type == QuestionType.singleChoice && correct > 1) {
      problems.add(QuestionProblem.severalCorrectForSingle);
    }
    return problems;
  }

  /// Everything that blocks publishing a question: its content problems plus the two flags that need a human decision.
  static List<QuestionProblem> questionForPublishing(Question question) => [
    ...questionStructure(question),
    if (question.needsReview) QuestionProblem.flaggedForReview,
    if (question.answerKeyStale && question.type.hasOptions) QuestionProblem.answerKeyStale,
  ];

  /// Why [exam] cannot be published at [now]. Empty means it can be.
  static List<PublishProblem> publishing(Exam exam, DateTime now) {
    final problems = <PublishProblem>[];

    final detailFields = {
      ...details(
        ExamDetails(
          title: exam.title,
          courseName: exam.courseName,
          description: exam.description,
          instructions: exam.instructions,
          durationMinutes: exam.durationMinutes,
          passMarkPercent: exam.passMarkPercent ?? double.nan,
        ),
      ),
    };
    final settingFields = settings(exam.settings);
    if (detailFields.isNotEmpty || settingFields.isNotEmpty) {
      problems.add(DetailsIncompleteProblem([...detailFields.keys, ...settingFields.keys]));
    }

    if (exam.questions.isEmpty) {
      problems.add(const NoQuestionsProblem());
    } else {
      for (var index = 0; index < exam.questions.length; index++) {
        for (final problem in questionForPublishing(exam.questions[index])) {
          problems.add(QuestionPublishProblem(index + 1, problem));
        }
      }
    }

    final opens = exam.opensAt;
    final closes = exam.closesAt;
    if (opens == null || closes == null) {
      problems.add(const ScheduleMissingProblem());
    } else {
      if (closes.isBefore(opens.add(Duration(minutes: exam.durationMinutes)))) {
        problems.add(const WindowTooShortProblem());
      }
      if (!opens.isAfter(now)) problems.add(const StartTimePassedProblem());
    }
    return problems;
  }

  static const FieldProblem _tooLong = KnownFieldProblem(FieldReason.tooLong);
  static const FieldProblem _outOfRange = KnownFieldProblem(FieldReason.outOfRange);
}
