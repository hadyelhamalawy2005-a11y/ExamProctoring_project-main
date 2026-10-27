import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/grading.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:meta/meta.dart';

/// Whether an attempt is under way.
enum AttemptStatus {
  /// The student is working on it.
  inProgress('inProgress'),

  /// It was submitted (by the student or by the clock) and can no longer change.
  submitted('submitted');

  const AttemptStatus(this.wireName);

  /// The stored name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, AttemptStatus> byWireName = {
    'inProgress': AttemptStatus.inProgress,
    'submitted': AttemptStatus.submitted,
  };
}

/// Who submitted.
enum SubmissionKind {
  /// The student pressed Submit.
  manual('manual'),

  /// The deadline passed, so the app submitted what was saved.
  auto('auto');

  const SubmissionKind(this.wireName);

  /// The stored name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, SubmissionKind> byWireName = {'manual': SubmissionKind.manual, 'auto': SubmissionKind.auto};
}

/// One student's attempt at one exam, as stored on the device.
///
/// It carries a snapshot of the exam as it was when the attempt began, answer key included, so a later edit to the exam can
/// never change how this attempt is graded. Only the repositories read the snapshot; a student's own view of the attempt
/// ([StudentAttemptSession]) has no field that could hold the key.
@immutable
final class Attempt {
  /// Creates an attempt.
  const Attempt({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.exam,
    required this.startedAt,
    required this.deadline,
    required this.lastSeenAt,
    required this.status,
    required this.currentIndex,
    required this.questionOrder,
    required this.optionOrders,
    required this.answers,
    required this.manualMarks,
    this.submittedAt,
    this.submissionKind,
    this.result,
  });

  /// Reads an attempt.
  factory Attempt.fromJson(JsonReader json) => Attempt(
    id: json.string('id'),
    studentId: json.string('studentId'),
    studentName: json.string('studentName'),
    exam: Exam.fromJson(json.object('exam')),
    startedAt: json.dateTime('startedAt'),
    deadline: json.dateTime('deadline'),
    lastSeenAt: json.dateTime('lastSeenAt'),
    status: json.enumValue('status', AttemptStatus.byWireName),
    currentIndex: json.integer('currentIndex'),
    questionOrder: json.stringList('questionOrder'),
    optionOrders: {
      for (final entry in json.list(
        'optionOrders',
        (item) => (item.string('questionId'), item.stringList('optionIds')),
      ))
        entry.$1: entry.$2,
    },
    answers: {
      for (final entry in json.list(
        'answers',
        (item) => (item.string('questionId'), AnswerValue.fromJson(item.object('answer'))),
      ))
        entry.$1: entry.$2,
    },
    manualMarks: {
      for (final entry in json.list('manualMarks', (item) => (item.string('questionId'), item.number('marks'))))
        entry.$1: entry.$2,
    },
    submittedAt: json.optionalDateTime('submittedAt'),
    submissionKind: json.has('submissionKind') && json.optionalString('submissionKind') != null
        ? json.enumValue('submissionKind', SubmissionKind.byWireName)
        : null,
    result: json.optionalObject('result') == null ? null : AttemptResult.fromJson(json.object('result')),
  );

  /// The attempt's id.
  final String id;

  /// The student.
  final String studentId;

  /// The student's name when the attempt began (for the instructor's list).
  final String studentName;

  /// The exam as it was when the attempt began, with its answer key.
  final Exam exam;

  /// When the student began.
  final DateTime startedAt;

  /// When the attempt ends, fixed when it begins. Resuming never moves it.
  final DateTime deadline;

  /// The latest moment the app has ever seen on the clock during this attempt. The timer never goes below it, so turning
  /// the device clock back cannot give time back.
  final DateTime lastSeenAt;

  /// Whether the attempt is still open.
  final AttemptStatus status;

  /// The question the student was on (0-based), so resuming returns there.
  final int currentIndex;

