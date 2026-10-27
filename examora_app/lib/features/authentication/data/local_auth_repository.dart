import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/security/password_hasher.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/auth_repository.dart';

/// Authentication against the accounts stored on this device.
final class LocalAuthRepository implements AuthRepository {
  /// Creates the repository.
  LocalAuthRepository({required this._accounts, required this._sessions, required this._hasher, required this._clock});

  /// Wrong passwords in a row that lock an account.
  static const int maxFailedAttempts = 5;

  /// How long a locked account stays locked.
  static const Duration lockoutDuration = Duration(minutes: 15);

  final LocalAccountStore _accounts;
  final LocalSessionStore _sessions;
  final PasswordHasher _hasher;
  final AppClock _clock;

  @override
  Future<Result<Account>> signIn({required String email, required String password}) async {
    final fields = <String, FieldProblem>{
      'email': ?Validators.email(email),
      'password': ?Validators.requiredPassword(password),
    };
    if (fields.isNotEmpty) return Err(ValidationFailure(fields: fields));

    try {
      final account = await _accounts.findByEmail(email);
      // An unknown email and a wrong password give the same answer, so this screen cannot be used to find out who has an
      // account.
      if (account == null) return const Err(InvalidCredentialsFailure());

      final now = _clock.now();
      if (account.isLockedAt(now)) return const Err(AccountLockedFailure());

      if (!await _hasher.verify(password, account.passwordHash)) {
        final attempts = account.failedAttempts + 1;
        final locks = attempts >= maxFailedAttempts;
        await _accounts.replace(
          account.copyWith(
            failedAttempts: locks ? 0 : attempts,
            lockoutUntil: locks ? Nullable(now.add(lockoutDuration)) : null,
          ),
        );
        return locks ? const Err(AccountLockedFailure()) : const Err(InvalidCredentialsFailure());
      }

      if (account.status == AccountStatus.deactivated) return const Err(AccountDeactivatedFailure());
      final expires = account.temporaryPasswordExpiresAt;
      if (account.mustChangePassword && expires != null && !expires.isAfter(now)) {
        return const Err(TemporaryPasswordExpiredFailure());
      }

      final signedIn = account.copyWith(
        failedAttempts: 0,
        lockoutUntil: const Nullable(null),
        lastLoginAt: Nullable(now),
      );
      await _accounts.replace(signedIn);
      await _sessions.write(StoredSession(accountId: account.id, expiresAt: now.add(LocalSessionStore.lifetime)));
      return Ok(signedIn.toAccount());
    } on Object {
      return const Err(StorageFailure());
    }
  }

  @override
  Future<Result<Account?>> restoreSession() async {
    try {
      final session = await _sessions.read();
      if (session == null) return const Ok(null);
      if (!session.expiresAt.isAfter(_clock.now())) {
        await _sessions.clear();
        return const Ok(null);
      }
      // Re-read the account, so a role or password change made elsewhere is reflected after a restart.
      final account = await _accounts.findById(session.accountId);
      if (account == null || account.status == AccountStatus.deactivated) {
        await _sessions.clear();
        return const Ok(null);
      }
      return Ok(account.toAccount());
    } on Object {
      return const Err(StorageFailure());
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _sessions.clear();
    } on Object {
      // Signing out always succeeds locally; a storage problem must not trap the user.
    }
  }

  @override
  Future<Result<Account>> changePassword({required String currentPassword, required String newPassword}) async {
    final fields = <String, FieldProblem>{
      'currentPassword': ?Validators.requiredPassword(currentPassword),
      'newPassword': ?Validators.newPassword(newPassword),
    };
    if (fields.isNotEmpty) return Err(ValidationFailure(fields: fields));

    try {
      final session = await _sessions.read();
      if (session == null || !session.expiresAt.isAfter(_clock.now())) return const Err(SessionExpiredFailure());
      final account = await _accounts.findById(session.accountId);
      if (account == null) return const Err(SessionExpiredFailure());

      if (!await _hasher.verify(currentPassword, account.passwordHash)) {
        return const Err(
          ValidationFailure(fields: {'currentPassword': KnownFieldProblem(FieldReason.currentPasswordIncorrect)}),
        );
      }
      if (currentPassword == newPassword) {
        return const Err(
          ValidationFailure(fields: {'newPassword': KnownFieldProblem(FieldReason.newPasswordSameAsCurrent)}),
        );
      }

      final updated = account.copyWith(
        passwordHash: await _hasher.hash(newPassword),
        mustChangePassword: false,
        temporaryPasswordExpiresAt: const Nullable(null),
      );
      await _accounts.replace(updated);
      return Ok(updated.toAccount());
    } on Object {
      return const Err(StorageFailure());
    }
  }
}
