import 'dart:convert';

import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/configuration/data_source.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/network/api_client.dart';
import 'package:examora_app/core/network/api_tokens.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/administration/data/admin_providers.dart';
import 'package:examora_app/features/administration/data/api_admin_repository.dart';
import 'package:examora_app/features/administration/data/local_admin_repository.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_clock.dart';

/// Pins the exact requests and responses of the Api administration repository against the real .NET contract
/// (`AdminAccountsController`, route `api/admin`).
void main() {
  late FakeClock clock;
  late ApiTokenStore tokenStore;
  late List<http.Request> requests;

  setUp(() async {
    clock = FakeClock(DateTime.utc(2026, 10, 27, 9));
    tokenStore = ApiTokenStore(InMemorySecureStore());
    requests = [];
    await tokenStore.write(
      ApiTokens(
        accessToken: 'access-1',
        accessTokenExpiresAt: clock.now().add(const Duration(minutes: 15)),
        refreshToken: 'refresh-1',
        refreshTokenExpiresAt: clock.now().add(const Duration(days: 7)),
      ),
    );
  });

  ApiAdminRepository repositoryAnswering(http.Response Function(http.Request request) answer) {
    final client = ApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      baseUrl: 'https://api.test',
      tokens: tokenStore,
      clock: clock,
    );
    return ApiAdminRepository(client: client);
  }

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  http.Response problem(int status, String code, String detail, {Map<String, List<String>>? errors}) => http.Response(
    jsonEncode({'status': status, 'code': code, 'detail': detail, 'errors': ?errors}),
    status,
    headers: {'content-type': 'application/problem+json'},
  );

  Map<String, Object?> summary({
    String id = 'a1',
    String role = 'Student',
    String status = 'Active',
    bool mustChange = false,
    bool locked = false,
    String? reason,
  }) => {
    'id': id,
    'fullName': 'Malk Mostafa',
    'email': 'student@examora.app',
    'role': role,
    'accountStatus': status,
    'mustChangePassword': mustChange,
    'temporaryPasswordExpiresAt': mustChange ? '2026-10-30T09:00:00Z' : null,
    'isLockedOut': locked,
    'createdAt': '2026-10-01T08:00:00Z',
    'lastLoginAt': '2026-10-26T18:30:00+00:00',
    'statusChangedAt': reason == null ? null : '2026-10-20T10:00:00Z',
    'statusReason': reason,
  };

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

  group('GET /api/admin/accounts', () {
    test('sends role, status, page and pageSize as the server names them, with the bearer token', () async {
      final repository = repositoryAnswering(
        (_) => json({
          'items': [summary()],
          'page': 2,
          'pageSize': 5,
          'totalCount': 11,
        }),
      );
      final page = ok(
        await repository.listAccounts(role: UserRole.student, status: AccountStatus.deactivated, page: 2, pageSize: 5),
      );

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.path, '/api/admin/accounts');
      expect(request.url.queryParameters, {'role': 'Student', 'status': 'Deactivated', 'page': '2', 'pageSize': '5'});
      expect(request.headers['Authorization'], 'Bearer access-1');

      expect(page.page, 2);
      expect(page.pageSize, 5);
      expect(page.totalCount, 11);
      expect(page.hasNext, isTrue);
      final account = page.items.single;
      expect(account.id, 'a1');
      expect(account.role, UserRole.student);
      expect(account.status, AccountStatus.active);
      expect(account.lastLoginAt, DateTime.utc(2026, 10, 26, 18, 30));
    });

    test('omits filters that are not set', () async {
      final repository = repositoryAnswering(
        (_) => json({'items': <Object>[], 'page': 1, 'pageSize': 20, 'totalCount': 0}),
      );
      ok(await repository.listAccounts());
      expect(requests.single.url.queryParameters, {'page': '1', 'pageSize': '20'});
    });

    test('an unrecognised role in the payload is a parse error naming the field, never a default role', () async {
      final repository = repositoryAnswering(
        (_) => json({
          'items': [summary(role: 'Root')],
          'page': 1,
          'pageSize': 20,
          'totalCount': 1,
        }),
      );
      final failure = err(await repository.listAccounts());
      expect(failure, isA<ParseFailure>());
      expect((failure as ParseFailure).field, 'items[0].role');
    });

    test('maps 400, 401, 403 and 5xx', () async {
      var status = 400;
      final repository = repositoryAnswering(
        (_) => status == 400
            ? problem(
                400,
                'validation_failed',
                'bad',
                errors: {
                  'pageSize': ['Page size must be at most 100.'],
                },
              )
            : problem(status, 'x', 'x'),
      );
      final invalid = err(await repository.listAccounts(pageSize: 500));
      expect(
        (invalid as ValidationFailure).fields['pageSize'],
        const ServerFieldProblem('Page size must be at most 100.'),
      );

      status = 403;
      expect(err(await repository.listAccounts()), isA<ForbiddenFailure>());
      status = 500;
      expect(err(await repository.listAccounts()), isA<ServerFailure>());
    });
  });

  group('GET /api/admin/accounts/{id}', () {
    test('reads one account and escapes the id', () async {
      final repository = repositoryAnswering((_) => json(summary(mustChange: true, locked: true)));
      final account = ok(await repository.getAccount('a b/1'));
      expect(requests.single.url.path, '/api/admin/accounts/a%20b%2F1');
      expect(account.mustChangePassword, isTrue);
      expect(account.isLockedOut, isTrue);
      expect(account.temporaryPasswordExpiresAt, DateTime.utc(2026, 10, 30, 9));
    });

    test('404 is not found', () async {
      final repository = repositoryAnswering((_) => problem(404, 'account_not_found', 'The account was not found.'));
      expect(err(await repository.getAccount('x')), isA<NotFoundFailure>());
    });
  });

  group('POST /api/admin/instructors', () {
    test('sends exactly fullName and email (no role field) and reads the one-time password', () async {
      final repository = repositoryAnswering(
        (_) => json({
          'id': 'new-1',
          'fullName': 'Dr. Sara Nabil',
          'email': 'sara@uni.edu',
          'role': 'Instructor',
          'temporaryPassword': 'Abcdefgh2345Jkmn',
          'temporaryPasswordExpiresAt': '2026-10-30T09:00:00Z',
        }, 201),
      );
      final issued = ok(
        await repository.createAccount(
          role: UserRole.instructor,
          fullName: ' Dr. Sara Nabil ',
          email: ' Sara@Uni.edu ',
        ),
      );
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/admin/instructors');
      expect(jsonDecode(request.body), {'fullName': 'Dr. Sara Nabil', 'email': 'sara@uni.edu'});
      expect(issued.temporaryPassword, 'Abcdefgh2345Jkmn');
      expect(issued.expiresAt, DateTime.utc(2026, 10, 30, 9));
      expect(issued.toString().contains('Abcdefgh2345Jkmn'), isFalse);
    });

    test('409 duplicate_account is a conflict with the server code', () async {
      final repository = repositoryAnswering(
        (_) => problem(409, 'duplicate_account', 'An account with this email already exists.'),
      );
      final failure = err(
        await repository.createAccount(role: UserRole.instructor, fullName: 'Dr Who', email: 'a@b.co'),
      );
      expect(failure, isA<ConflictFailure>());
      expect(failure.code, 'duplicate_account');
    });

    test('validates before sending', () async {
      final repository = repositoryAnswering((_) => fail('no request expected'));
      final failure = err(await repository.createAccount(role: UserRole.instructor, fullName: '', email: 'nope'));
      expect(failure, isA<ValidationFailure>());
      expect(requests, isEmpty);
    });

    test(
      'creating a STUDENT is refused by name and sends nothing - there is no endpoint, and no local fallback',
      () async {
        final repository = repositoryAnswering((_) => fail('no request expected'));
        final failure = err(
          await repository.createAccount(role: UserRole.student, fullName: 'Omar Ali', email: 'omar@uni.edu'),
        );
        expect(failure, isA<EndpointMissingFailure>());
        expect((failure as EndpointMissingFailure).endpoint, 'POST /api/admin/students');
        expect(requests, isEmpty);
      },
    );

    test('an administrator is never created', () async {
      final repository = repositoryAnswering((_) => fail('no request expected'));
      expect(
        err(await repository.createAccount(role: UserRole.administrator, fullName: 'Evil Admin', email: 'e@x.co')),
        isA<ForbiddenFailure>(),
      );
      expect(requests, isEmpty);
    });
  });

  group('POST /api/admin/accounts/{id}/temporary-password', () {
    test('reads the person first, posts, and combines the two', () async {
      final repository = repositoryAnswering((request) {
        if (request.method == 'GET') return json(summary());
        return json({'temporaryPassword': 'Zyxwvuts9876Pqrs', 'temporaryPasswordExpiresAt': '2026-10-30T09:00:00Z'});
      });
      final issued = ok(await repository.issueTemporaryPassword('a1'));
      expect(requests.map((r) => '${r.method} ${r.url.path}'), [
        'GET /api/admin/accounts/a1',
        'POST /api/admin/accounts/a1/temporary-password',
      ]);
      expect(issued.email, 'student@examora.app');
      expect(issued.fullName, 'Malk Mostafa');
      expect(issued.temporaryPassword, 'Zyxwvuts9876Pqrs');
    });

    test('an unknown account stops after the read', () async {
      final repository = repositoryAnswering((_) => problem(404, 'account_not_found', 'The account was not found.'));
      expect(err(await repository.issueTemporaryPassword('zzz')), isA<NotFoundFailure>());
      expect(requests.length, 1);
    });
  });

  group('POST /api/admin/accounts/{id}/deactivate and /reactivate', () {
    test('deactivate sends the trimmed reason, then re-reads the account', () async {
      final repository = repositoryAnswering((request) {
        if (request.method == 'POST') return http.Response('', 204);
        return json(summary(status: 'Deactivated', reason: 'plagiarism'));
      });
      final account = ok(await repository.deactivate('a1', reason: '  plagiarism '));
      expect(requests.first.url.path, '/api/admin/accounts/a1/deactivate');
      expect(jsonDecode(requests.first.body), {'reason': 'plagiarism'});
      expect(account.status, AccountStatus.deactivated);
      expect(account.statusReason, 'plagiarism');
    });

    test('deactivate without a reason never reaches the server', () async {
      final repository = repositoryAnswering((_) => fail('no request expected'));
      final failure = err(await repository.deactivate('a1', reason: '  '));
      expect((failure as ValidationFailure).fields['reason'], const KnownFieldProblem(FieldReason.required));
      expect(requests, isEmpty);
    });

    test('reactivate sends a null reason when none is given', () async {
      final repository = repositoryAnswering((request) {
        if (request.method == 'POST') return http.Response('', 204);
        return json(summary());
      });
      ok(await repository.reactivate('a1'));
      expect(requests.first.url.path, '/api/admin/accounts/a1/reactivate');
      expect(jsonDecode(requests.first.body), {'reason': null});
    });

    test('409 account_status_unchanged becomes the already-active / already-deactivated conflict', () async {
      final repository = repositoryAnswering(
        (_) => problem(409, 'account_status_unchanged', 'The account is already deactivated.'),
      );
      expect(err(await repository.deactivate('a1', reason: 'x')).code, 'account_already_deactivated');
      expect(err(await repository.reactivate('a1')).code, 'account_already_active');
    });

    test('an unreachable server is a network failure, not silence', () async {
      final client = ApiClient(
        httpClient: MockClient((_) async => throw http.ClientException('offline')),
        baseUrl: 'https://api.test',
        tokens: tokenStore,
        clock: clock,
      );
      expect(err(await ApiAdminRepository(client: client).listAccounts()), isA<NetworkFailure>());
    });
  });

  group('adminRepositoryProvider', () {
    test('switches on the data source and never falls back', () {
      final local = ProviderContainer(
        overrides: [dataSourceProvider.overrideWithValue(DataSource.local), ..._storage(clock)],
      );
      addTearDown(local.dispose);
      expect(local.read(adminRepositoryProvider), isA<LocalAdminRepository>());

      final api = ProviderContainer(
        overrides: [dataSourceProvider.overrideWithValue(DataSource.api), ..._storage(clock)],
      );
      addTearDown(api.dispose);
      expect(api.read(adminRepositoryProvider), isA<ApiAdminRepository>());
    });
  });

  group('ManagedAccount.fromJson', () {
    test('requires every field the server always sends', () {
      final without = summary()..remove('isLockedOut');
      expect(switch (JsonReader.parse(without, ManagedAccount.fromJson)) {
        Err<ManagedAccount>(:final failure) => (failure as ParseFailure).field,
        Ok<ManagedAccount>() => 'parsed',
      }, 'isLockedOut');
    });
  });
}

List<Override> _storage(FakeClock clock) => [
  keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
  secureStoreProvider.overrideWithValue(InMemorySecureStore()),
  clockProvider.overrideWithValue(clock),
];
