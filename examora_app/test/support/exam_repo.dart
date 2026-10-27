import 'package:examora_app/core/storage/json_collection_store.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_caller.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/exams/data/local_exam_repository.dart';
import 'package:examora_app/features/exams/domain/exam.dart';

import 'test_harness.dart';

/// An exam repository over the same stored data the app will read, for preparing a test before the app starts. The
/// caller must already be signed in (see `startSignedIn`).
LocalExamRepository examRepositoryFor(TestEnvironment env) => LocalExamRepository(
  exams: JsonCollectionStore<Exam>(
    store: env.keyValueStore,
    key: 'local.exams.v1',
    fromJson: Exam.fromJson,
    toJson: (exam) => exam.toJson(),
  ),
  caller: LocalCaller(
    accounts: LocalAccountStore(store: env.keyValueStore, hasher: TestEnvironment.fastHasher, clock: env.clock),
    sessions: LocalSessionStore(env.secureStore),
    clock: env.clock,
  ),
  clock: env.clock,
);
