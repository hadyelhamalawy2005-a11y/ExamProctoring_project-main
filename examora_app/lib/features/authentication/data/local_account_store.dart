import 'dart:async';
import 'dart:convert';

import 'package:examora_app/core/security/password_hasher.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:uuid/uuid.dart';

/// One of the three accounts every fresh install starts with.
final class SeedAccount {
  /// Creates a seed account description.
  const SeedAccount({required this.email, required this.password, required this.fullName, required this.role});

  /// The sign-in email.
  final String email;

  /// The starting password. Only its salted hash is ever stored.
  final String password;

  /// The person's name.
  final String fullName;

  /// The role.
  final UserRole role;
}

/// The accounts created on first launch (see the specification). Added only when missing, so an account whose password
/// has since been changed is never touched.
const List<SeedAccount> seedAccounts = [
  SeedAccount(email: 'student@examora.app', password: 'Examora#2026', fullName: 'Malk Mostafa', role: UserRole.student),
  SeedAccount(
    email: 'instructor@examora.app',
    password: 'Examora#2026',
    fullName: 'Ahmed Zahran',
    role: UserRole.instructor,
  ),
  SeedAccount(
    email: 'admin@examora.app',
    password: 'Examora#2026',
    fullName: 'Mohamed Hatem',
    role: UserRole.administrator,
  ),
];

/// The device's list of accounts: the only place accounts exist while the app runs standalone.
///
/// Shared by sign-in and by administration, and every change runs one at a time, so two operations can never overwrite
/// each other's write.
final class LocalAccountStore {
  /// Creates the store.
  LocalAccountStore({required this._store, required this._hasher, required this._clock, this._uuid = const Uuid()});

  static const String _key = 'local.accounts.v1';

  final KeyValueStore _store;
  final PasswordHasher _hasher;
  final AppClock _clock;
  final Uuid _uuid;

  Future<void> _tail = Future<void>.value();
  Future<void>? _seeding;

  /// Creates the seed accounts that are missing. Safe to call any number of times; a failed attempt is retried by the
  /// next call.
  Future<void> ensureSeeded() => _seeding ??= _seed().then<void>(
    (_) {},
    onError: (Object error, StackTrace stack) {
      _seeding = null;
      Error.throwWithStackTrace(error, stack);
    },
  );

  Future<void> _seed() async {
    final existing = await _load();
    final missing = [
      for (final seed in seedAccounts)
        if (!existing.any((account) => account.email == seed.email)) seed,
    ];
    if (missing.isEmpty) return;

    // Hashed in parallel: each hash runs in its own isolate.
    final hashes = await Future.wait([for (final seed in missing) _hasher.hash(seed.password)]);
    final now = _clock.now();
    await _synchronized(() async {
      final current = await _load();
      var changed = false;
      for (var index = 0; index < missing.length; index++) {
        final seed = missing[index];
        if (current.any((account) => account.email == seed.email)) continue;
        current.add(
          StoredAccount(
            id: _uuid.v4(),
            fullName: seed.fullName,
            email: seed.email,
            role: seed.role,
            passwordHash: hashes[index],
            mustChangePassword: false,
            status: AccountStatus.active,
            createdAt: now,
          ),
        );
        changed = true;
      }
      if (changed) await _save(current);
    });
  }

  /// All accounts, in the order they were created.
  Future<List<StoredAccount>> all() async {
    await ensureSeeded();
    return _synchronized(_load);
  }

  /// The account with [email] (compared trimmed and case-insensitively), or null.
  Future<StoredAccount?> findByEmail(String email) async {
    final wanted = Validators.normalizeEmail(email);
    final accounts = await all();
    for (final account in accounts) {
      if (account.email == wanted) return account;
    }
    return null;
  }

  /// The account with [id], or null.
  Future<StoredAccount?> findById(String id) async {
    final accounts = await all();
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// Runs [change] over the list while no other change can run, then saves the list. What [change] returns is passed
  /// back. If [change] throws, nothing is saved. [change] must not call back into this store (it would wait for itself).
  Future<T> mutate<T>(FutureOr<T> Function(List<StoredAccount> accounts) change) async {
    await ensureSeeded();
    return _synchronized(() async {
      final accounts = await _load();
      final result = await change(accounts);
      await _save(accounts);
      return result;
    });
  }

  /// Replaces the account with the same id. Returns false when it no longer exists.
  Future<bool> replace(StoredAccount updated) => mutate((accounts) {
    final index = accounts.indexWhere((account) => account.id == updated.id);
    if (index < 0) return false;
    accounts[index] = updated;
    return true;
  });

  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<List<StoredAccount>> _load() async {
    final text = await _store.read(_key);
    if (text == null) return [];
    final decoded = jsonDecode(text);
    if (decoded is! List) throw const JsonParseException('(accounts)', 'must be a list');
    return [
      for (var index = 0; index < decoded.length; index++)
        StoredAccount.fromJson(JsonReader.of(decoded[index], '(accounts)[$index]')),
    ];
  }

  Future<void> _save(List<StoredAccount> accounts) =>
      _store.write(_key, jsonEncode([for (final account in accounts) account.toJson()]));
}
