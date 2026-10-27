import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Ok exposes its value and no failure', () {
      const Result<int> result = Ok(3);
      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 3);
      expect(result.failureOrNull, isNull);
    });

    test('Err exposes its failure and no value', () {
      const Result<int> result = Err(NetworkFailure());
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('map transforms a value and leaves a failure untouched', () {
      expect(const Ok<int>(2).map((v) => v * 10).valueOrNull, 20);
      final mapped = const Err<int>(TimeoutFailure()).map((v) => v * 10);
      expect(mapped.failureOrNull, isA<TimeoutFailure>());
    });

    test('andThen runs the next step only after success', () async {
      var called = 0;
      Future<Result<String>> next(int v) async {
        called++;
        return Ok('v$v');
      }

      expect((await const Ok<int>(1).andThen(next)).valueOrNull, 'v1');
      expect((await const Err<int>(ServerFailure()).andThen(next)).failureOrNull, isA<ServerFailure>());
      expect(called, 1);
    });

    test('an exhaustive switch over a Result compiles for both cases', () {
      String describe(Result<int> r) => switch (r) {
        Ok<int>(:final value) => 'ok $value',
        Err<int>(:final failure) => 'err ${failure.code}',
      };
      expect(describe(const Ok(1)), 'ok 1');
      expect(describe(const Err(NotFoundFailure())), 'err not_found');
    });
  });

  group('AppFailure', () {
    test('every failure carries a code and an English message that is safe to show', () {
      const failures = <AppFailure>[
        ValidationFailure(),
        InvalidCredentialsFailure(),
        AccountLockedFailure(),
        AccountDeactivatedFailure(),
        TemporaryPasswordExpiredFailure(),
        SessionExpiredFailure(),
        PasswordChangeRequiredFailure(),
        ForbiddenFailure(),
        NotFoundFailure(),
        ConflictFailure(),
        NetworkFailure(),
        TimeoutFailure(),
        RateLimitedFailure(),
        ServerFailure(statusCode: 500),
        StorageFailure(),
        ParseFailure(field: 'role', problem: 'is missing'),
        EndpointMissingFailure(endpoint: 'POST /api/x'),
        UnavailableFailure(capability: 'Camera'),
      ];
      for (final failure in failures) {
        expect(failure.code, isNotEmpty, reason: failure.runtimeType.toString());
        expect(failure.message, isNotEmpty, reason: failure.runtimeType.toString());
      }
    });

    test('a server failure never carries server text', () {
      expect(const ServerFailure(statusCode: 500).message, isNot(contains('Exception')));
    });

    test('wrong password and unknown email are the same failure value', () {
      expect(const InvalidCredentialsFailure().message, 'Incorrect email or password.');
    });
  });

  group('JsonReader', () {
    test('reads typed fields', () {
      final reader = JsonReader.of({
        'name': 'Ana',
        'age': 31,
        'score': 2.5,
        'ok': true,
        'when': '2026-10-27T09:00:00+02:00',
        'tags': ['a', 'b'],
        'inner': {'x': 1},
      });
      expect(reader.string('name'), 'Ana');
      expect(reader.integer('age'), 31);
      expect(reader.number('score'), 2.5);
      expect(reader.boolean('ok'), isTrue);
      expect(reader.dateTime('when'), DateTime.utc(2026, 10, 27, 7));
      expect(reader.stringList('tags'), ['a', 'b']);
      expect(reader.object('inner').integer('x'), 1);
    });

    test('a missing field names itself', () {
      final reader = JsonReader.of(<String, Object?>{});
      expect(
        () => reader.string('email'),
        throwsA(
          isA<JsonParseException>()
              .having((e) => e.field, 'field', 'email')
              .having((e) => e.problem, 'problem', 'is missing'),
        ),
      );
    });

    test('a wrong type names the field and what it must be', () {
      final reader = JsonReader.of({'age': 'old'});
      expect(
        () => reader.integer('age'),
        throwsA(isA<JsonParseException>().having((e) => e.problem, 'problem', 'must be a whole number')),
      );
    });

    test('nested fields are named with their path', () {
      final reader = JsonReader.of({
        'user': {'role': 5},
      });
      expect(
        () => reader.object('user').string('role'),
        throwsA(isA<JsonParseException>().having((e) => e.field, 'field', 'user.role')),
      );
    });

    test('list items are named with their index', () {
      final reader = JsonReader.of({
        'items': [
          {'id': 'a'},
          {'id': 2},
        ],
      });
      expect(
        () => reader.list('items', (item) => item.string('id')),
        throwsA(isA<JsonParseException>().having((e) => e.field, 'field', 'items[1].id')),
      );
    });

    test('a whole-number double is accepted as an integer, a fractional one is not', () {
      expect(JsonReader.of({'n': 3.0}).integer('n'), 3);
      expect(() => JsonReader.of({'n': 3.5}).integer('n'), throwsA(isA<JsonParseException>()));
    });

    test('a non-object root is a parse error', () {
      expect(() => JsonReader.of([1, 2]), throwsA(isA<JsonParseException>()));
    });

    test('parse turns the exception into an Err naming the field', () {
      final result = JsonReader.parse<String>({'a': 1}, (r) => r.string('a'));
      final failure = result.failureOrNull;
      expect(failure, isA<ParseFailure>());
      expect((failure! as ParseFailure).field, 'a');
    });

    test('optional fields may be absent or null but are still type-checked', () {
      final reader = JsonReader.of({'x': null, 'y': 5});
      expect(reader.optionalString('x'), isNull);
      expect(reader.optionalString('missing'), isNull);
      expect(() => reader.optionalString('y'), throwsA(isA<JsonParseException>()));
    });

    test('an unrecognised enum value is a hard error, never a default', () {
      final reader = JsonReader.of({'role': 'SuperUser'});
      expect(
        () => reader.enumValue('role', UserRole.byWireName),
        throwsA(isA<JsonParseException>().having((e) => e.problem, 'problem', contains('SuperUser'))),
      );
    });
  });

  group('Account', () {
    test('round-trips through JSON', () {
      const account = Account(
        id: 'u1',
        fullName: 'Malk Mostafa',
        email: 'student@examora.app',
        role: UserRole.student,
        mustChangePassword: true,
      );
      final parsed = Account.fromJson(JsonReader.of(account.toJson()));
      expect(parsed, account);
    });

    test('the wire role names match the API', () {
      expect(UserRole.administrator.wireName, 'Admin');
      expect(UserRole.instructor.wireName, 'Instructor');
      expect(UserRole.student.wireName, 'Student');
    });

    test('a payload with an unknown role cannot become an account (no privilege by default)', () {
      final result = JsonReader.parse<Account>({
        'id': 'u',
        'fullName': 'X',
        'email': 'x@y.z',
        'role': 'Root',
        'mustChangePassword': false,
      }, Account.fromJson);
      expect(result.isErr, isTrue);
      expect((result.failureOrNull! as ParseFailure).field, 'role');
    });

    test('a payload with a missing role cannot become an account', () {
      final result = JsonReader.parse<Account>({
        'id': 'u',
        'fullName': 'X',
        'email': 'x@y.z',
        'mustChangePassword': false,
      }, Account.fromJson);
      expect(result.isErr, isTrue);
    });
  });
}
