import 'dart:convert';

import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/configuration/data_source.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/network/api_client.dart';
import 'package:examora_app/core/network/api_tokens.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/features/authentication/data/api_auth_repository.dart';
import 'package:examora_app/features/authentication/data/auth_providers.dart';
import 'package:examora_app/features/authentication/data/local_auth_repository.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../support/fake_clock.dart';
import '../../support/test_harness.dart';

/// Pins the exact requests and responses of the Api authentication repository against the real .NET contract
/// (`AuthController`, `TokenResponse`, `MeResponse`). On the day a server is connected these are the tests that say
/// whether it matches.
void main() {
  late FakeClock clock;
  late InMemorySecureStore secure;
  late ApiTokenStore tokenStore;
  late List<http.Request> requests;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 10, 27, 9));
    secure = InMemorySecureStore();
    tokenStore = ApiTokenStore(secure);
    requests = [];
  });

  Map<String, Object?> tokenResponse({
    String role = 'Instructor',
    bool mustChange = false,
    String access = 'access-1',
    String refresh = 'refresh-1',
  }) => {
    'tokenType': 'Bearer',
    'accessToken': access,
    'accessTokenExpiresAt': clock.now().add(const Duration(minutes: 15)).toIso8601String(),
    'refreshToken': refresh,
    'refreshTokenExpiresAt': clock.now().add(const Duration(days: 7)).toIso8601String(),
    'mustChangePassword': mustChange,
    'user': {
      'id': 'f9d3c6e0-0000-0000-0000-000000000001',
      'fullName': 'Dr. Example',
      'email': 'instructor@example.edu',
      'role': role,
    },
  };

  ApiAuthRepository repositoryAnswering(http.Response Function(http.Request request) answer) {
    final client = ApiClient(
      httpClient: MockClient((request) async {
        requests.add(request);
        return answer(request);
      }),
      baseUrl: 'https://api.test',
      tokens: tokenStore,
      clock: clock,
    );
    return ApiAuthRepository(client: client, tokens: tokenStore);
  }

  http.Response ok(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

  http.Response problem(int status, {String? code, String? detail, Map<String, List<String>>? errors}) => http.Response(
    jsonEncode({'status': status, 'code': ?code, 'detail': ?detail, 'errors': ?errors}),
    status,
    headers: {'content-type': 'application/problem+json'},
  );

  Future<void> signedIn() => tokenStore.write(
    ApiTokens(
      accessToken: 'access-1',
      accessTokenExpiresAt: clock.now().add(const Duration(minutes: 15)),
      refreshToken: 'refresh-1',
      refreshTokenExpiresAt: clock.now().add(const Duration(days: 7)),
    ),
  );

  group('signIn', () {
    test('POST /api/auth/login with exactly {email, password} and no bearer token', () async {
      final repository = repositoryAnswering((request) => ok(tokenResponse()));

      final result = await repository.signIn(email: '  Instructor@Example.edu ', password: 'Examora#2026');

      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, '/api/auth/login');
      expect(requests.single.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(requests.single.body), {'email': 'instructor@example.edu', 'password': 'Examora#2026'});
      expect(result.valueOrNull, isA<Account>());
    });

    test('parses TokenResponse into an account and stores the tokens in secure storage only', () async {
      final repository = repositoryAnswering((request) => ok(tokenResponse(mustChange: true)));

      final account = (await repository.signIn(email: 'instructor@example.edu', password: 'x')).valueOrNull!;

      expect(account.role, UserRole.instructor);
      expect(account.fullName, 'Dr. Example');
      expect(account.mustChangePassword, isTrue);
      final stored = await tokenStore.read();
      expect(stored!.accessToken, 'access-1');
      expect(stored.refreshToken, 'refresh-1');
      expect(secure.values.keys, ['api.tokens.v1']);
    });

    test('maps Admin, Instructor and Student role names from the API', () async {
      for (final entry in {
        'Admin': UserRole.administrator,
        'Instructor': UserRole.instructor,
        'Student': UserRole.student,
      }.entries) {
        final repository = repositoryAnswering((request) => ok(tokenResponse(role: entry.key)));
        expect((await repository.signIn(email: 'a@b.cd', password: 'x')).valueOrNull!.role, entry.value);
      }
    });

    test('an unrecognised role from the server is a ParseFailure, never a default role', () async {
      final repository = repositoryAnswering((request) => ok(tokenResponse(role: 'SuperAdmin')));
      final failure = (await repository.signIn(email: 'a@b.cd', password: 'x')).failureOrNull;
      expect(failure, isA<ParseFailure>());
      expect((failure! as ParseFailure).field, 'user.role');
      expect(await tokenStore.read(), isNull, reason: 'nothing may be stored from a payload that could not be trusted');
    });

    test('401 invalid_credentials becomes the same failure the local repository gives', () async {
      final repository = repositoryAnswering(
        (request) => problem(401, code: 'invalid_credentials', detail: 'The email or password is incorrect.'),
      );
      expect((await repository.signIn(email: 'a@b.cd', password: 'x')).failureOrNull, isA<InvalidCredentialsFailure>());
    });

    test('maps account_locked, account_deactivated, temporary_password_expired and 429', () async {
      Future<AppFailure?> failureFor(http.Response response) async =>
          (await repositoryAnswering((request) => response).signIn(email: 'a@b.cd', password: 'x')).failureOrNull;

      expect(await failureFor(problem(401, code: 'account_locked')), isA<AccountLockedFailure>());
      expect(await failureFor(problem(403, code: 'account_deactivated')), isA<AccountDeactivatedFailure>());
      expect(
        await failureFor(problem(403, code: 'temporary_password_expired')),
        isA<TemporaryPasswordExpiredFailure>(),
      );
      expect(await failureFor(problem(429)), isA<RateLimitedFailure>());
    });

    test('blank fields are refused locally and nothing is sent', () async {
      final repository = repositoryAnswering((request) => ok(tokenResponse()));
      final failure = (await repository.signIn(email: '', password: '')).failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect(requests, isEmpty);
    });
  });

  group('restoreSession', () {
    test('with no stored tokens there is no session and no request', () async {
      final repository = repositoryAnswering((request) => ok({}));
      expect((await repository.restoreSession()).valueOrNull, isNull);
      expect(requests, isEmpty);
    });

    test('GET /api/auth/me with the bearer token, parsed as MeResponse', () async {
      await signedIn();
      final repository = repositoryAnswering(
        (request) => ok({
          'id': 'u1',
          'fullName': 'Dr. Example',
          'email': 'a@b.cd',
          'role': 'Student',
          'mustChangePassword': true,
        }),
      );

      final account = (await repository.restoreSession()).valueOrNull!;

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/auth/me');
      expect(requests.single.headers['Authorization'], 'Bearer access-1');
      expect(account.role, UserRole.student);
      expect(account.mustChangePassword, isTrue);
    });

    test('a rejected session means signed out; a network problem is reported, not treated as signed out', () async {
      await signedIn();
      final rejected = repositoryAnswering((request) {
        if (request.url.path == '/api/auth/refresh') return problem(401, code: 'token_invalid');
        return problem(401, code: 'token_invalid');
      });
      expect((await rejected.restoreSession()).valueOrNull, isNull);
      expect((await rejected.restoreSession()).isOk, isTrue);

      await signedIn();
      final down = ApiAuthRepository(
        client: ApiClient(
          httpClient: MockClient((request) async => throw http.ClientException('offline')),
          baseUrl: 'https://api.test',
          tokens: tokenStore,
          clock: clock,
        ),
        tokens: tokenStore,
      );
      expect((await down.restoreSession()).failureOrNull, isA<NetworkFailure>());
      expect(await tokenStore.read(), isNotNull, reason: 'a brief outage must not throw a valid session away');
    });
  });

  group('signOut', () {
    test('POST /api/auth/logout with the refresh token, then forgets the tokens', () async {
      await signedIn();
      final repository = repositoryAnswering((request) => http.Response('', 204));

      await repository.signOut();

      expect(requests.single.url.path, '/api/auth/logout');
      expect(jsonDecode(requests.single.body), {'refreshToken': 'refresh-1'});
      expect(requests.single.headers['Authorization'], 'Bearer access-1');
      expect(await tokenStore.read(), isNull);
    });

    test('signing out always succeeds locally, even when the server is unreachable', () async {
      await signedIn();
      final repository = ApiAuthRepository(
        client: ApiClient(
          httpClient: MockClient((request) async => throw http.ClientException('offline')),
          baseUrl: 'https://api.test',
          tokens: tokenStore,
          clock: clock,
        ),
        tokens: tokenStore,
      );
      await repository.signOut();
      expect(await tokenStore.read(), isNull);
    });
  });

  group('changePassword', () {
    test('POST /api/auth/change-password with {currentPassword, newPassword} and stores the NEW tokens', () async {
      await signedIn();
      final repository = repositoryAnswering(
        (request) => ok(tokenResponse(access: 'access-NEW', refresh: 'refresh-NEW')),
      );

      final account = (await repository.changePassword(
        currentPassword: 'Temp#12345',
        newPassword: 'Newpass123',
      )).valueOrNull!;

      expect(requests.single.url.path, '/api/auth/change-password');
      expect(requests.single.headers['Authorization'], 'Bearer access-1');
      expect(jsonDecode(requests.single.body), {'currentPassword': 'Temp#12345', 'newPassword': 'Newpass123'});
      expect(account.mustChangePassword, isFalse);
      expect((await tokenStore.read())!.refreshToken, 'refresh-NEW');
    });

    test(
      'field errors from the server are kept under their names; a lock is a 403 with the same typed failure',
      () async {
        await signedIn();
        final invalid = repositoryAnswering(
          (request) => problem(
            400,
            code: 'validation_failed',
            errors: {
              'currentPassword': ['The current password is incorrect.'],
            },
          ),
        );
        final failure = (await invalid.changePassword(
          currentPassword: 'wrong',
          newPassword: 'Newpass123',
        )).failureOrNull;
        expect(
          (failure! as ValidationFailure).fields['currentPassword'],
          const ServerFieldProblem('The current password is incorrect.'),
        );

        final locked = repositoryAnswering((request) => problem(403, code: 'account_locked'));
        expect(
          (await locked.changePassword(currentPassword: 'wrong', newPassword: 'Newpass123')).failureOrNull,
          isA<AccountLockedFailure>(),
        );
      },
    );

    test('a weak new password is refused locally and nothing is sent', () async {
      await signedIn();
      final repository = repositoryAnswering((request) => ok(tokenResponse()));
      final failure = (await repository.changePassword(currentPassword: 'x', newPassword: 'weak')).failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect(requests, isEmpty);
    });
  });

  group('provider wiring', () {
    test('the data source decides which implementation the app gets, with no other change', () {
      final env = TestEnvironment();
      expect(env.container().read(authRepositoryProvider), isA<LocalAuthRepository>());
      expect(
        env.container(extra: [dataSourceProvider.overrideWithValue(DataSource.api)]).read(authRepositoryProvider),
        isA<ApiAuthRepository>(),
      );
    });

    test(
      'the Api implementation never falls back to local data: with no server configured it refuses by name',
      () async {
        final env = TestEnvironment();
        final container = env.container(extra: [dataSourceProvider.overrideWithValue(DataSource.api)]);
        final result = await container
            .read(authRepositoryProvider)
            .signIn(email: 'student@examora.app', password: 'Examora#2026');
        expect(
          result.failureOrNull,
          isA<UnavailableFailure>(),
          reason: 'seeded local accounts must NOT sign in through the Api repository',
        );
        expect(env.keyValueStore.values, isEmpty, reason: 'the local store must not even have been touched');
      },
    );

    test('the API client provider is built from the build-time address and shared storage', () {
      final container = TestEnvironment().container();
      expect(container.read(apiClientProvider).baseUrl, isEmpty);
    });
  });
}
