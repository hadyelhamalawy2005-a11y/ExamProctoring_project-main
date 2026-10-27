import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

/// A valid single-choice question: options A..D, [correct] (0-based) is right.
Question singleChoice({
  String id = 'q1',
  String text = 'What is 2 + 2?',
  double marks = 1,
  int correct = 1,
  List<String> options = const ['3', '4', '5', '6'],
  bool needsReview = false,
  bool answerKeyStale = false,
}) => Question(
  id: id,
  type: QuestionType.singleChoice,
  text: text,
  marks: marks,
  options: [
    for (var index = 0; index < options.length; index++)
      QuestionOption(id: '$id-o$index', text: options[index], isCorrect: index == correct),
  ],
  needsReview: needsReview,
  answerKeyStale: answerKeyStale,
);

/// A valid multiple-choice question whose correct options are [correct] (0-based).
Question multipleChoice({
  String id = 'm1',
  String text = 'Which are prime?',
  double marks = 2,
  Set<int> correct = const {0, 2},
  List<String> options = const ['2', '4', '5', '9'],
}) => Question(
  id: id,
  type: QuestionType.multipleChoice,
  text: text,
  marks: marks,
  options: [
    for (var index = 0; index < options.length; index++)
      QuestionOption(id: '$id-o$index', text: options[index], isCorrect: correct.contains(index)),
  ],
);

/// A valid short-text question.
Question shortText({String id = 's1', String text = 'Explain recursion.', double marks = 5}) =>
    Question(id: id, type: QuestionType.shortText, text: text, marks: marks, modelAnswer: 'A function calling itself.');

/// Valid first-step details.
ExamDetails details({
  String title = 'Algorithms midterm',
  String course = 'CS201',
  int minutes = 60,
  double passMark = 50,
  String description = 'Chapters 1 to 4',
  String instructions = 'No notes allowed.',
}) => ExamDetails(
  title: title,
  courseName: course,
  description: description,
  instructions: instructions,
  durationMinutes: minutes,
  passMarkPercent: passMark,
);

/// Unwraps a success or fails the test with the failure.
T ok<T>(Result<T> result) {
  switch (result) {
    case Ok<T>(:final value):
      return value;
    case Err<T>(:final failure):
      fail('expected success, got $failure');
  }
}

/// Unwraps a failure or fails the test with the value.
AppFailure err<T>(Result<T> result) {
  switch (result) {
    case Ok<T>(:final value):
      fail('expected a failure, got $value');
    case Err<T>(:final failure):
      return failure;
  }
}
