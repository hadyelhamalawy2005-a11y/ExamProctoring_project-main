import 'package:examora_app/core/network/missing_endpoints.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_repositories.dart';

/// Reporting incidents to the Examora API. The API has no incident model, so this REFUSES, naming the endpoint, and sends
/// nothing. It never falls back to the incidents stored on the device.
final class ApiIncidentRecorder implements IncidentRecorder {
  /// Creates the recorder.
  const ApiIncidentRecorder();

  @override
  Future<Result<Incident>> record(NewIncident incident) async => MissingEndpoints.recordIncident.refuse();
}

/// Reviewing incidents on the Examora API. Every call refuses by name.
final class ApiIncidentReviewRepository implements IncidentReviewRepository {
  /// Creates the repository.
  const ApiIncidentReviewRepository();

  @override
  Future<Result<List<IncidentSummary>>> listQueue({bool? decided}) async => MissingEndpoints.incidentQueue.refuse();

  @override
  Future<Result<IncidentDetail>> getIncident(String incidentId) async => MissingEndpoints.incidentDetail.refuse();

  @override
  Future<Result<Incident>> decide(String incidentId, ReviewDecision decision, String notes) async =>
      MissingEndpoints.incidentDecision.refuse();
}
