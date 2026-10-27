import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/configuration/data_source.dart';
import 'package:examora_app/features/authentication/data/api_auth_repository.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_auth_repository.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/domain/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The device's list of accounts (shared by sign-in and administration).
final localAccountStoreProvider = Provider<LocalAccountStore>(
  (ref) => LocalAccountStore(
    store: ref.watch(keyValueStoreProvider),
    hasher: ref.watch(passwordHasherProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// The device's stored session.
final localSessionStoreProvider = Provider<LocalSessionStore>(
  (ref) => LocalSessionStore(ref.watch(secureStoreProvider)),
);

/// The one provider that decides where authentication data comes from.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => switch (ref.watch(dataSourceProvider)) {
    DataSource.local => LocalAuthRepository(
      accounts: ref.watch(localAccountStoreProvider),
      sessions: ref.watch(localSessionStoreProvider),
      hasher: ref.watch(passwordHasherProvider),
      clock: ref.watch(clockProvider),
    ),
    DataSource.api => ApiAuthRepository(client: ref.watch(apiClientProvider), tokens: ref.watch(apiTokenStoreProvider)),
  },
);
