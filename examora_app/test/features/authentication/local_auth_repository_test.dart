import 'dart:convert';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_auth_repository.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/data/stored_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

/// A key-value store that fails on demand, to prove errors are reported and never trap the user.
final class FailingKeyValueStore extends InMemoryKeyValueStore {
  bool failReads = false;
  bool failWrites = false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('disk read failed');
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('disk write failed');
    return super.write(key, value);
  }
}

final class FailingSecureStore extends InMemorySecureStore {
  bool failDelete = false;

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('keystore unavailable');
    return super.delete(key);
  }
}

void main() {
  late TestEnvironment env;
  late LocalAccountStore accounts;
  late LocalSessionStore sessions;
  late LocalAuthRepository repository;

  void build({InMemoryKeyValueStore? store, InMemorySecureStore? secure}) {
    final keyValue = store ?? env.keyValueStore;
    final secureStore = secure ?? env.secureStore;
    accounts = LocalAccountStore(store: keyValue, hasher: TestEnvironment.fastHasher, clock: env.clock);
    sessions = LocalSessionStore(secureStore);
    repository = LocalAuthRepository(
      accounts: accounts,
      sessions: sessions,
      hasher: TestEnvironment.fastHasher,
      clock: env.clock,
    );
  }

  setUp(() {
    env = TestEnvironment();
    build();
  });

  group('seeding', () {
    test('creates exactly the three accounts of the specification', () async {
      final all = await accounts.all();
      expect(all.map((a) => (a.email, a.fullName, a.role)), [
        ('student@examora.app', 'Malk Mostafa', UserRole.student),
        ('instructor@examora.app', 'Ahmed Zahran', UserRole.instructor),
        ('admin@examora.app', 'Mohamed Hatem', UserRole.administrator),
      ]);
      expect(all.every((a) => a.status == AccountStatus.active && !a.mustChangePassword), isTrue);
    });

    test('stores only a salted hash, never the password', () async {
      await accounts.all();
      final stored = env.keyValueStore.values['local.accounts.v1']!;
      expect(stored, isNot(contains('Examora#2026')));
      for (final account in await accounts.all()) {
        expect(account.passwordHash, startsWith('pbkdf2-sha256\$'));
      }
      // Two accounts with the same password have different hashes: the salt is per account.
      final hashes = (await accounts.all()).map((a) => a.passwordHash).toSet();
      expect(hashes, hasLength(3));
    });

    test('is idempotent: seeding again creates nothing and changes nothing', () async {
      final first = jsonEncode((await accounts.all()).map((a) => a.toJson()).toList());
      build(); // a fresh start of the app over the same storage
      final second = jsonEncode((await accounts.all()).map((a) => a.toJson()).toList());
      expect(second, first);
    });

    test('never overwrites an account whose password has since been changed', () async {
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      await repository.changePassword(currentPassword: 'Examora#2026', newPassword: 'Changed#2027');

      build(); // restart

      expect(
        (await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).failureOrNull,
        isA<InvalidCredentialsFailure>(),
      );
      expect((await repository.signIn(email: 'student@examora.app', password: 'Changed#2027')).isOk, isTrue);
    });

    test('restores a deleted seed account but leaves the others alone', () async {
      await accounts.mutate((list) => list.removeWhere((a) => a.email == 'admin@examora.app'));
      build();
      final emails = (await accounts.all()).map((a) => a.email).toList();
      expect(emails, containsAll(['student@examora.app', 'instructor@examora.app', 'admin@examora.app']));
      expect(emails, hasLength(3));
    });

    test('concurrent first calls still produce exactly three accounts', () async {
      build();
      await Future.wait([accounts.all(), accounts.all(), accounts.findByEmail('admin@examora.app')]);
      expect(await accounts.all(), hasLength(3));
    });
  });

  group('signIn', () {
    for (final seed in seedAccounts) {
      test('${seed.role.name} signs in with the seeded password', () async {
        final result = await repository.signIn(email: seed.email, password: seed.password);
        final account = result.valueOrNull!;
        expect(account.fullName, seed.fullName);
        expect(account.role, seed.role);
        expect(account.mustChangePassword, isFalse);
      });
    }

    test('the email is trimmed and case-insensitive', () async {
      expect((await repository.signIn(email: '  STUDENT@Examora.App ', password: 'Examora#2026')).isOk, isTrue);
    });

    test('a wrong password and an unknown email give the SAME failure', () async {
      final wrongPassword = (await repository.signIn(email: 'student@examora.app', password: 'nope')).failureOrNull;
      final unknownEmail = (await repository.signIn(
        email: 'nobody@examora.app',
        password: 'Examora#2026',
      )).failureOrNull;
      expect(wrongPassword, isA<InvalidCredentialsFailure>());
      expect(unknownEmail, isA<InvalidCredentialsFailure>());
      expect(wrongPassword!.message, unknownEmail!.message);
      expect(wrongPassword.code, unknownEmail.code);
    });

    test('blank fields are refused as validation, naming the fields', () async {
      final failure = (await repository.signIn(email: '', password: '')).failureOrNull as ValidationFailure;
      expect(failure.fields.keys, containsAll(['email', 'password']));
    });

    test('a successful sign-in writes a 12-hour session and records the time', () async {
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      final session = (await sessions.read())!;
      expect(session.expiresAt, env.clock.now().add(const Duration(hours: 12)));
      expect((await accounts.findByEmail('student@examora.app'))!.lastLoginAt, env.clock.now());
    });

    test('the session holds no password and no hash', () async {
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      final text = env.secureStore.values['local.session.v1']!;
      expect(text, isNot(contains('Examora')));
      expect(text, isNot(contains('pbkdf2')));
    });

    test('a deactivated account cannot sign in (only after the right password, so nobody can probe for it)', () async {
      final student = (await accounts.findByEmail('student@examora.app'))!;
      await accounts.replace(student.copyWith(status: AccountStatus.deactivated));
      expect(
        (await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).failureOrNull,
        isA<AccountDeactivatedFailure>(),
      );
      expect(
        (await repository.signIn(email: 'student@examora.app', password: 'wrong')).failureOrNull,
        isA<InvalidCredentialsFailure>(),
      );
    });

    test('an expired temporary password is refused with its own message', () async {
      final student = (await accounts.findByEmail('student@examora.app'))!;
      await accounts.replace(
        student.copyWith(
          mustChangePassword: true,
          temporaryPasswordExpiresAt: Nullable(env.clock.now().subtract(const Duration(minutes: 1))),
        ),
      );
      expect(
        (await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).failureOrNull,
        isA<TemporaryPasswordExpiredFailure>(),
      );
    });

    test('a temporary password that has not expired signs in and sets mustChangePassword', () async {
      final student = (await accounts.findByEmail('student@examora.app'))!;
      await accounts.replace(
        student.copyWith(
          mustChangePassword: true,
          temporaryPasswordExpiresAt: Nullable(env.clock.now().add(const Duration(hours: 72))),
        ),
      );
      final account = (await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).valueOrNull!;
      expect(account.mustChangePassword, isTrue);
    });

    group('lockout', () {
      test('five wrong passwords lock the account, even for the right password', () async {
        for (var attempt = 1; attempt < LocalAuthRepository.maxFailedAttempts; attempt++) {
          expect(
            (await repository.signIn(email: 'student@examora.app', password: 'bad$attempt')).failureOrNull,
            isA<InvalidCredentialsFailure>(),
          );
        }
        expect(
          (await repository.signIn(email: 'student@examora.app', password: 'bad5')).failureOrNull,
          isA<AccountLockedFailure>(),
        );
        expect(
          (await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).failureOrNull,
          isA<AccountLockedFailure>(),
        );
      });

      test('the lock ends after 15 minutes and not a second before', () async {
        for (var i = 0; i < 5; i++) {
          await repository.signIn(email: 'student@examora.app', password: 'bad');
        }
        env.clock.advance(const Duration(minutes: 14, seconds: 59));
        expect(
          (await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).failureOrNull,
          isA<AccountLockedFailure>(),
        );
        env.clock.advance(const Duration(seconds: 2));
        expect((await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).isOk, isTrue);
      });

      test('a success resets the count', () async {
        for (var i = 0; i < 4; i++) {
          await repository.signIn(email: 'student@examora.app', password: 'bad');
        }
        await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
        for (var i = 0; i < 4; i++) {
          expect(
            (await repository.signIn(email: 'student@examora.app', password: 'bad')).failureOrNull,
            isA<InvalidCredentialsFailure>(),
          );
        }
      });

      test('locking one account does not lock another', () async {
        for (var i = 0; i < 5; i++) {
          await repository.signIn(email: 'student@examora.app', password: 'bad');
        }
        expect((await repository.signIn(email: 'instructor@examora.app', password: 'Examora#2026')).isOk, isTrue);
      });
    });

    test('a storage failure is reported as a StorageFailure, not thrown', () async {
      final failing = FailingKeyValueStore();
      build(store: failing);
      failing.failReads = true;
      expect(
        (await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).failureOrNull,
        isA<StorageFailure>(),
      );
    });
  });

  group('session', () {
    test('restoring returns the signed-in account', () async {
      await repository.signIn(email: 'instructor@examora.app', password: 'Examora#2026');
      build(); // the app was killed and restarted
      final restored = (await repository.restoreSession()).valueOrNull!;
      expect(restored.email, 'instructor@examora.app');
      expect(restored.role, UserRole.instructor);
    });

    test('there is no session before anyone signed in', () async {
      expect((await repository.restoreSession()).valueOrNull, isNull);
    });

    test('a session lasts 12 hours: valid just before, gone at the boundary', () async {
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      env.clock.advance(const Duration(hours: 11, minutes: 59, seconds: 59));
      expect((await repository.restoreSession()).valueOrNull, isNotNull);
      env.clock.advance(const Duration(seconds: 1));
      expect((await repository.restoreSession()).valueOrNull, isNull);
      expect(await sessions.read(), isNull, reason: 'an expired session is cleared, not just ignored');
    });

    test('restoring re-reads the account, so a role change elsewhere shows after a restart', () async {
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      final student = (await accounts.findByEmail('student@examora.app'))!;
      await accounts.mutate((list) {
        final index = list.indexWhere((a) => a.id == student.id);
        list[index] = StoredAccount(
          id: student.id,
          fullName: 'Malk Mostafa',
          email: student.email,
          role: UserRole.instructor,
          passwordHash: student.passwordHash,
          mustChangePassword: true,
          status: AccountStatus.active,
          createdAt: student.createdAt,
        );
      });
      final restored = (await repository.restoreSession()).valueOrNull!;
      expect(restored.role, UserRole.instructor);
      expect(restored.mustChangePassword, isTrue);
    });

    test('if the account is gone the session is cleared', () async {
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      final id = (await accounts.findByEmail('student@examora.app'))!.id;
      await accounts.mutate((list) => list.removeWhere((a) => a.id == id));
      await env.keyValueStore.write(
        'local.accounts.v1',
        jsonEncode((await accounts.all()).where((a) => a.id != id).map((a) => a.toJson()).toList()),
      );
      // The seed would recreate "student@..." with a NEW id; the old session's id no longer exists.
      expect((await repository.restoreSession()).valueOrNull, isNull);
      expect(await sessions.read(), isNull);
    });

    test('a deactivated account loses its session on restore', () async {
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      final student = (await accounts.findByEmail('student@examora.app'))!;
      await accounts.replace(student.copyWith(status: AccountStatus.deactivated));
      expect((await repository.restoreSession()).valueOrNull, isNull);
      expect(await sessions.read(), isNull);
    });

    test('a corrupt stored session is discarded, not a crash', () async {
      env.secureStore.values['local.session.v1'] = '{broken';
      expect((await repository.restoreSession()).valueOrNull, isNull);
      expect(env.secureStore.values, isEmpty);
    });

    test('signing out clears the session', () async {
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      await repository.signOut();
      expect(await sessions.read(), isNull);
      expect((await repository.restoreSession()).valueOrNull, isNull);
    });

    test('signing out always succeeds, even when storage fails', () async {
      final secure = FailingSecureStore();
      build(secure: secure);
      await repository.signIn(email: 'student@examora.app', password: 'Examora#2026');
      secure.failDelete = true;
      await expectLater(repository.signOut(), completes);
    });
  });

  group('changePassword', () {
    Future<void> signInAsStudent() => repository.signIn(email: 'student@examora.app', password: 'Examora#2026');

    test('changes the password: the new one signs in, the old one does not', () async {
      await signInAsStudent();
      expect(
        (await repository.changePassword(currentPassword: 'Examora#2026', newPassword: 'Brand#New2027')).isOk,
        isTrue,
      );
      expect((await repository.signIn(email: 'student@examora.app', password: 'Brand#New2027')).isOk, isTrue);
      expect(
        (await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).failureOrNull,
        isA<InvalidCredentialsFailure>(),
      );
    });

    test('clears a pending forced change', () async {
      final student = (await accounts.findByEmail('student@examora.app'))!;
      await accounts.replace(
        student.copyWith(
          mustChangePassword: true,
          temporaryPasswordExpiresAt: Nullable(env.clock.now().add(const Duration(hours: 1))),
        ),
      );
      await signInAsStudent();
      final updated = (await repository.changePassword(
        currentPassword: 'Examora#2026',
        newPassword: 'Brand#New2027',
      )).valueOrNull!;
      expect(updated.mustChangePassword, isFalse);
      expect((await accounts.findByEmail('student@examora.app'))!.temporaryPasswordExpiresAt, isNull);
    });

    test('a wrong current password changes nothing', () async {
      await signInAsStudent();
      final failure =
          (await repository.changePassword(currentPassword: 'wrong', newPassword: 'Brand#New2027')).failureOrNull
              as ValidationFailure;
      expect(failure.fields['currentPassword'], const KnownFieldProblem(FieldReason.currentPasswordIncorrect));
      expect((await repository.signIn(email: 'student@examora.app', password: 'Examora#2026')).isOk, isTrue);
    });

    test('the new password must follow the policy', () async {
      await signInAsStudent();
      for (final weak in ['short1A', 'alllowercase1', 'ALLUPPERCASE1', 'NoDigitsHere']) {
        final failure =
            (await repository.changePassword(currentPassword: 'Examora#2026', newPassword: weak)).failureOrNull
                as ValidationFailure;
        expect(failure.fields['newPassword'], const KnownFieldProblem(FieldReason.passwordPolicy), reason: weak);
      }
    });

    test('the new password must differ from the current one', () async {
      await signInAsStudent();
      final failure =
          (await repository.changePassword(currentPassword: 'Examora#2026', newPassword: 'Examora#2026')).failureOrNull
              as ValidationFailure;
      expect(failure.fields['newPassword'], const KnownFieldProblem(FieldReason.newPasswordSameAsCurrent));
    });

    test('without a session there is nothing to change', () async {
      expect(
        (await repository.changePassword(currentPassword: 'Examora#2026', newPassword: 'Brand#New2027')).failureOrNull,
        isA<SessionExpiredFailure>(),
      );
    });
  });
}
