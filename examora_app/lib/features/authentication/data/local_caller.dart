import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';

/// Who is making a call, read from the stored session on this device.
///
/// Every local repository asks this before doing anything, so a screen reached by mistake (or a deep link the router
/// should have stopped) still cannot act as another role.
final class LocalCaller {
  /// Creates the resolver.
  const LocalCaller({required this._accounts, required this._sessions, required this._clock});

  final LocalAccountStore _accounts;
  final LocalSessionStore _sessions;
  final AppClock _clock;

  /// The signed-in account, or [SessionExpiredFailure] when there is no live session or the account is gone or
  /// deactivated.
  Future<Result<StoredAccount>> current() async {
    final session = await _sessions.read();
    if (session == null || !session.expiresAt.isAfter(_clock.now())) return const Err(SessionExpiredFailure());
    final account = await _accounts.findById(session.accountId);
    if (account == null || account.status == AccountStatus.deactivated) return const Err(SessionExpiredFailure());
    return Ok(account);
  }

  /// The signed-in account when it has [role], otherwise [ForbiddenFailure] (or the session failure).
  Future<Result<StoredAccount>> currentWithRole(UserRole role) async {
    final result = await current();
    switch (result) {
      case Err<StoredAccount>():
        return result;
      case Ok<StoredAccount>(:final value):
        return value.role == role ? result : const Err(ForbiddenFailure());
    }
  }
}
