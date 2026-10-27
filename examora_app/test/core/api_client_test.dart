import 'dart:async';
import 'dart:convert';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/network/api_client.dart';
import 'package:examora_app/core/network/api_tokens.dart';
import 'package:examora_app/core/network/problem_details.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/fake_clock.dart';

const String baseUrl = 'https://api.test';

ApiTokens tokens({String access = 'access-1', String refresh = 'refresh-1', required DateTime expires}) => ApiTokens(
  accessToken: access,
  accessTokenExpiresAt: expires,
  refreshToken: refresh,
  refreshTokenExpiresAt: expires.add(const Duration(days: 7)),
);

Map<String, Object?> tokenJson(String access, String refresh, DateTime expires) => {
  'tokenType': 'Bearer',
  'accessToken': access,
  'accessTokenExpiresAt': expires.toIso8601String(),
  'refreshToken': refresh,
  'refreshTokenExpiresAt': expires.add(const Duration(days: 7)).toIso8601String(),
  'mustChangePassword': false,
  'user': {'id': 'u1', 'fullName': 'A', 'email': 'a@b.cd', 'role': 'Instructor'},
};

http.Response problem(int status, {String? code, String? detail, Map<String, List<String>>? errors}) => http.Response(
  jsonEncode({'status': status, 'code': ?code, 'detail': ?detail, 'errors': ?errors}),
  status,
  headers: {'content-type': 'application/problem+json'},
);

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  late FakeClock clock;
  late InMemorySecureStore secure;
  late ApiTokenStore tokenStore;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 10, 27, 9));
    secure = InMemorySecureStore();
    tokenStore = ApiTokenStore(secure);
  });

  ApiClient clientWith(MockClient mock, {Duration? timeout, String url = baseUrl}) => ApiClient(
    httpClient: mock,
    baseUrl: url,
    tokens: tokenStore,
    clock: clock,
    timeout: timeout ?? ApiClient.defaultTimeout,
  );

  Future<void> signIn({DateTime? expires, String access = 'access-1', String refresh = 'refresh-1'}) =>
      tokenStore.write(
        tokens(access: access, refresh: refresh, expires: expires ?? clock.now().add(const Duration(minutes: 15))),
      );

  group('ProblemDetails', () {
    test('reads detail, code and camelCase field errors', () {
      final parsed = ProblemDetails.fromBody(
        jsonEncode({
          'status': 400,
          'detail': 'One or more fields are invalid.',
          'code': 'validation_failed',
          'errors': {
            'startsAt': ['Start time must be in the future.'],
            'options[1].text': ['Option text is required.'],
          },
        }),
      );
      expect(parsed.status, 400);
      expect(parsed.detail, 'One or more fields are invalid.');
      expect(parsed.code, 'validation_failed');
      expect(parsed.errors['startsAt'], ['Start time must be in the future.']);
      expect(parsed.errors['options[1].text'], ['Option text is required.']);
    });

    test('an unusable body gives an empty problem, never an exception', () {
      for (final body in ['', 'not json', '[1,2]', '<html>502</html>']) {
        final parsed = ProblemDetails.fromBody(body);
        expect(parsed.code, isNull, reason: body);
        expect(parsed.errors, isEmpty, reason: body);
      }
    });
  });

  group('failureFromResponse', () {
    AppFailure map(int status, {String? code, Map<String, List<String>>? errors, String? detail}) =>
        failureFromResponse(status, ProblemDetails(code: code, errors: errors ?? const {}, detail: detail));

    test('maps the API codes to typed failures, whatever the status', () {
      expect(map(401, code: 'invalid_credentials'), isA<InvalidCredentialsFailure>());
      expect(map(401, code: 'account_locked'), isA<AccountLockedFailure>());
      // The API answers a locked change-password with 403, still the same typed failure.
      expect(map(403, code: 'account_locked'), isA<AccountLockedFailure>());
      expect(map(403, code: 'account_deactivated'), isA<AccountDeactivatedFailure>());
      expect(map(403, code: 'temporary_password_expired'), isA<TemporaryPasswordExpiredFailure>());
      expect(map(403, code: 'password_change_required'), isA<PasswordChangeRequiredFailure>());
      expect(map(401, code: 'token_invalid'), isA<SessionExpiredFailure>());
      expect(map(401, code: 'refresh_token_reused'), isA<SessionExpiredFailure>());
    });

    test('maps plain statuses', () {
      expect(map(403), isA<ForbiddenFailure>());
      expect(map(404, code: 'exam_not_found'), isA<NotFoundFailure>());
      expect(
        map(409, code: 'exam_not_editable', detail: 'The exam can no longer be changed in its current state.'),
        isA<ConflictFailure>(),
      );
      expect(map(429), isA<RateLimitedFailure>());
      expect(map(500), isA<ServerFailure>());
      expect(map(503), isA<ServerFailure>());
    });

    test('a 400 keeps the field errors under their camelCase names', () {
      final failure = map(
        400,
        code: 'validation_failed',
        errors: {
          'confirmPassword': ['Passwords do not match.'],
        },
      );
      expect(failure, isA<ValidationFailure>());
      expect(
        (failure as ValidationFailure).fields['confirmPassword'],
        const ServerFieldProblem('Passwords do not match.'),
      );
    });

    test('a conflict keeps the server explanation; a 5xx never does', () {
      final conflict = map(409, code: 'exam_not_publishable', detail: 'The exam has no questions.') as ConflictFailure;
      expect(conflict.serverDetail, 'The exam has no questions.');
      final server = map(500, detail: 'System.InvalidOperationException: secret');
      expect(server.message, isNot(contains('secret')));
      expect(server.toString(), isNot(contains('secret')));
    });
  });

  group('ApiClient requests', () {
    test('sends JSON with the bearer token and decodes the response', () async {
      await signIn();
      late http.BaseRequest seen;
      String? seenBody;
      final client = clientWith(
        MockClient((request) async {
          seen = request;
          seenBody = request.body;
          return json({'ok': true});
        }),
      );

      final result = await client.send(method: 'POST', path: '/api/exams', body: {'title': 'Midterm'});

      expect(result.valueOrNull, {'ok': true});
      expect(seen.method, 'POST');
      expect(seen.url.toString(), '$baseUrl/api/exams');
      expect(seen.headers['Authorization'], 'Bearer access-1');
      expect(seen.headers['Content-Type'], 'application/json');
      expect(seen.headers['Accept'], 'application/json');
      expect(jsonDecode(seenBody!), {'title': 'Midterm'});
    });

    test('query parameters are encoded and a trailing slash on the base URL is harmless', () async {
      await signIn();
      late Uri seen;
      final client = clientWith(
        MockClient((request) async {
          seen = request.url;
          return json({'items': <Object>[]});
        }),
        url: '$baseUrl/',
      );

      await client.get('/api/exams', query: {'status': 'Draft', 'page': '2', 'pageSize': '10'});

      expect(seen.path, '/api/exams');
      expect(seen.queryParameters, {'status': 'Draft', 'page': '2', 'pageSize': '10'});
    });

    test('a 204 and an empty body give null, not an error', () async {
      await signIn();
      final client = clientWith(MockClient((request) async => http.Response('', 204)));
      final result = await client.delete('/api/exams/e1');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('an unauthenticated request carries no Authorization header', () async {
      late http.BaseRequest seen;
      final client = clientWith(
        MockClient((request) async {
          seen = request;
          return json(tokenJson('a', 'r', clock.now().add(const Duration(minutes: 15))));
        }),
      );
      await client.post('/api/auth/login', body: {'email': 'a@b.cd', 'password': 'x'}, authenticated: false);
      expect(seen.headers.containsKey('Authorization'), isFalse);
    });

    test('an authenticated request with no stored session is refused without any request', () async {
      var calls = 0;
      final client = clientWith(
        MockClient((request) async {
          calls++;
          return json({});
        }),
      );
      final result = await client.get('/api/exams');
      expect(result.failureOrNull, isA<SessionExpiredFailure>());
      expect(calls, 0);
    });

    test('with no server address configured it says so and sends nothing', () async {
      var calls = 0;
      final client = clientWith(
        MockClient((request) async {
          calls++;
          return json({});
        }),
        url: '',
      );
      final failure = (await client.get('/api/exams')).failureOrNull;
      expect(failure, isA<UnavailableFailure>());
      expect(calls, 0);
    });

    test('error responses become typed failures with the field errors', () async {
      await signIn();
      final client = clientWith(
        MockClient(
          (request) async => problem(
            400,
            code: 'validation_failed',
            errors: {
              'title': ['Title is required.'],
            },
          ),
        ),
      );
      final failure = (await client.post('/api/exams', body: {})).failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fields['title'], const ServerFieldProblem('Title is required.'));
    });

    test('a connection error is a NetworkFailure', () async {
      await signIn();
      final client = clientWith(MockClient((request) async => throw http.ClientException('connection refused')));
      expect((await client.get('/api/exams')).failureOrNull, isA<NetworkFailure>());
    });

    test('a request that takes too long is a TimeoutFailure', () async {
      await signIn();
      final never = Completer<http.Response>();
      final client = clientWith(MockClient((request) => never.future), timeout: const Duration(milliseconds: 50));
      expect((await client.get('/api/exams')).failureOrNull, isA<TimeoutFailure>());
    });

    test('a successful response that is not JSON is a ParseFailure', () async {
      await signIn();
      final client = clientWith(MockClient((request) async => http.Response('<html>', 200)));
      expect((await client.get('/api/exams')).failureOrNull, isA<ParseFailure>());
    });
  });

  group('ApiClient token refresh', () {
    test('a 401 refreshes once, stores the rotated tokens and retries once with the new token', () async {
      await signIn();
      final seen = <String>[];
      final client = clientWith(
        MockClient((request) async {
          seen.add('${request.method} ${request.url.path} ${request.headers['Authorization'] ?? '-'}');
          if (request.url.path == '/api/auth/refresh') {
            expect(jsonDecode(request.body), {'refreshToken': 'refresh-1'});
            return json(tokenJson('access-2', 'refresh-2', clock.now().add(const Duration(minutes: 15))));
          }
          return request.headers['Authorization'] == 'Bearer access-2'
              ? json({'id': 'e1'})
              : problem(401, code: 'token_invalid', detail: 'A valid access token is required.');
        }),
      );

      final result = await client.get('/api/exams/e1');

      expect(result.valueOrNull, {'id': 'e1'});
      expect(seen, [
        'GET /api/exams/e1 Bearer access-1',
        'POST /api/auth/refresh -',
        'GET /api/exams/e1 Bearer access-2',
      ]);
      final stored = await tokenStore.read();
      expect(stored!.accessToken, 'access-2');
      expect(stored.refreshToken, 'refresh-2');
    });

    test('parallel requests share ONE refresh (tokens rotate, so a second refresh would be reuse)', () async {
      await signIn(expires: clock.now().add(const Duration(seconds: 5))); // inside the 30 s margin
      var refreshes = 0;
      final gate = Completer<void>();
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            refreshes++;
            await gate.future;
            return json(tokenJson('access-2', 'refresh-2', clock.now().add(const Duration(minutes: 15))));
          }
          return json({'path': request.url.path, 'auth': request.headers['Authorization']});
        }),
      );

      final all = Future.wait([client.get('/api/a'), client.get('/api/b'), client.get('/api/c')]);
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      final results = await all;

      expect(refreshes, 1);
      for (final result in results) {
        expect((result.valueOrNull! as Map<String, Object?>)['auth'], 'Bearer access-2');
      }
    });

    test('retries ONLY once: a second 401 after a successful refresh is returned, not looped on', () async {
      await signIn();
      var calls = 0;
      final client = clientWith(
        MockClient((request) async {
          calls++;
          if (request.url.path == '/api/auth/refresh') {
            return json(tokenJson('access-2', 'refresh-2', clock.now().add(const Duration(minutes: 15))));
          }
          return problem(401, code: 'token_invalid');
        }),
      );
      final result = await client.get('/api/exams');
      expect(result.failureOrNull, isA<SessionExpiredFailure>());
      expect(calls, 3); // request, refresh, one retry
    });

    test('a refresh the server rejects ends the session and clears the tokens', () async {
      await signIn();
      final client = clientWith(
        MockClient((request) async {
          if (request.url.path == '/api/auth/refresh') {
            return problem(401, code: 'refresh_token_reused', detail: 'The refresh token was already used.');
          }
          return problem(401, code: 'token_invalid');
        }),
      );
      final result = await client.get('/api/exams');
      expect(result.failureOrNull, isA<SessionExpiredFailure>());
      expect(await tokenStore.read(), isNull);
    });

    test('a rate limit, a server error or no connection during refresh keeps the session', () async {
      for (final response in <http.Response Function()>[
        () => problem(429),
        () => problem(500),
        () => throw http.ClientException('offline'),
      ]) {
        await signIn();
        final client = clientWith(
          MockClient((request) async {
            if (request.url.path == '/api/auth/refresh') return response();
            return problem(401, code: 'token_invalid');
          }),
        );
        final result = await client.get('/api/exams');
        expect(result.isErr, isTrue);
        expect(result.failureOrNull, isNot(isA<SessionExpiredFailure>()));
        expect(await tokenStore.read(), isNotNull, reason: 'the session must survive a temporary failure');
      }
    });

    test('an expiring token that cannot be refreshed right now is still used while it is VALID', () async {
      await signIn(expires: clock.now().add(const Duration(seconds: 10)));
      final seen = <String>[];
      final client = clientWith(
        MockClient((request) async {
          seen.add(request.url.path);
          if (request.url.path == '/api/auth/refresh') return problem(500);
          return json({'ok': true});
        }),
      );
      final result = await client.get('/api/exams');
      expect(result.valueOrNull, {'ok': true});
      expect(seen, ['/api/auth/refresh', '/api/exams']);
    });

    test('an EXPIRED token is never sent, even when the refresh fails temporarily', () async {
      await signIn(expires: clock.now().subtract(const Duration(seconds: 1)));
      final seen = <String>[];
      final client = clientWith(
        MockClient((request) async {
          seen.add(request.url.path);
          return problem(503);
        }),
      );
      final result = await client.get('/api/exams');
      expect(result.failureOrNull, isA<ServerFailure>());
      expect(seen, ['/api/auth/refresh']);
      expect(await tokenStore.read(), isNotNull);
    });
  });

  group('ApiTokenStore', () {
    test('keeps tokens only in secure storage and never prints them', () async {
      await signIn();
      expect(secure.values.keys, ['api.tokens.v1']);
      final stored = (await tokenStore.read())!;
      expect(stored.toString(), isNot(contains('access-1')));
      expect(stored.toString(), isNot(contains('refresh-1')));
    });

    test('unreadable stored tokens are discarded rather than crashing', () async {
      secure.values['api.tokens.v1'] = '{not json';
      expect(await tokenStore.read(), isNull);
      expect(secure.values, isEmpty);
    });
  });
}
