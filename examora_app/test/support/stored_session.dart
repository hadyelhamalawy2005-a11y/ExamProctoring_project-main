import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_auth_repository.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';

import 'test_harness.dart';

/// Signs a seeded account in directly through the repository, so the next app launch starts with a stored session.
Future<void> startSignedIn(TestEnvironment env, String email, {String password = 'Examora#2026'}) async {
  final repository = LocalAuthRepository(
    accounts: LocalAccountStore(store: env.keyValueStore, hasher: TestEnvironment.fastHasher, clock: env.clock),
    sessions: LocalSessionStore(env.secureStore),
    hasher: TestEnvironment.fastHasher,
    clock: env.clock,
  );
  final result = await repository.signIn(email: email, password: password);
  if (result.isErr) {
    throw StateError('Could not start signed in as $email: ${result.failureOrNull}');
  }
}

/// Edits an account in the stored list (for example to force a password change) before the app starts.
Future<void> editStoredAccount(
  TestEnvironment env,
  String email,
  StoredAccount Function(StoredAccount account) change,
) async {
  final accounts = LocalAccountStore(store: env.keyValueStore, hasher: TestEnvironment.fastHasher, clock: env.clock);
  final account = (await accounts.findByEmail(email))!;
  await accounts.replace(change(account));
}
