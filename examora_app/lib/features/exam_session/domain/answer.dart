import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:meta/meta.dart';

/// What a student answered. A choice answer holds OPTION IDS, never positions: the order options are shown in can change
/// (it is shuffled per student when the exam asks for that) without changing what an answer means.
@immutable
sealed class AnswerValue {
  /// Creates an answer.
  const AnswerValue();

  /// Reads an answer. An unknown kind is a parse error.
  factory AnswerValue.fromJson(JsonReader json) {
    final kind = json.string('kind');
    return switch (kind) {
      'choice' => ChoiceAnswer({...json.stringList('optionIds')}),
      'text' => TextAnswer(json.string('text')),
      _ => throw JsonParseException('kind', 'has the unrecognised value "$kind"'),
    };
  }

  /// The stored form.
  Map<String, Object?> toJson();
}

/// One or more chosen options.
final class ChoiceAnswer extends AnswerValue {
  /// Creates a choice answer.
  const ChoiceAnswer(this.optionIds);

  /// The ids of the chosen options.
  final Set<String> optionIds;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'choice',
    'optionIds': ([...optionIds]..sort()),
  };

  @override
  bool operator ==(Object other) =>
      other is ChoiceAnswer && other.optionIds.length == optionIds.length && other.optionIds.containsAll(optionIds);

  @override
  int get hashCode => Object.hashAllUnordered(optionIds);
}

/// Typed text.
final class TextAnswer extends AnswerValue {
  /// Creates a text answer.
  const TextAnswer(this.text);

  /// The longest answer the app keeps.
  static const int maxLength = 10000;

  /// What was typed.
  final String text;

  @override
  Map<String, Object?> toJson() => {'kind': 'text', 'text': text};

  @override
  bool operator ==(Object other) => other is TextAnswer && other.text == text;

  @override
  int get hashCode => text.hashCode;
}
