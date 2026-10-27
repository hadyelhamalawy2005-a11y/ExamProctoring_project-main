import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/administration/data/admin_providers.dart';
import 'package:examora_app/features/administration/domain/admin_repository.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the account list shows: the filters and the page. A record, so two equal queries share one cached result.
typedef AccountQuery = ({UserRole? role, AccountStatus? status, int page});

/// One page of accounts for [AccountQuery]. Invalidate it after any change so the list shows the new truth.
final accountListProvider = FutureProvider.autoDispose.family<Result<AccountPage>, AccountQuery>(
  (ref, query) => ref
      .watch(adminRepositoryProvider)
      .listAccounts(
        role: query.role,
        status: query.status,
        page: query.page,
        pageSize: AdminRepository.defaultPageSize,
      ),
);

/// One account by id.
final accountDetailProvider = FutureProvider.autoDispose.family<Result<ManagedAccount>, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).getAccount(id),
);

/// Opens an address in another app (the email draft). Replaceable in tests; returns false when nothing could handle it.
final uriLauncherProvider = Provider<Future<bool> Function(Uri uri)>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri);
    } on Object {
      return false;
    }
  },
);
