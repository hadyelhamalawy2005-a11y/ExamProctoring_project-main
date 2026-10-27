import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/features/exam_session/data/consent_record.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every student's attempts, stored on this device.
final localAttemptStoreProvider = Provider<JsonCollectionStore<Attempt>>(
  (ref) => JsonCollectionStore<Attempt>(
    store: ref.watch(keyValueStoreProvider),
    key: 'local.attempts.v1',
    fromJson: Attempt.fromJson,
    toJson: (attempt) => attempt.toJson(),
  ),
);

/// Who accepted the proctoring notice for which exam.
final localConsentStoreProvider = Provider<JsonCollectionStore<ConsentRecord>>(
  (ref) => JsonCollectionStore<ConsentRecord>(
    store: ref.watch(keyValueStoreProvider),
    key: 'local.consents.v1',
    fromJson: ConsentRecord.fromJson,
    toJson: (record) => record.toJson(),
  ),
);

/// Every incident, stored on this device.
final localIncidentStoreProvider = Provider<JsonCollectionStore<Incident>>(
  (ref) => JsonCollectionStore<Incident>(
    store: ref.watch(keyValueStoreProvider),
    key: 'local.incidents.v1',
    fromJson: Incident.fromJson,
    toJson: (incident) => incident.toJson(),
  ),
);
