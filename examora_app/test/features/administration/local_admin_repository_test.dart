import 'dart:math';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/security/temporary_password.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/administration/data/local_admin_repository.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/authentication/data/local_account_store.dart';
import 'package:examora_app/features/authentication/data/local_auth_repository.dart';
import 'package:examora_app/features/authentication/data/local_session_store.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';

void main() {
  late TestEnvironment env;
  late LocalAccountStore accounts;
  late LocalSessionStore sessions;
  late LocalAuthRepository auth;
  late LocalAdminRepository admin;

  setUp(() {
    env = TestEnvironment();
    accounts = LocalAccountStore(store: env.keyValueStore, hasher: TestEnvironment.fastHasher, clock: env.clock);
    sessions = LocalSessionStore(env.secureStore);
    auth = LocalAuthRepository(
      accounts: accounts,
      sessions: sessions,
      hasher: TestEnvironment.fastHasher,
      clock: env.clock,
    );
    admin = LocalAdminRepository(
      accounts: accounts,
      sessions: sessions,
      hasher: TestEnvironment.fastHasher,
      clock: env.clock,
      random: Random(7),
    );
  });

  Future<void> signInAs(String email) async {
    final result = await auth.signIn(email: email, password: 'Examora#2026');
    expect(result.isOk, isTrue, reason: 'could not sign in as $email');
  }

  T ok<T>(Result<T> result) {
    switch (result) {
      case Ok<T>(:final value):
        return value;
      case Err<T>(:final failure):
        fail('expected success, got $failure');
    }
  }

  AppFailure err<T>(Result<T> result) {
    switch (result) {
      case Ok<T>(:final value):
        fail('expected a failure, got $value');
      case Err<T>(:final failure):
        return failure;
    }
  }

  group('who may use it', () {
    test('without a session every call says the session ended', () async {
      expect(err(await admin.listAccounts()), isA<SessionExpiredFailure>());
      expect(err(await admin.getAccount('x')), isA<SessionExpiredFailure>());
      expect(
        err(await admin.createAccount(role: UserRole.student, fullName: 'A B', email: 'a@b.co')),
        isA<SessionExpiredFailure>(),
      );
    });

    for (final email in ['student@examora.app', 'instructor@examora.app']) {
      test('$email is forbidden from every operation', () async {
        await signInAs(email);
        final target = (await accounts.findByEmail('student@examora.app'))!;
        expect(err(await admin.listAccounts()), isA<ForbiddenFailure>());
        expect(err(await admin.getAccount(target.id)), isA<ForbiddenFailure>());
        expect(
          err(await admin.createAccount(role: UserRole.student, fullName: 'A B', email: 'a@b.co')),
          isA<ForbiddenFailure>(),
        );
        expect(err(await admin.issueTemporaryPassword(target.id)), isA<ForbiddenFailure>());
        expect(err(await admin.deactivate(target.id, reason: 'no')), isA<ForbiddenFailure>());
        expect(err(await admin.reactivate(target.id)), isA<ForbiddenFailure>());
        // And nothing changed.
        expect((await accounts.findByEmail('student@examora.app'))!.status, AccountStatus.active);
      });
    }

    test('an expired session is refused', () async {
      await signInAs('admin@examora.app');
      env.clock.advance(const Duration(hours: 13));
      expect(err(await admin.listAccounts()), isA<SessionExpiredFailure>());
    });
  });

  group('listing', () {
    setUp(() async {
      await signInAs('admin@examora.app');
    });

    test('never lists administrators', () async {
      final page = ok(await admin.listAccounts());
      expect(page.items.map((a) => a.email), unorderedEquals(['student@examora.app', 'instructor@examora.app']));
      expect(page.items.any((a) => a.role == UserRole.administrator), isFalse);
      expect(page.totalCount, 2);
    });

    test('refuses to filter by the administrator role', () async {
      expect(err(await admin.listAccounts(role: UserRole.administrator)), isA<ValidationFailure>());
    });

    test('is newest first', () async {
      env.clock.advance(const Duration(minutes: 1));
      ok(await admin.createAccount(role: UserRole.student, fullName: 'Newer One', email: 'newer@x.co'));
      env.clock.advance(const Duration(minutes: 1));
      ok(await admin.createAccount(role: UserRole.student, fullName: 'Newest One', email: 'newest@x.co'));
      final emails = ok(await admin.listAccounts()).items.map((a) => a.email).toList();
      expect(emails.first, 'newest@x.co');
      expect(emails[1], 'newer@x.co');
    });

    test('filters by role and by status, and the two combine', () async {
      ok(await admin.createAccount(role: UserRole.student, fullName: 'Second Student', email: 'second@x.co'));
      final student = (await accounts.findByEmail('second@x.co'))!;
      ok(await admin.deactivate(student.id, reason: 'left the course'));

      expect(ok(await admin.listAccounts(role: UserRole.student)).items.length, 2);
      expect(ok(await admin.listAccounts(role: UserRole.instructor)).items.length, 1);
      expect(ok(await admin.listAccounts(status: AccountStatus.deactivated)).items.single.email, 'second@x.co');
      expect(ok(await admin.listAccounts(role: UserRole.instructor, status: AccountStatus.deactivated)).items, isEmpty);
    });

    test('pages, with a total that counts every match', () async {
      for (var i = 0; i < 5; i++) {
        env.clock.advance(const Duration(minutes: 1));
        ok(await admin.createAccount(role: UserRole.student, fullName: 'Person $i', email: 'p$i@x.co'));
      }
      final first = ok(await admin.listAccounts(pageSize: 3));
      expect(first.items.length, 3);
      expect(first.totalCount, 7);
      expect(first.hasNext, isTrue);
      expect(first.hasPrevious, isFalse);

      final last = ok(await admin.listAccounts(page: 3, pageSize: 3));
      expect(last.items.length, 1);
      expect(last.hasNext, isFalse);
      expect(last.hasPrevious, isTrue);

      expect(ok(await admin.listAccounts(page: 9, pageSize: 3)).items, isEmpty);
    });

    test('rejects an out-of-range page or page size', () async {
      expect(err(await admin.listAccounts(page: 0)), isA<ValidationFailure>());
      expect(err(await admin.listAccounts(pageSize: 101)), isA<ValidationFailure>());
    });

    test('shows locked and must-change-password state, and no secrets', () async {
      ok(await admin.createAccount(role: UserRole.student, fullName: 'Fresh Account', email: 'fresh@x.co'));
      final fresh = ok(await admin.listAccounts()).items.firstWhere((a) => a.email == 'fresh@x.co');
      expect(fresh.mustChangePassword, isTrue);
      expect(fresh.temporaryPasswordExpiresAt, env.clock.now().add(const Duration(hours: 72)));

      for (var i = 0; i < LocalAuthRepository.maxFailedAttempts; i++) {
        await auth.signIn(email: 'student@examora.app', password: 'wrong');
      }
      await signInAs('admin@examora.app');
      final locked = ok(await admin.listAccounts()).items.firstWhere((a) => a.email == 'student@examora.app');
      expect(locked.isLockedOut, isTrue);
    });
  });

  group('creating', () {
    setUp(() async {
      await signInAs('admin@examora.app');
    });

    test('an instructor gets a policy-meeting temporary password that works once and must be changed', () async {
      final issued = ok(
        await admin.createAccount(role: UserRole.instructor, fullName: '  Dr. Sara Nabil ', email: ' Sara@Uni.EDU '),
      );
      expect(issued.email, 'sara@uni.edu');
      expect(issued.fullName, 'Dr. Sara Nabil');
      expect(Validators.newPassword(issued.temporaryPassword), isNull);
      expect(issued.expiresAt, env.clock.now().add(const Duration(hours: 72)));

      final stored = (await accounts.findByEmail('sara@uni.edu'))!;
      expect(stored.role, UserRole.instructor);
      expect(stored.mustChangePassword, isTrue);
      expect(stored.status, AccountStatus.active);
      // Only the hash is stored.
      expect(stored.passwordHash.contains(issued.temporaryPassword), isFalse);
      expect(env.keyValueStore.values.values.any((v) => v.contains(issued.temporaryPassword)), isFalse);

      await auth.signOut();
      final signedIn = ok(await auth.signIn(email: 'sara@uni.edu', password: issued.temporaryPassword));
      expect(signedIn.role, UserRole.instructor);
      expect(signedIn.mustChangePassword, isTrue);
    });

    test('a student can be created too', () async {
      final issued = ok(await admin.createAccount(role: UserRole.student, fullName: 'Omar Ali', email: 'omar@uni.edu'));
      expect((await accounts.findByEmail('omar@uni.edu'))!.role, UserRole.student);
      await auth.signOut();
      expect(ok(await auth.signIn(email: 'omar@uni.edu', password: issued.temporaryPassword)).role, UserRole.student);
    });

    test('the temporary password stops working after 72 hours', () async {
      final issued = ok(await admin.createAccount(role: UserRole.student, fullName: 'Late Person', email: 'l@uni.edu'));
      await auth.signOut();
      env.clock.advance(const Duration(hours: 73));
      expect(
        err(await auth.signIn(email: 'l@uni.edu', password: issued.temporaryPassword)),
        isA<TemporaryPasswordExpiredFailure>(),
      );
    });

    test('an administrator account cannot be created', () async {
      expect(
        err(await admin.createAccount(role: UserRole.administrator, fullName: 'Evil Admin', email: 'e@x.co')),
        isA<ForbiddenFailure>(),
      );
      expect(await accounts.findByEmail('e@x.co'), isNull);
    });

    test('a duplicate email is a conflict, compared without case or spaces, and creates nothing', () async {
      final before = (await accounts.all()).length;
      final failure = err(
        await admin.createAccount(role: UserRole.student, fullName: 'Copy Cat', email: ' STUDENT@examora.app '),
      );
      expect(failure, isA<ConflictFailure>());
      expect(failure.code, 'duplicate_account');
      expect((await accounts.all()).length, before);
    });

    test('invalid names and emails report the field', () async {
      final failure = err(await admin.createAccount(role: UserRole.student, fullName: '   ', email: 'not-an-email'));
      expect(failure, isA<ValidationFailure>());
      final fields = (failure as ValidationFailure).fields;
      expect(fields.keys, containsAll(['fullName', 'email']));
      expect(fields['fullName'], const KnownFieldProblem(FieldReason.required));
      expect(fields['email'], const KnownFieldProblem(FieldReason.invalidEmail));
    });

    test('a name with control characters or over 150 characters is refused', () async {
      expect(Validators.fullName('Bad\u0000Name'), const KnownFieldProblem(FieldReason.invalidCharacters));
      expect(Validators.fullName('x' * 151), const KnownFieldProblem(FieldReason.tooLong));
      expect(Validators.fullName('x' * 150), isNull);
    });

    test('two simultaneous creations of the same email create one account', () async {
      final results = await Future.wait([
        admin.createAccount(role: UserRole.student, fullName: 'Twin One', email: 'twin@x.co'),
        admin.createAccount(role: UserRole.student, fullName: 'Twin Two', email: 'twin@x.co'),
      ]);
      expect(results.where((r) => r.isOk).length, 1);
      expect((await accounts.all()).where((a) => a.email == 'twin@x.co').length, 1);
    });
  });

  group('temporary password for an existing account', () {
    setUp(() async {
      await signInAs('admin@examora.app');
    });

    test('replaces the old password, forces a change, clears a lock and returns the password once', () async {
      for (var i = 0; i < LocalAuthRepository.maxFailedAttempts; i++) {
        await auth.signIn(email: 'student@examora.app', password: 'wrong');
      }
      await signInAs('admin@examora.app');
      final target = (await accounts.findByEmail('student@examora.app'))!;
      expect(target.isLockedAt(env.clock.now()), isTrue);

      final issued = ok(await admin.issueTemporaryPassword(target.id));
      expect(Validators.newPassword(issued.temporaryPassword), isNull);
      expect(issued.email, 'student@examora.app');

      final after = (await accounts.findById(target.id))!;
      expect(after.mustChangePassword, isTrue);
      expect(after.isLockedAt(env.clock.now()), isFalse);
      expect(after.temporaryPasswordExpiresAt, env.clock.now().add(const Duration(hours: 72)));

      await auth.signOut();
      expect(
        err(await auth.signIn(email: 'student@examora.app', password: 'Examora#2026')),
        isA<InvalidCredentialsFailure>(),
      );
      expect(
        ok(await auth.signIn(email: 'student@examora.app', password: issued.temporaryPassword)).mustChangePassword,
        isTrue,
      );
    });

    test('a deactivated account stays deactivated', () async {
      final target = (await accounts.findByEmail('student@examora.app'))!;
      ok(await admin.deactivate(target.id, reason: 'on leave'));
      ok(await admin.issueTemporaryPassword(target.id));
      expect((await accounts.findById(target.id))!.status, AccountStatus.deactivated);
    });

    test('an administrator or unknown id is not found', () async {
      final adminAccount = (await accounts.findByEmail('admin@examora.app'))!;
      expect(err(await admin.issueTemporaryPassword(adminAccount.id)), isA<NotFoundFailure>());
      expect(err(await admin.issueTemporaryPassword('no-such-id')), isA<NotFoundFailure>());
    });

    test('the IssuedPassword text never contains the password', () async {
      final target = (await accounts.findByEmail('student@examora.app'))!;
      final issued = ok(await admin.issueTemporaryPassword(target.id));
      expect(issued.toString().contains(issued.temporaryPassword), isFalse);
    });
  });

  group('deactivating and reactivating', () {
    late String studentId;

    setUp(() async {
      await signInAs('admin@examora.app');
      studentId = (await accounts.findByEmail('student@examora.app'))!.id;
    });

    test('a reason is required to deactivate', () async {
      for (final reason in ['', '   ']) {
        final failure = err(await admin.deactivate(studentId, reason: reason));
        expect((failure as ValidationFailure).fields['reason'], const KnownFieldProblem(FieldReason.required));
      }
      final tooLong = err(await admin.deactivate(studentId, reason: 'x' * 501));
      expect((tooLong as ValidationFailure).fields['reason'], const KnownFieldProblem(FieldReason.tooLong));
      expect(ok(await admin.deactivate(studentId, reason: 'x' * 500)).status, AccountStatus.deactivated);
    });

    test('records the status, the trimmed reason and when', () async {
      env.clock.advance(const Duration(hours: 1));
      final account = ok(await admin.deactivate(studentId, reason: '  plagiarism case  '));
      expect(account.status, AccountStatus.deactivated);
      expect(account.statusReason, 'plagiarism case');
      expect(account.statusChangedAt, env.clock.now());
    });

    test('a deactivated account cannot sign in, and can again after reactivation', () async {
      ok(await admin.deactivate(studentId, reason: 'left'));
      await auth.signOut();
      expect(
        err(await auth.signIn(email: 'student@examora.app', password: 'Examora#2026')),
        isA<AccountDeactivatedFailure>(),
      );

      await signInAs('admin@examora.app');
      final back = ok(await admin.reactivate(studentId));
      expect(back.status, AccountStatus.active);
      await auth.signOut();
      expect(ok(await auth.signIn(email: 'student@examora.app', password: 'Examora#2026')).role, UserRole.student);
    });

    test('reactivation takes an optional reason; blank means none', () async {
      ok(await admin.deactivate(studentId, reason: 'left'));
      expect(ok(await admin.reactivate(studentId, reason: '  ')).statusReason, isNull);
      ok(await admin.deactivate(studentId, reason: 'left again'));
      expect(ok(await admin.reactivate(studentId, reason: 'returned')).statusReason, 'returned');
      ok(await admin.deactivate(studentId, reason: 'left a third time'));
      expect(err(await admin.reactivate(studentId, reason: 'x' * 501)), isA<ValidationFailure>());
    });

    test('asking for the status an account already has is a conflict, not a silent success', () async {
      final already = err(await admin.reactivate(studentId));
      expect(already, isA<ConflictFailure>());
      expect(already.code, 'account_already_active');

      ok(await admin.deactivate(studentId, reason: 'left'));
      final twice = err(await admin.deactivate(studentId, reason: 'again'));
      expect(twice, isA<ConflictFailure>());
      expect(twice.code, 'account_already_deactivated');
      // The first reason is untouched.
      expect((await accounts.findById(studentId))!.statusReason, 'left');
    });

    test('administrators and unknown ids cannot be deactivated', () async {
      final adminAccount = (await accounts.findByEmail('admin@examora.app'))!;
      expect(err(await admin.deactivate(adminAccount.id, reason: 'x')), isA<NotFoundFailure>());
      expect(err(await admin.deactivate('nope', reason: 'x')), isA<NotFoundFailure>());
      expect(err(await admin.reactivate('nope')), isA<NotFoundFailure>());
      expect((await accounts.findByEmail('admin@examora.app'))!.status, AccountStatus.active);
    });
  });

  group('storage trouble', () {
    test('is reported as a storage failure, never thrown', () async {
      await signInAs('admin@examora.app');
      final broken = LocalAdminRepository(
        accounts: LocalAccountStore(
          store: _BrokenStore(env.keyValueStore),
          hasher: TestEnvironment.fastHasher,
          clock: env.clock,
        ),
        sessions: sessions,
        hasher: TestEnvironment.fastHasher,
        clock: env.clock,
      );
      expect(err(await broken.listAccounts()), isA<StorageFailure>());
    });
  });

  group('TemporaryPassword', () {
    test('always has 16 characters from the safe alphabet and meets the password policy', () {
      final random = Random(1);
      for (var i = 0; i < 500; i++) {
        final password = TemporaryPassword.generate(random);
        expect(password.length, TemporaryPassword.length);
        expect(password.split('').every(TemporaryPassword.alphabet.contains), isTrue);
        expect(Validators.newPassword(password), isNull);
        expect(RegExp('[0O1lI]').hasMatch(password), isFalse, reason: password);
      }
    });

    test('the secure default produces different passwords', () {
      final seen = {for (var i = 0; i < 50; i++) TemporaryPassword.generate()};
      expect(seen.length, 50);
    });
  });

  group('ManagedAccount', () {
    ManagedAccount? tryParse(Map<String, Object?> json) => switch (JsonReader.parse(json, ManagedAccount.fromJson)) {
      Ok<ManagedAccount>(:final value) => value,
      Err<ManagedAccount>() => null,
    };

    test('rejects an unrecognised role or status instead of defaulting', () {
      Map<String, Object?> json({String role = 'Student', String status = 'Active'}) => {
        'id': '1',
        'fullName': 'A B',
        'email': 'a@b.co',
        'role': role,
        'accountStatus': status,
        'mustChangePassword': false,
        'temporaryPasswordExpiresAt': null,
        'isLockedOut': false,
        'createdAt': '2026-10-27T09:00:00Z',
        'lastLoginAt': null,
        'statusChangedAt': null,
        'statusReason': null,
      };
      expect(tryParse(json())?.role, UserRole.student);
      expect(tryParse(json(role: 'Root')), isNull);
      expect(tryParse(json(status: 'Banned')), isNull);
    });
  });
}

/// A store whose reads always fail.
final class _BrokenStore implements KeyValueStore {
  _BrokenStore(this._inner);

  final KeyValueStore _inner;

  @override
  Future<String?> read(String key) async => throw StateError('disk read failed');

  @override
  Future<void> write(String key, String value) => _inner.write(key, value);

  @override
  Future<void> delete(String key) => _inner.delete(key);
}
