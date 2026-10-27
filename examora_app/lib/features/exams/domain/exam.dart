import 'dart:convert';

import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/exams/domain/exam_settings.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:meta/meta.dart';

/// What the instructor did with an exam. The status students and instructors see is worked out from this and the clock.
enum ExamLifecycle {
  /// Being written. Not visible to students.
  draft('draft'),

  /// Published: visible to students from its window.
  published('published'),

  /// Withdrawn for good.
  archived('archived');

  const ExamLifecycle(this.wireName);

  /// The stored and wire name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, ExamLifecycle> byWireName = {
    'draft': ExamLifecycle.draft,
    'published': ExamLifecycle.published,
    'archived': ExamLifecycle.archived,
  };
}

/// The status of an exam right now.
enum ExamStatus {
  /// Being written.
  draft,

  /// Published, not open yet.
  scheduled,

  /// Open now.
  ongoing,

  /// The window has closed.
  completed,

  /// Withdrawn.
  archived,
}

/// The fields of the first wizard step.
@immutable
final class ExamDetails {
  /// Creates the details.
  const ExamDetails({
    required this.title,
    required this.courseName,
    required this.durationMinutes,
    required this.passMarkPercent,
    this.description = '',
    this.instructions = '',
  });

  /// The exam's title.
  final String title;

  /// The course it belongs to.
  final String courseName;

  /// A short description.
  final String description;

  /// What students are told before they start.
  final String instructions;

  /// How long one attempt lasts.
  final int durationMinutes;

  /// The percentage of the total marks needed to pass.
  final double passMarkPercent;
}

/// An exam with its questions and settings.
@immutable
final class Exam {
  /// Creates an exam.
  const Exam({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.courseName,
    required this.description,
    required this.instructions,
    required this.durationMinutes,
    required this.settings,
    required this.version,
    required this.lifecycle,
    this.createdAt,
    this.updatedAt,
    this.passMarkPercent,
    this.opensAt,
    this.closesAt,
    this.publishedAt,
    this.archivedAt,
    this.questions = const [],
  });

  /// Reads an exam.
  factory Exam.fromJson(JsonReader json) => Exam(
    id: json.string('id'),
    ownerId: json.string('ownerId'),
    title: json.string('title'),
    courseName: json.string('courseName'),
    description: json.string('description'),
    instructions: json.string('instructions'),
    durationMinutes: json.integer('durationMinutes'),
    passMarkPercent: json.optionalNumber('passMarkPercent'),
    opensAt: json.optionalDateTime('opensAt'),
    closesAt: json.optionalDateTime('closesAt'),
    settings: ExamSettings.fromJson(json.object('settings')),
    version: json.integer('version'),
    lifecycle: json.enumValue('lifecycle', ExamLifecycle.byWireName),
    publishedAt: json.optionalDateTime('publishedAt'),
    archivedAt: json.optionalDateTime('archivedAt'),
    createdAt: json.optionalDateTime('createdAt'),
    updatedAt: json.optionalDateTime('updatedAt'),
    questions: json.list('questions', Question.fromJson),
  );

  /// A stable identifier.
  final String id;

  /// The instructor who owns it. Nobody else may read or change it.
  final String ownerId;

  /// The exam's title.
  final String title;

  /// The course it belongs to.
  final String courseName;

  /// A short description.
  final String description;

  /// What students are told before they start.
  final String instructions;

  /// How long one attempt lasts, in minutes.
  final int durationMinutes;

  /// The percentage of the total marks needed to pass, or null when none was set (an exam read from a server that does
  /// not store one). With no pass mark a result shows the marks only, never "passed" or "failed".
  final double? passMarkPercent;

  /// When students may start (UTC).
  final DateTime? opensAt;

  /// When students can no longer start, and every attempt ends at the latest (UTC).
  final DateTime? closesAt;

  /// How the exam behaves.
  final ExamSettings settings;

  /// Marks an exam read from a server that does not version exams.
  static const int unversioned = 0;

  /// Starts at 1 and goes up whenever something a student sees or is graded on changes after the exam was first
  /// published, so an attempt that began against an older version can be recognised.
  final int version;

  /// What the instructor did with it.
  final ExamLifecycle lifecycle;

  /// When it was last published.
  final DateTime? publishedAt;

  /// When it was archived.
  final DateTime? archivedAt;

  /// When it was created, or null when the source does not say.
  final DateTime? createdAt;

  /// When it last changed, or null when the source does not say.
  final DateTime? updatedAt;

  /// The questions, in order.
  final List<Question> questions;

  /// The sum of every question's marks.
  double get totalMarks => questions.fold(0, (sum, question) => sum + question.marks);

