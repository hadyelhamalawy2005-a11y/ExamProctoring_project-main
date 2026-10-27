import 'dart:math';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/security/password_hasher.dart';
import 'package:examora_app/core/security/temporary_password.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/administration/domain/admin_repository.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:uuid/uuid.dart';

/// Account administration over the accounts stored on this device.
///
/// Mirrors the server's rules: administrators are never listed or changed, a temporary password lasts 72 hours and forces
/// a change at sign-in, a deactivation needs a reason, and asking for the status an account already has is a conflict.
/// Every call checks that the stored session belongs to an administrator, so a student or instructor can never use it even
/// if a screen were reachable by mistake.
final class LocalAdminRepository implements AdminRepository {
  /// Creates the repository. [random] is for tests; it defaults to a secure generator.
  LocalAdminRepository({
    required this._accounts,
    required this._sessions,
    required this._hasher,
    required this._clock,
    this._random,
    this._uuid = const Uuid(),
  });

  final LocalAccountStore _accounts;
  final LocalSessionStore _sessions;
  final PasswordHasher _hasher;
  final AppClock _clock;
  final Random? _random;
  final Uuid _uuid;

  @override
  Future<Result<AccountPage>> listAccounts({
    UserRole? role,
    AccountStatus? status,
    int page = 1,
    int pageSize = AdminRepository.defaultPageSize,
  }) => _guarded(() async {
    if (role == UserRole.administrator) {
      // Administrators are never listed (the server refuses the filter too).
      return const Err(ValidationFailure(fields: {'role': ServerFieldProblem('Role must be Student or Instructor.')}));
    }
    if (page < 1 || pageSize < 1 || pageSize > AdminRepository.maxPageSize) {
      return const Err(ValidationFailure(fields: {'page': ServerFieldProblem('Page or page size is out of range.')}));
    }
    final now = _clock.now();
    final matching = [
      for (final account in await _accounts.all())
        if (account.role != UserRole.administrator &&
            (role == null || account.role == role) &&
            (status == null || account.status == status))
          account,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final start = (page - 1) * pageSize;
    final slice = start >= matching.length ? <StoredAccount>[] : matching.skip(start).take(pageSize).toList();
    return Ok(
      AccountPage(
        items: [for (final account in slice) _view(account, now)],
        page: page,
        pageSize: pageSize,
        totalCount: matching.length,
      ),
    );
  });

  @override
  Future<Result<ManagedAccount>> getAccount(String id) => _guarded(() async {
    final account = await _accounts.findById(id);
    if (account == null || account.role == UserRole.administrator) return const Err(NotFoundFailure());
    return Ok(_view(account, _clock.now()));
  });

  @override
  Future<Result<IssuedPassword>> createAccount({
    required UserRole role,
    required String fullName,
    required String email,
  }) => _guarded(() async {
    if (role == UserRole.administrator) {
      return const Err(ForbiddenFailure(message: 'Administrator accounts cannot be created here.'));
    }
    final fields = <String, FieldProblem>{
      'fullName': ?Validators.fullName(fullName),
      'email': ?Validators.email(email),
    };
    if (fields.isNotEmpty) return Err(ValidationFailure(fields: fields));

    final normalizedEmail = Validators.normalizeEmail(email);
    final password = TemporaryPassword.generate(_random);
    final hash = await _hasher.hash(password);
    final now = _clock.now();
    final expiresAt = now.add(TemporaryPassword.validity);

    final created = await _accounts.mutate<bool>((accounts) {
      if (accounts.any((account) => account.email == normalizedEmail)) return false;
      accounts.add(
        StoredAccount(
          id: _uuid.v4(),
          fullName: fullName.trim(),
          email: normalizedEmail,
          role: role,
          passwordHash: hash,
          mustChangePassword: true,
          temporaryPasswordExpiresAt: expiresAt,
          status: AccountStatus.active,
          createdAt: now,
        ),
      );
      return true;
    });
    if (!created) return const Err(ConflictFailure(code: 'duplicate_account'));
    return Ok(
      IssuedPassword(
        email: normalizedEmail,
        fullName: fullName.trim(),
        temporaryPassword: password,
        expiresAt: expiresAt,
      ),
    );
  });

  @override
  Future<Result<IssuedPassword>> issueTemporaryPassword(String accountId) => _guarded(() async {
    final password = TemporaryPassword.generate(_random);
    final hash = await _hasher.hash(password);
    final expiresAt = _clock.now().add(TemporaryPassword.validity);

    final target = await _accounts.mutate<StoredAccount?>((accounts) {
      final index = accounts.indexWhere((a) => a.id == accountId && a.role != UserRole.administrator);
      if (index < 0) return null;
      final updated = accounts[index].copyWith(
        passwordHash: hash,
        mustChangePassword: true,
        temporaryPasswordExpiresAt: Nullable(expiresAt),
        // A new password is a fresh start: any earlier lock no longer applies.
        failedAttempts: 0,
        lockoutUntil: const Nullable(null),
      );
      accounts[index] = updated;
      return updated;
    });
    if (target == null) return const Err(NotFoundFailure());
    return Ok(
      IssuedPassword(email: target.email, fullName: target.fullName, temporaryPassword: password, expiresAt: expiresAt),
    );
  });

  @override
  Future<Result<ManagedAccount>> deactivate(String accountId, {required String reason}) {
    final problem = Validators.statusReason(reason, required: true);
    if (problem != null) {
      return Future.value(Err(ValidationFailure(fields: {'reason': problem})));
    }
    return _changeStatus(accountId, AccountStatus.deactivated, reason.trim());
  }

  @override
  Future<Result<ManagedAccount>> reactivate(String accountId, {String? reason}) {
    final problem = Validators.statusReason(reason ?? '', required: false);
    if (problem != null) {
      return Future.value(Err(ValidationFailure(fields: {'reason': problem})));
    }
    final trimmed = reason?.trim();
    return _changeStatus(accountId, AccountStatus.active, trimmed == null || trimmed.isEmpty ? null : trimmed);
  }

  Future<Result<ManagedAccount>> _changeStatus(String accountId, AccountStatus wanted, String? reason) =>
      _guarded(() async {
        final now = _clock.now();
        final outcome = await _accounts.mutate<Result<StoredAccount>>((accounts) {
          final index = accounts.indexWhere((a) => a.id == accountId && a.role != UserRole.administrator);
          if (index < 0) return const Err(NotFoundFailure());
          final current = accounts[index];
          if (current.status == wanted) {
            return Err(
              ConflictFailure(
                code: wanted == AccountStatus.deactivated ? 'account_already_deactivated' : 'account_already_active',
              ),
            );
          }
          final updated = current.copyWith(
            status: wanted,
            statusReason: Nullable(reason),
            statusChangedAt: Nullable(now),
          );
          accounts[index] = updated;
          return Ok(updated);
        });
        switch (outcome) {
          case Ok<StoredAccount>(:final value):
            return Ok(_view(value, now));
          case Err<StoredAccount>(:final failure):
            return Err(failure);
        }
      });

  ManagedAccount _view(StoredAccount account, DateTime now) => ManagedAccount(
    id: account.id,
    fullName: account.fullName,
    email: account.email,
    role: account.role,
    status: account.status,
    mustChangePassword: account.mustChangePassword,
    temporaryPasswordExpiresAt: account.temporaryPasswordExpiresAt,
    isLockedOut: account.isLockedAt(now),
    createdAt: account.createdAt,
    lastLoginAt: account.lastLoginAt,
    statusChangedAt: account.statusChangedAt,
    statusReason: account.statusReason,
  );

  /// Runs [action] only for a signed-in administrator, and turns a storage error into [StorageFailure].
  Future<Result<T>> _guarded<T>(Future<Result<T>> Function() action) async {
    try {
      final session = await _sessions.read();
      if (session == null || !session.expiresAt.isAfter(_clock.now())) return const Err(SessionExpiredFailure());
      final caller = await _accounts.findById(session.accountId);
      if (caller == null || caller.status == AccountStatus.deactivated) return const Err(SessionExpiredFailure());
      if (caller.role != UserRole.administrator) return const Err(ForbiddenFailure());
      return await action();
    } on Object {
      return const Err(StorageFailure());
    }
  }
}
