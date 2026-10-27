import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/configuration/data_source.dart';
import 'package:examora_app/features/administration/data/api_admin_repository.dart';
import 'package:examora_app/features/administration/data/local_admin_repository.dart';
import 'package:examora_app/features/administration/domain/admin_repository.dart';
import 'package:examora_app/features/authentication/data/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one provider that decides where account administration data comes from.
final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => switch (ref.watch(dataSourceProvider)) {
    DataSource.local => LocalAdminRepository(
      accounts: ref.watch(localAccountStoreProvider),
      sessions: ref.watch(localSessionStoreProvider),
      hasher: ref.watch(passwordHasherProvider),
      clock: ref.watch(clockProvider),
    ),
    DataSource.api => ApiAdminRepository(client: ref.watch(apiClientProvider)),
  },
);