  /// The status at [now].
  ExamStatus statusAt(DateTime now) {
    switch (lifecycle) {
      case ExamLifecycle.draft:
        return ExamStatus.draft;
      case ExamLifecycle.archived:
        return ExamStatus.archived;
      case ExamLifecycle.published:
        final opens = opensAt;
        final closes = closesAt;
        if (opens == null || closes == null) return ExamStatus.scheduled;
        if (now.isBefore(opens)) return ExamStatus.scheduled;
        if (now.isBefore(closes)) return ExamStatus.ongoing;
        return ExamStatus.completed;
    }
  }

  /// The moment an attempt that began at [startedAt] must end: the duration later, but never after the window closes.
  DateTime deadlineFor(DateTime startedAt) {
    final byDuration = startedAt.add(Duration(minutes: durationMinutes));
    final closes = closesAt;
    return closes != null && closes.isBefore(byDuration) ? closes : byDuration;
  }

  /// A copy with the given changes.
  Exam copyWith({
    String? title,
    String? courseName,
    String? description,
    String? instructions,
    int? durationMinutes,
    ({double? value})? passMarkPercent,
    ({DateTime? value})? opensAt,
    ({DateTime? value})? closesAt,
    ExamSettings? settings,
    int? version,
    ExamLifecycle? lifecycle,
    ({DateTime? value})? publishedAt,
    ({DateTime? value})? archivedAt,
    DateTime? updatedAt,
    List<Question>? questions,
  }) => Exam(
    id: id,
    ownerId: ownerId,
    title: title ?? this.title,
    courseName: courseName ?? this.courseName,
    description: description ?? this.description,
    instructions: instructions ?? this.instructions,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    passMarkPercent: passMarkPercent == null ? this.passMarkPercent : passMarkPercent.value,
    opensAt: opensAt == null ? this.opensAt : opensAt.value,
    closesAt: closesAt == null ? this.closesAt : closesAt.value,
    settings: settings ?? this.settings,
    version: version ?? this.version,
    lifecycle: lifecycle ?? this.lifecycle,
    publishedAt: publishedAt == null ? this.publishedAt : publishedAt.value,
    archivedAt: archivedAt == null ? this.archivedAt : archivedAt.value,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    questions: questions ?? this.questions,
  );

  /// Everything that decides what a student sees and how they are graded, as one comparable text. It leaves out the
  /// bookkeeping (version, timestamps, who published), so two exams with equal fingerprints are the same exam to a student.
  String get contentFingerprint => jsonEncode({
    'title': title,
    'courseName': courseName,
    'description': description,
    'instructions': instructions,
    'durationMinutes': durationMinutes,
    'passMarkPercent': passMarkPercent,
    'opensAt': opensAt?.toUtc().toIso8601String(),
    'closesAt': closesAt?.toUtc().toIso8601String(),
    'settings': settings.toJson(),
    'questions': [
      for (final question in questions)
        {...question.toJson()}
          ..remove('needsReview')
          ..remove('answerKeyStale')
          ..remove('source'),
    ],
  });

  /// The stored form.
  Map<String, Object?> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'title': title,
    'courseName': courseName,
    'description': description,
    'instructions': instructions,
    'durationMinutes': durationMinutes,
    'passMarkPercent': passMarkPercent,
    'opensAt': opensAt?.toUtc().toIso8601String(),
    'closesAt': closesAt?.toUtc().toIso8601String(),
    'settings': settings.toJson(),
    'version': version,
    'lifecycle': lifecycle.wireName,
    'publishedAt': publishedAt?.toUtc().toIso8601String(),
    'archivedAt': archivedAt?.toUtc().toIso8601String(),
    'createdAt': createdAt?.toUtc().toIso8601String(),
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
    'questions': [for (final question in questions) question.toJson()],
  };
}

/// An exam as a list shows it. [questionCount] is null when the source cannot say (so the list never shows a made-up 0).
@immutable
final class ExamSummary {
  /// Creates a summary.
  const ExamSummary({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.status,
    required this.version,
    this.courseName,
    this.opensAt,
    this.closesAt,
    this.questionCount,
  });

  /// The exam's id.
  final String id;

  /// The title.
  final String title;

  /// The course, or null when the source does not store one.
  final String? courseName;

  /// How long one attempt lasts.
  final int durationMinutes;

  /// The status when the list was read.
  final ExamStatus status;

  /// The exam's version.
  final int version;

  /// When students may start.
  final DateTime? opensAt;

  /// When the window closes.
  final DateTime? closesAt;

  /// How many questions, or null when unknown.
  final int? questionCount;
}

/// One page of exams. [totalCount] counts every match, not only this page.
@immutable
final class ExamPage {
  /// Creates a page.
  const ExamPage({required this.items, required this.page, required this.pageSize, required this.totalCount});

  /// The exams on this page, newest first.
  final List<ExamSummary> items;

  /// The page number, starting at 1.
  final int page;

  /// How many exams a page holds.
  final int pageSize;

  /// How many exams match in total.
  final int totalCount;

  /// True when more exams follow.
  bool get hasNext => page * pageSize < totalCount;

  /// True when an earlier page exists.
  bool get hasPrevious => page > 1;
}