  /// The question ids in the order this student sees them.
  final List<String> questionOrder;

  /// For each choice question, the option ids in the order this student sees them.
  final Map<String, List<String>> optionOrders;

  /// The answers saved so far, by question id.
  final Map<String, AnswerValue> answers;

  /// Marks an instructor gave to typed answers, by question id.
  final Map<String, double> manualMarks;

  /// When it was submitted.
  final DateTime? submittedAt;

  /// How it was submitted.
  final SubmissionKind? submissionKind;

  /// The marks, worked out once at submission (and again when an instructor marks a typed answer).
  final AttemptResult? result;

  /// The questions in this student's order.
  List<Question> get orderedQuestions {
    final byId = {for (final question in exam.questions) question.id: question};
    return [
      for (final id in questionOrder)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// A copy with the given changes.
  Attempt copyWith({
    DateTime? lastSeenAt,
    AttemptStatus? status,
    int? currentIndex,
    Map<String, AnswerValue>? answers,
    Map<String, double>? manualMarks,
    DateTime? submittedAt,
    SubmissionKind? submissionKind,
    AttemptResult? result,
  }) => Attempt(
    id: id,
    studentId: studentId,
    studentName: studentName,
    exam: exam,
    startedAt: startedAt,
    deadline: deadline,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    status: status ?? this.status,
    currentIndex: currentIndex ?? this.currentIndex,
    questionOrder: questionOrder,
    optionOrders: optionOrders,
    answers: answers ?? this.answers,
    manualMarks: manualMarks ?? this.manualMarks,
    submittedAt: submittedAt ?? this.submittedAt,
    submissionKind: submissionKind ?? this.submissionKind,
    result: result ?? this.result,
  );

  /// The stored form.
  Map<String, Object?> toJson() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'exam': exam.toJson(),
    'startedAt': startedAt.toUtc().toIso8601String(),
    'deadline': deadline.toUtc().toIso8601String(),
    'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
    'status': status.wireName,
    'currentIndex': currentIndex,
    'questionOrder': questionOrder,
    'optionOrders': [
      for (final entry in optionOrders.entries) {'questionId': entry.key, 'optionIds': entry.value},
    ],
    'answers': [
      for (final entry in answers.entries) {'questionId': entry.key, 'answer': entry.value.toJson()},
    ],
    'manualMarks': [
      for (final entry in manualMarks.entries) {'questionId': entry.key, 'marks': entry.value},
    ],
    'submittedAt': submittedAt?.toUtc().toIso8601String(),
    'submissionKind': submissionKind?.wireName,
    'result': result?.toJson(),
  };
}

/// Keeps the timer honest. The deadline is an absolute moment; what is left is always [deadline] minus the clock, worked
/// out afresh every time, never counted down. The clock reading is also never allowed to go backwards: the latest moment
/// ever seen is the floor, so setting the device clock back, or killing the app and reopening it, cannot gain a second.
final class AttemptTimer {
  /// Creates a timer for an attempt ending at [deadline] that has already seen the clock reach [seenUpTo].
  AttemptTimer({required this.deadline, required DateTime seenUpTo}) : _floor = seenUpTo.toUtc();

  /// When the attempt ends.
  final DateTime deadline;

  DateTime _floor;

  /// The latest moment seen so far.
  DateTime get seenUpTo => _floor;

  /// Takes a clock reading and returns the moment to use: [reading], unless the clock went backwards, in which case the
  /// latest moment already seen.
  DateTime observe(DateTime reading) {
    final utc = reading.toUtc();
    if (utc.isAfter(_floor)) _floor = utc;
    return _floor;
  }

  /// What is left at [reading]; never negative.
  Duration remaining(DateTime reading) {
    final left = deadline.difference(observe(reading));
    return left.isNegative ? Duration.zero : left;
  }

  /// True once the deadline has been reached.
  bool isOver(DateTime reading) => remaining(reading) == Duration.zero;
}
