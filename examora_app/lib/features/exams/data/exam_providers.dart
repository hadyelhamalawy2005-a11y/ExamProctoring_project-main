import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/configuration/data_source.dart';
import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/features/authentication/data/auth_providers.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/exam_session/data/local_stores.dart';
import 'package:examora_app/features/exams/data/api_exam_repository.dart';
import 'package:examora_app/features/exams/data/local_exam_repository.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:examora_app/features/exams/domain/exam_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who is calling, read from the stored session (used by every local repository).
final localCallerProvider = Provider<LocalCaller>(
  (ref) => LocalCaller(
    accounts: ref.watch(localAccountStoreProvider),
    sessions: ref.watch(localSessionStoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// The exams stored on this device.
final localExamStoreProvider = Provider<JsonCollectionStore<Exam>>(
  (ref) => JsonCollectionStore<Exam>(
    store: ref.watch(keyValueStoreProvider),
    key: 'local.exams.v1',
    fromJson: Exam.fromJson,
    toJson: (exam) => exam.toJson(),
  ),
);

/// The one provider that decides where an instructor's exams come from.
final examRepositoryProvider = Provider<ExamRepository>(
  (ref) => switch (ref.watch(dataSourceProvider)) {
    DataSource.local => LocalExamRepository(
      exams: ref.watch(localExamStoreProvider),
      caller: ref.watch(localCallerProvider),
      clock: ref.watch(clockProvider),
      // An exam that already has an attempt can no longer be taken back to a draft.
      hasAttempts: (examId) async {
        final attempts = await ref.read(localAttemptStoreProvider).all();
        return attempts.any((attempt) => attempt.exam.id == examId);
      },
    ),
    DataSource.api => ApiExamRepository(client: ref.watch(apiClientProvider)),
  },
);
