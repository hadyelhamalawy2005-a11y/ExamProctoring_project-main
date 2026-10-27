import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';

/// Account administration. Only an administrator may use it, and administrators are never listed, created, deactivated or
/// reset through it.
abstract interface class AdminRepository {
  /// The default page size (the server's default).
  static const int defaultPageSize = 20;

  /// The largest page size the server accepts.
  static const int maxPageSize = 100;

  /// Lists students and instructors, newest first, optionally filtered by [role] (student or instructor) and [status].
  Future<Result<AccountPage>> listAccounts({
    UserRole? role,
    AccountStatus? status,
    int page = 1,
    int pageSize = defaultPageSize,
  });

  /// One account.
  Future<Result<ManagedAccount>> getAccount(String id);

  /// Creates a student or instructor with a temporary password the person must change at first sign-in. The password is
  /// returned once.
  Future<Result<IssuedPassword>> createAccount({
    required UserRole role,
    required String fullName,
    required String email,
  });

  /// Replaces the password with a new temporary one (valid for 72 hours, must be changed at sign-in). Returned once.
  Future<Result<IssuedPassword>> issueTemporaryPassword(String accountId);

  /// Stops the account signing in. A [reason] of 1 to 500 characters is required.
  Future<Result<ManagedAccount>> deactivate(String accountId, {required String reason});

  /// Lets the account sign in again. The [reason] is optional.
  Future<Result<ManagedAccount>> reactivate(String accountId, {String? reason});
}
