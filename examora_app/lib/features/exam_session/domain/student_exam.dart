import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:meta/meta.dart';

/// An option as a student sees it. There is no field for "is correct": a student's types cannot carry an answer key.
@immutable
final class StudentOption {
  /// Creates an option.
  const StudentOption({required this.id, required this.text});

  /// Reads an option.
  factory StudentOption.of(QuestionOption option) => StudentOption(id: option.id, text: option.text);

  /// The stable id that an answer refers to.
  final String id;

  /// What the student reads.
  final String text;
}

/// A question as a student sees it: no correct options, no model answer, no explanation.
@immutable
final class StudentQuestion {
  /// Creates a question.
  const StudentQuestion({
    required this.id,
    required this.type,
    required this.text,
    required this.marks,
    required this.options,
  });

  /// Strips a question down to what a student may see. [optionOrder] is the order the options are shown in (their ids).
  factory StudentQuestion.of(Question question, {List<String>? optionOrder}) {
    final byId = {for (final option in question.options) option.id: option};
    final ordered = optionOrder == null
        ? question.options
        : [
            for (final id in optionOrder)
              if (byId[id] != null) byId[id]!,
          ];
    return StudentQuestion(
      id: question.id,
      type: question.type,
      text: question.text,
      marks: question.marks,
      options: [for (final option in ordered) StudentOption.of(option)],
    );
  }

  /// The question's id.
  final String id;

  /// The kind of question.
  final QuestionType type;

  /// The question text.
  final String text;

  /// What a fully correct answer earns.
  final double marks;

  /// The options in the order this student sees them.
  final List<StudentOption> options;
}

/// Where a student stands with an exam.
enum AttemptState {
  /// No attempt yet.
  notStarted,

  /// An attempt is under way.
  inProgress,

  /// The attempt was submitted.
  submitted,
}

/// An exam in a student's list.
@immutable
final class StudentExamSummary {
  /// Creates a summary.
  const StudentExamSummary({
    required this.id,
    required this.title,
    required this.courseName,
    required this.durationMinutes,
    required this.status,
    required this.attemptState,
    required this.questionCount,
    this.opensAt,
    this.closesAt,
    this.attemptId,
  });

  /// The exam's id.
  final String id;

  /// The title.
  final String title;

  /// The course.
  final String courseName;

  /// How long one attempt lasts.
  final int durationMinutes;

  /// Scheduled, ongoing or completed.
  final ExamStatus status;

  /// This student's attempt, if any.
  final AttemptState attemptState;

  /// How many questions the exam has.
  final int questionCount;

  /// When students may start.
  final DateTime? opensAt;

  /// When the window closes.
  final DateTime? closesAt;

  /// The student's attempt id, when they have one.
  final String? attemptId;
}

/// What the briefing screen shows: everything about the exam a student is allowed to know before starting.
@immutable
final class StudentExamInfo {
  /// Creates the info.
  const StudentExamInfo({
    required this.id,
    required this.title,
    required this.courseName,
    required this.description,
    required this.instructions,
    required this.durationMinutes,
    required this.status,
    required this.questionCount,
    required this.totalMarks,
    required this.version,
    required this.calculatorEnabled,
    required this.allowBackwardNavigation,
    required this.randomizeQuestions,
    required this.randomizeOptions,
    required this.activeRules,
    required this.inactiveRules,
    required this.attemptState,
    this.opensAt,
    this.closesAt,
    this.attemptId,
  });

  /// The exam's id.
  final String id;

  /// The title.
  final String title;

  /// The course.
  final String courseName;

  /// The description.
  final String description;

  /// What the instructor tells students.
  final String instructions;

  /// How long one attempt lasts.
  final int durationMinutes;

  /// Scheduled, ongoing or completed.
  final ExamStatus status;

  /// How many questions.
  final int questionCount;

  /// The total marks.
  final double totalMarks;

  /// The exam's version.
  final int version;

  /// Whether the calculator is offered.
  final bool calculatorEnabled;

  /// Whether earlier questions can be revisited.
  final bool allowBackwardNavigation;

  /// Whether the question order is shuffled.
  final bool randomizeQuestions;

  /// Whether the option order is shuffled.
  final bool randomizeOptions;

  /// The proctoring rules that actually watch this exam.
  final Set<IncidentCategory> activeRules;

  /// Rules the instructor listed that this build cannot run (they need a face, gaze or speech model).
  final Set<IncidentCategory> inactiveRules;

  /// This student's attempt state.
  final AttemptState attemptState;

  /// When students may start.
  final DateTime? opensAt;

  /// When the window closes.
  final DateTime? closesAt;

  /// The student's attempt id, when they have one.
  final String? attemptId;

  /// Builds the student's view of [exam].
  factory StudentExamInfo.of(
    Exam exam, {
    required DateTime now,
    required AttemptState attemptState,
    String? attemptId,
  }) {
    final settings = exam.settings;
    return StudentExamInfo(
      id: exam.id,
      title: exam.title,
      courseName: exam.courseName,
      description: exam.description,
      instructions: exam.instructions,
      durationMinutes: exam.durationMinutes,
      status: exam.statusAt(now),
      questionCount: exam.questions.length,
      totalMarks: exam.totalMarks,
      version: exam.version,
      calculatorEnabled: settings.calculatorEnabled,
      allowBackwardNavigation: settings.allowBackwardNavigation,
      randomizeQuestions: settings.randomizeQuestions,
      randomizeOptions: settings.randomizeOptions,
      activeRules: {
        for (final rule in settings.enabledRules)
          if (rule.hasDetector) rule,
      },
      inactiveRules: {
        for (final rule in settings.enabledRules)
          if (!rule.hasDetector) rule,
      },
      attemptState: attemptState,
      opensAt: exam.opensAt,
      closesAt: exam.closesAt,
      attemptId: attemptId,
    );
  }
}
