import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:meta/meta.dart';

/// The kinds of question. Only the first two are marked by the app.
enum QuestionType {
  /// Pick exactly one option. Marked automatically.
  singleChoice('singleChoice'),

  /// Pick any number of options. Marked automatically, ALL OR NOTHING: partial credit is a course policy, not an app
  /// decision.
  multipleChoice('multipleChoice'),

  /// Type an answer. NEVER marked by the app: it is flagged for the instructor to mark.
  shortText('shortText');

  const QuestionType(this.wireName);

  /// The stored and wire name.
  final String wireName;

  /// True for the two kinds that have options.
  bool get hasOptions => this != QuestionType.shortText;

  /// True when the app can mark it.
  bool get isAutoMarked => hasOptions;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, QuestionType> byWireName = {
    'singleChoice': QuestionType.singleChoice,
    'multipleChoice': QuestionType.multipleChoice,
    'shortText': QuestionType.shortText,
  };
}

/// Where a question came from.
enum QuestionSource {
  /// Typed in by the instructor.
  manual('manual'),

  /// Read from a Word document.
  wordImport('wordImport');

  const QuestionSource(this.wireName);

  /// The stored and wire name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, QuestionSource> byWireName = {
    'manual': QuestionSource.manual,
    'wordImport': QuestionSource.wordImport,
  };
}

/// One answer option. Its [id] never changes, so an answer refers to an option, not to a position, and shuffling the order
/// can never change what an answer means.
@immutable
final class QuestionOption {
  /// Creates an option.
  const QuestionOption({required this.id, required this.text, required this.isCorrect});

  /// Reads an option.
  factory QuestionOption.fromJson(JsonReader json) =>
      QuestionOption(id: json.string('id'), text: json.string('text'), isCorrect: json.boolean('isCorrect'));

  /// The stable identifier.
  final String id;

  /// What the student reads.
  final String text;

  /// Whether choosing it is right. Students never receive this.
  final bool isCorrect;

  /// A copy with the given changes.
  QuestionOption copyWith({String? text, bool? isCorrect}) =>
      QuestionOption(id: id, text: text ?? this.text, isCorrect: isCorrect ?? this.isCorrect);

  /// The stored form.
  Map<String, Object?> toJson() => {'id': id, 'text': text, 'isCorrect': isCorrect};

  @override
  bool operator ==(Object other) =>
      other is QuestionOption && other.id == id && other.text == text && other.isCorrect == isCorrect;

  @override
  int get hashCode => Object.hash(id, text, isCorrect);
}

/// A question with its answer key. Only instructors ever hold one of these; students get a `StudentQuestion`, which has
/// no field for the key.
@immutable
final class Question {
  /// Creates a question.
  const Question({
    required this.id,
    required this.type,
    required this.text,
    required this.marks,
    this.options = const [],
    this.modelAnswer,
    this.explanation,
    this.topic,
    this.difficulty,
    this.source = QuestionSource.manual,
    this.needsReview = false,
    this.answerKeyStale = false,
  });

  /// Reads a question.
  factory Question.fromJson(JsonReader json) => Question(
    id: json.string('id'),
    type: json.enumValue('type', QuestionType.byWireName),
    text: json.string('text'),
    marks: json.number('marks'),
    options: json.list('options', QuestionOption.fromJson),
    modelAnswer: json.optionalString('modelAnswer'),
    explanation: json.optionalString('explanation'),
    topic: json.optionalString('topic'),
    difficulty: json.optionalString('difficulty'),
    source: json.enumValue('source', QuestionSource.byWireName),
    needsReview: json.boolean('needsReview'),
    answerKeyStale: json.boolean('answerKeyStale'),
  );

  /// The stable identifier.
  final String id;

  /// What kind of question it is.
  final QuestionType type;

  /// The question itself.
  final String text;

  /// What a fully correct answer earns.
  final double marks;

  /// The options, in the order the instructor wrote them (empty for short text).
  final List<QuestionOption> options;

