import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:meta/meta.dart';

/// What an instructor decided about an incident.
enum ReviewDecision {
  /// Looked at, and nothing wrong happened.
  noViolation('noViolation'),

  /// Looked at, and it was a violation.
  violationConfirmed('violationConfirmed'),

  /// Looked at, and the evidence does not settle it.
  inconclusive('inconclusive');

  const ReviewDecision(this.wireName);

  /// The stored name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, ReviewDecision> byWireName = {
    'noViolation': ReviewDecision.noViolation,
    'violationConfirmed': ReviewDecision.violationConfirmed,
    'inconclusive': ReviewDecision.inconclusive,
  };
}

/// Whether there is a recording of the moment.
enum EvidenceStatus {
  /// There is none, and the reason is stated. This is what every incident has in this build.
  unavailable('unavailable'),

  /// There is one, and [Evidence.reference] points to it.
  captured('captured');

  const EvidenceStatus(this.wireName);

  /// The stored name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, EvidenceStatus> byWireName = {
    'unavailable': EvidenceStatus.unavailable,
    'captured': EvidenceStatus.captured,
  };
}

/// Why there is no evidence.
enum EvidenceGap {
  /// No Flutter camera plugin can record the seconds BEFORE an incident, which is what retrospective evidence needs.
  noRetroactiveCapture('noRetroactiveCapture');

  const EvidenceGap(this.wireName);

  /// The stored name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, EvidenceGap> byWireName = {'noRetroactiveCapture': EvidenceGap.noRetroactiveCapture};
}

/// The evidence for an incident: a real reference to a real recording, or a statement that there is none.
@immutable
final class Evidence {
  const Evidence._(this.status, this.reference, this.gap);

  /// No recording exists, for [gap].
  const Evidence.unavailable([EvidenceGap gap = EvidenceGap.noRetroactiveCapture])
    : this._(EvidenceStatus.unavailable, null, gap);

  /// A recording exists at [reference] (never a made-up value: the repository refuses an empty one).
  const Evidence.captured(String reference) : this._(EvidenceStatus.captured, reference, null);

  /// Reads evidence.
  factory Evidence.fromJson(JsonReader json) {
    final status = json.enumValue('status', EvidenceStatus.byWireName);
    switch (status) {
      case EvidenceStatus.unavailable:
        return Evidence.unavailable(json.enumValue('gap', EvidenceGap.byWireName));
      case EvidenceStatus.captured:
        return Evidence.captured(json.string('reference'));
    }
  }

  /// Whether a recording exists.
  final EvidenceStatus status;

  /// Where the recording is, when [status] is captured.
  final String? reference;

  /// Why there is none, when [status] is unavailable.
  final EvidenceGap? gap;

  /// The stored form.
  Map<String, Object?> toJson() => {'status': status.wireName, 'reference': reference, 'gap': gap?.wireName};
}

/// An instructor's decision about an incident, with their notes.
@immutable
final class IncidentDecision {
  /// Creates a decision.
  const IncidentDecision({required this.decision, required this.notes, required this.decidedAt});

  /// Reads a decision.
  factory IncidentDecision.fromJson(JsonReader json) => IncidentDecision(
    decision: json.enumValue('decision', ReviewDecision.byWireName),
    notes: json.string('notes'),
    decidedAt: json.dateTime('decidedAt'),
  );

  /// What was decided.
  final ReviewDecision decision;

  /// Why.
  final String notes;

  /// When.
  final DateTime decidedAt;

  /// The stored form.
  Map<String, Object?> toJson() => {
    'decision': decision.wireName,
    'notes': notes,
    'decidedAt': decidedAt.toUtc().toIso8601String(),
  };
}

/// Something that happened during an attempt that an instructor may want to look at.
///
/// An incident is a record of an observation, never a verdict, and it never changes a mark.
@immutable
final class Incident {
  /// Creates an incident.
  const Incident({
    required this.id,
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.ownerId,
    required this.studentName,
    required this.category,
    required this.severity,
    required this.source,
    required this.occurredAt,
    required this.evidence,
    required this.warningLimit,
    this.durationMs,
    this.detail,
    this.decision,
  });

