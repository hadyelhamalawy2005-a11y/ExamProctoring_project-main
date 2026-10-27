import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:meta/meta.dart';

/// A student accepted the proctoring notice for an exam.
@immutable
final class ConsentRecord {
  /// Creates a record.
  const ConsentRecord({required this.studentId, required this.examId, required this.givenAt});

  /// Reads a record.
  factory ConsentRecord.fromJson(JsonReader json) => ConsentRecord(
    studentId: json.string('studentId'),
    examId: json.string('examId'),
    givenAt: json.dateTime('givenAt'),
  );

  /// Who accepted.
  final String studentId;

  /// Which exam.
  final String examId;

  /// When.
  final DateTime givenAt;

  /// The stored form.
  Map<String, Object?> toJson() => {
    'studentId': studentId,
    'examId': examId,
    'givenAt': givenAt.toUtc().toIso8601String(),
  };
}
