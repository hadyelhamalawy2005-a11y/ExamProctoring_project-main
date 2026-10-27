import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/authentication/domain/account.dart';

/// Everything the app does about signing in and out. Screens and controllers depend only on this interface and never
/// know whether the answer came from the device or from a server.
abstract interface class AuthRepository {
  /// Signs in. A wrong password and an unknown email produce the same failure.
  Future<Result<Account>> signIn({required String email, required String password});

  /// The signed-in account, re-read so a change made elsewhere is reflected, or null when there is no valid session.
  /// A session whose account no longer exists is cleared.
  Future<Result<Account?>> restoreSession();

  /// Ends the session. Always succeeds locally: the user asked to leave, and a failure elsewhere must not trap them.
  Future<void> signOut();

  /// Changes the signed-in account's password and clears a pending forced change.
  Future<Result<Account>> changePassword({required String currentPassword, required String newPassword});
}
