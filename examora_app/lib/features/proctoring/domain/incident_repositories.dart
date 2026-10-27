import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:meta/meta.dart';

/// Where the player reports incidents. It can only WRITE: there is deliberately no way for a student to read incidents back,
/// so a student cannot review (or tidy) their own record.
abstract interface class IncidentRecorder {
  /// Records an incident for the signed-in student's own, still open attempt, if its category is one of the exam's active
  /// rules. "Captured" evidence without a real reference is refused.
  Future<Result<Incident>> record(NewIncident incident);
}

/// One incident with everything around it.
@immutable
final class IncidentDetail {
  /// Creates the detail.
  const IncidentDetail({required this.incident, required this.timeline});

  /// The incident.
  final Incident incident;

  /// Every incident of the same attempt in time order (this one included), so it can be read in context.
  final List<Incident> timeline;

  /// How many incidents the attempt has (each counts as one warning).
  int get warnings => timeline.length;

  /// True when the attempt reached the exam's warning limit.
  bool get limitReached => warnings >= incident.warningLimit;
}

/// An instructor's review of the incidents at their own exams. Another instructor's exam, and a student, get nothing.
abstract interface class IncidentReviewRepository {
  /// The incidents at the instructor's exams, newest first. [decided] limits the list to those with a decision (true) or
  /// without (false); null lists all.
  Future<Result<List<IncidentSummary>>> listQueue({bool? decided});

  /// One incident with its timeline.
  Future<Result<IncidentDetail>> getIncident(String incidentId);

  /// Records the decision (and replaces an earlier one).
  Future<Result<Incident>> decide(String incidentId, ReviewDecision decision, String notes);
}