  /// What a good short-text answer looks like, for the person marking it. Never used to mark automatically.
  final String? modelAnswer;

  /// Shown with the result when the exam allows explanations.
  final String? explanation;

  /// The topic the question covers, as written in an import file. Only a label for the instructor.
  final String? topic;

  /// The difficulty, as written in an import file. Only a label for the instructor; never used to mark.
  final String? difficulty;

  /// Where the question came from.
  final QuestionSource source;

  /// True while the question is flagged for review (an import that needs a human decision). Blocks publishing.
  final bool needsReview;

  /// True when the options changed after the correct answer was set and nobody confirmed the answer again. Blocks
  /// publishing.
  final bool answerKeyStale;

  /// The ids of the options marked correct.
  Set<String> get correctOptionIds => {
    for (final option in options)
      if (option.isCorrect) option.id,
  };

  /// A copy with the given changes.
  Question copyWith({
    QuestionType? type,
    String? text,
    double? marks,
    List<QuestionOption>? options,
    ({String? value})? modelAnswer,
    ({String? value})? explanation,
    ({String? value})? topic,
    ({String? value})? difficulty,
    QuestionSource? source,
    bool? needsReview,
    bool? answerKeyStale,
  }) => Question(
    id: id,
    type: type ?? this.type,
    text: text ?? this.text,
    marks: marks ?? this.marks,
    options: options ?? this.options,
    modelAnswer: modelAnswer == null ? this.modelAnswer : modelAnswer.value,
    explanation: explanation == null ? this.explanation : explanation.value,
    topic: topic == null ? this.topic : topic.value,
    difficulty: difficulty == null ? this.difficulty : difficulty.value,
    source: source ?? this.source,
    needsReview: needsReview ?? this.needsReview,
    answerKeyStale: answerKeyStale ?? this.answerKeyStale,
  );

  /// The stored form.
  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.wireName,
    'text': text,
    'marks': marks,
    'options': [for (final option in options) option.toJson()],
    'modelAnswer': modelAnswer,
    'explanation': explanation,
    'topic': topic,
    'difficulty': difficulty,
    'source': source.wireName,
    'needsReview': needsReview,
    'answerKeyStale': answerKeyStale,
  };

  @override
  bool operator ==(Object other) =>
      other is Question &&
      other.id == id &&
      other.type == type &&
      other.text == text &&
      other.marks == marks &&
      _sameOptions(other.options, options) &&
      other.modelAnswer == modelAnswer &&
      other.explanation == explanation &&
      other.topic == topic &&
      other.difficulty == difficulty &&
      other.source == source &&
      other.needsReview == needsReview &&
      other.answerKeyStale == answerKeyStale;

  @override
  int get hashCode =>
      Object.hash(id, type, text, marks, Object.hashAll(options), modelAnswer, explanation, topic, difficulty, source);

  static bool _sameOptions(List<QuestionOption> a, List<QuestionOption> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }
}

/// Decides whether a saved edit leaves the answer key stale.
abstract final class AnswerKey {
  /// Whether [after], saved over [before], leaves the answer key stale.
  ///
  /// Stale means the options (their number, ids or texts) changed while exactly the same options stayed marked correct,
  /// so nobody looked at the answer again against the new wording. It is not stale when the instructor [confirmed] the
  /// answer in this save, or changed which options are correct (that is a confirmation). With no change to the options
  /// the previous state is kept.
  static bool staleAfterEdit(Question before, Question after, {required bool confirmed}) {
    if (!after.type.hasOptions || confirmed) return false;
    final correctChanged = !_sameSet(before.correctOptionIds, after.correctOptionIds);
    if (correctChanged) return false;
    if (!_sameTexts(before.options, after.options)) return true;
    return before.answerKeyStale;
  }

  static bool _sameTexts(List<QuestionOption> a, List<QuestionOption> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index].id != b[index].id || a[index].text != b[index].text) return false;
    }
    return true;
  }

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);
}