  /// Reads an incident.
  factory Incident.fromJson(JsonReader json) => Incident(
    id: json.string('id'),
    attemptId: json.string('attemptId'),
    examId: json.string('examId'),
    examTitle: json.string('examTitle'),
    ownerId: json.string('ownerId'),
    studentName: json.string('studentName'),
    category: json.enumValue('category', IncidentCategory.byWireName),
    severity: json.enumValue('severity', IncidentSeverity.byWireName),
    source: json.enumValue('source', DetectionSource.byWireName),
    occurredAt: json.dateTime('occurredAt'),
    durationMs: json.optionalInteger('durationMs'),
    detail: json.optionalString('detail'),
    evidence: Evidence.fromJson(json.object('evidence')),
    warningLimit: json.integer('warningLimit'),
    decision: json.optionalObject('decision') == null ? null : IncidentDecision.fromJson(json.object('decision')),
  );

  /// A stable id.
  final String id;

  /// The attempt it happened in.
  final String attemptId;

  /// The exam.
  final String examId;

  /// The exam's title when it happened.
  final String examTitle;

  /// The instructor who owns the exam (the only one who may review it).
  final String ownerId;

  /// The student's name when it happened.
  final String studentName;

  /// What kind of incident.
  final IncidentCategory category;

  /// How serious.
  final IncidentSeverity severity;

  /// What noticed it.
  final DetectionSource source;

  /// When it happened.
  final DateTime occurredAt;

  /// How long it lasted, in milliseconds, when that is known.
  final int? durationMs;

  /// A short factual note ("left the app for 12 s").
  final String? detail;

  /// Whether there is a recording.
  final Evidence evidence;

  /// The exam's warning limit when it happened.
  final int warningLimit;

  /// What the instructor decided, if they have.
  final IncidentDecision? decision;

  /// A copy with a decision.
  Incident withDecision(IncidentDecision value) => Incident(
    id: id,
    attemptId: attemptId,
    examId: examId,
    examTitle: examTitle,
    ownerId: ownerId,
    studentName: studentName,
    category: category,
    severity: severity,
    source: source,
    occurredAt: occurredAt,
    durationMs: durationMs,
    detail: detail,
    evidence: evidence,
    warningLimit: warningLimit,
    decision: value,
  );

  /// The stored form.
  Map<String, Object?> toJson() => {
    'id': id,
    'attemptId': attemptId,
    'examId': examId,
    'examTitle': examTitle,
    'ownerId': ownerId,
    'studentName': studentName,
    'category': category.wireName,
    'severity': severity.wireName,
    'source': source.wireName,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'durationMs': durationMs,
    'detail': detail,
    'evidence': evidence.toJson(),
    'warningLimit': warningLimit,
    'decision': decision?.toJson(),
  };
}

/// What the player reports when something happens. The repository turns it into an [Incident].
@immutable
final class NewIncident {
  /// Creates the report.
  const NewIncident({
    required this.attemptId,
    required this.category,
    required this.occurredAt,
    this.durationMs,
    this.detail,
    this.evidenceStatus = EvidenceStatus.unavailable,
    this.evidenceReference,
  });

  /// The attempt.
  final String attemptId;

  /// What kind of incident.
  final IncidentCategory category;

  /// When it happened.
  final DateTime occurredAt;

  /// How long it lasted.
  final int? durationMs;

  /// A short factual note.
  final String? detail;

  /// Whether the reporter claims there is evidence. A claim of "captured" needs a real [evidenceReference].
  final EvidenceStatus evidenceStatus;

  /// Where the evidence is.
  final String? evidenceReference;
}

/// What the instructor's queue shows for an incident.
typedef IncidentSummary = Incident;
