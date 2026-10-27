import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_repositories.dart';
import 'package:uuid/uuid.dart';

/// Records incidents for the signed-in student's own, still open attempt.
///
/// It only writes. The category must be one of the exam's active rules (and one this build can notice), a claim of
/// "captured" evidence needs a real reference, and an incident is a record only: nothing here touches a mark.
final class LocalIncidentRecorder implements IncidentRecorder {
  /// Creates the recorder.
  LocalIncidentRecorder({
    required this._attempts,
    required this._incidents,
    required this._caller,
    this._uuid = const Uuid(),
  });

  final JsonCollectionStore<Attempt> _attempts;
  final JsonCollectionStore<Incident> _incidents;
  final LocalCaller _caller;
  final Uuid _uuid;

  @override
  Future<Result<Incident>> record(NewIncident report) async {
    try {
      final caller = await _caller.currentWithRole(UserRole.student);
      switch (caller) {
        case Err<StoredAccount>(:final failure):
          return Err(failure);
        case Ok<StoredAccount>(:final value):
          return await _record(value, report);
      }
    } on Object {
      return const Err(StorageFailure());
    }
  }

  Future<Result<Incident>> _record(StoredAccount student, NewIncident report) async {
    // Evidence is a real reference or a stated gap, never a made-up clip.
    if (report.evidenceStatus == EvidenceStatus.captured && (report.evidenceReference?.trim().isEmpty ?? true)) {
      return const Err(ValidationFailure(fields: {'evidence': KnownFieldProblem(FieldReason.required)}));
    }

    Attempt? attempt;
    for (final candidate in await _attempts.all()) {
      if (candidate.id == report.attemptId && candidate.studentId == student.id) attempt = candidate;
    }
    if (attempt == null) return const Err(NotFoundFailure());
    if (attempt.status != AttemptStatus.inProgress) {
      return const Err(ConflictFailure(code: 'attempt_already_submitted'));
    }
    final settings = attempt.exam.settings;
    if (!settings.enabledRules.contains(report.category) || !report.category.hasDetector) {
      return const Err(ConflictFailure(code: 'rule_not_enabled'));
    }

    final incident = Incident(
      id: _uuid.v4(),
      attemptId: attempt.id,
      examId: attempt.exam.id,
      examTitle: attempt.exam.title,
      ownerId: attempt.exam.ownerId,
      studentName: attempt.studentName,
      category: report.category,
      severity: report.category.defaultSeverity,
      source: report.category.source,
      occurredAt: report.occurredAt.toUtc(),
      durationMs: report.durationMs,
      detail: report.detail,
      evidence: report.evidenceStatus == EvidenceStatus.captured
          ? Evidence.captured(report.evidenceReference!.trim())
          : const Evidence.unavailable(),
      warningLimit: settings.maxWarnings,
    );
    await _incidents.mutate<void>((all) => all.add(incident));
    return Ok(incident);
  }
}

/// An instructor's review of the incidents at the exams they own.
final class LocalIncidentReviewRepository implements IncidentReviewRepository {
  /// Creates the repository.
  LocalIncidentReviewRepository({required this._incidents, required this._caller, required this._clock});

  final JsonCollectionStore<Incident> _incidents;
  final LocalCaller _caller;
  final AppClock _clock;

  @override
  Future<Result<List<IncidentSummary>>> listQueue({bool? decided}) => _guarded((instructor) async {
    final mine = [
      for (final incident in await _incidents.all())
        if (incident.ownerId == instructor.id && (decided == null || (incident.decision != null) == decided)) incident,
    ]..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return Ok(mine);
  });

  @override
  Future<Result<IncidentDetail>> getIncident(String incidentId) => _guarded((instructor) async {
    final all = await _incidents.all();
    for (final incident in all) {
      if (incident.id == incidentId && incident.ownerId == instructor.id) {
        final timeline = [
          for (final other in all)
            if (other.attemptId == incident.attemptId) other,
        ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
        return Ok(IncidentDetail(incident: incident, timeline: timeline));
      }
    }
    return const Err(NotFoundFailure());
  });

  @override
  Future<Result<Incident>> decide(String incidentId, ReviewDecision decision, String notes) =>
      _guarded((instructor) async {
        final trimmed = notes.trim();
        if (trimmed.length > Validators.statusReasonMaxLength) {
          return const Err(ValidationFailure(fields: {'notes': KnownFieldProblem(FieldReason.tooLong)}));
        }
        final now = _clock.now();
        return _incidents.mutate<Result<Incident>>((all) {
          final index = all.indexWhere((i) => i.id == incidentId && i.ownerId == instructor.id);
          if (index < 0) return const Err(NotFoundFailure());
          final updated = all[index].withDecision(IncidentDecision(decision: decision, notes: trimmed, decidedAt: now));
          all[index] = updated;
          return Ok(updated);
        });
      });

  Future<Result<T>> _guarded<T>(Future<Result<T>> Function(StoredAccount instructor) action) async {
    try {
      final caller = await _caller.currentWithRole(UserRole.instructor);
      switch (caller) {
        case Err<StoredAccount>(:final failure):
          return Err<T>(failure);
        case Ok<StoredAccount>(:final value):
          return await action(value);
      }
    } on Object {
      return Err<T>(const StorageFailure());
    }
  }
}
