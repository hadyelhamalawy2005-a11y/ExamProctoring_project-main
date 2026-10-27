import 'dart:async';
import 'dart:convert';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/network/api_tokens.dart';
import 'package:examora_app/core/network/problem_details.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:http/http.dart' as http;

/// A typed client for the Examora HTTP API.
///
/// Nothing in the app calls it today (every repository uses the device), but it is complete: JSON in and out,
/// RFC 9457 ProblemDetails mapped to typed failures, a timeout on every request, the bearer token attached, and
/// single-flight token refresh with one retry. Tokens rotate on refresh and reuse revokes the session, so only one
/// refresh may run at a time.
final class ApiClient {
  /// Creates a client. [baseUrl] comes from `--dart-define=API_BASE_URL=...` and is empty when unconfigured.
  ApiClient({
    required http.Client httpClient,
    required this.baseUrl,
    required this._tokens,
    required this._clock,
    this.timeout = defaultTimeout,
  }) : _http = httpClient;

  /// How long a request may take before it is abandoned.
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// A token that expires within this window is refreshed before it is used.
  static const Duration refreshMargin = Duration(seconds: 30);

  /// The server address, or empty when none was configured.
  final String baseUrl;

  /// The per-request timeout.
  final Duration timeout;

  final http.Client _http;
  final ApiTokenStore _tokens;
  final AppClock _clock;
  Future<_RefreshOutcome>? _refreshInFlight;

  /// Sends a request and returns the decoded JSON body (null for an empty body or 204).
  ///
  /// With [authenticated] true the bearer token is attached; an expiring token is refreshed first, and a 401 is retried
  /// once after a refresh.
  Future<Result<Object?>> send({
    required String method,
    required String path,
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
  }) async {
    if (baseUrl.isEmpty) {
      return const Err<Object?>(
        UnavailableFailure(
          capability: 'Server connection',
          because: 'No server address was configured. Build with --dart-define=API_BASE_URL=<address>.',
        ),
      );
    }

    if (authenticated) {
      final current = await _tokens.read();
      if (current == null) {
        return const Err<Object?>(SessionExpiredFailure());
      }
      if (current.accessTokenExpiresAt.difference(_clock.now()) < refreshMargin) {
        final outcome = await _refresh();
        switch (outcome) {
          case _Refreshed():
            break;
          case _Rejected():
            return const Err<Object?>(SessionExpiredFailure());
          case _Temporary(:final failure):
            // The refresh could not be attempted right now. The old token may still work, but never an expired one.
            if (!current.accessTokenExpiresAt.isAfter(_clock.now())) {
              return Err<Object?>(failure);
            }
        }
      }
    }

    final first = await _once(method, path, query, body, authenticated);
    if (authenticated && first is Err<Object?> && first.failure is SessionExpiredFailure) {
      final outcome = await _refresh();
      switch (outcome) {
        case _Refreshed():
          return _once(method, path, query, body, authenticated);
        case _Rejected():
          return const Err<Object?>(SessionExpiredFailure());
        case _Temporary(:final failure):
          return Err<Object?>(failure);
      }
    }
    return first;
  }

  /// `GET` [path].
  Future<Result<Object?>> get(String path, {Map<String, String>? query}) =>
      send(method: 'GET', path: path, query: query);

  /// `POST` [path] with a JSON [body].
  Future<Result<Object?>> post(String path, {Object? body, bool authenticated = true}) =>
      send(method: 'POST', path: path, body: body, authenticated: authenticated);

  /// `PUT` [path] with a JSON [body].
  Future<Result<Object?>> put(String path, {Object? body}) => send(method: 'PUT', path: path, body: body);

  /// `DELETE` [path].
  Future<Result<Object?>> delete(String path) => send(method: 'DELETE', path: path);

  /// Runs at most one refresh at a time; concurrent callers share the same one.
  Future<_RefreshOutcome> _refresh() {
    final running = _refreshInFlight;
    if (running != null) return running;
    final started = _runRefresh().whenComplete(() => _refreshInFlight = null);
    _refreshInFlight = started;
    return started;
  }

  Future<_RefreshOutcome> _runRefresh() async {
    final tokens = await _tokens.read();
    if (tokens == null) return const _Rejected();

    final result = await _once('POST', '/api/auth/refresh', null, {'refreshToken': tokens.refreshToken}, false);
    switch (result) {
      case Ok<Object?>(:final value):
        final parsed = JsonReader.parse<ApiTokens>(value, ApiTokens.fromJson);
        switch (parsed) {
          case Ok<ApiTokens>(value: final fresh):
            await _tokens.write(fresh);
            return const _Refreshed();
          case Err<ApiTokens>():
            await _tokens.clear();
            return const _Rejected();
        }
      case Err<Object?>(:final failure):
        // No answer, a rate limit or a server error says nothing about the token: keep the session.
        if (failure is NetworkFailure ||
            failure is TimeoutFailure ||
            failure is RateLimitedFailure ||
            failure is ServerFailure) {
          return _Temporary(failure);
        }
        await _tokens.clear();
        return const _Rejected();
    }
  }

  Future<Result<Object?>> _once(
    String method,
    String path,
    Map<String, String>? query,
    Object? body,
    bool authenticated,
  ) async {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl);
    final uri = base.replace(path: '${base.path}$path', queryParameters: query == null || query.isEmpty ? null : query);

    final request = http.Request(method, uri)..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (authenticated) {
      final tokens = await _tokens.read();
      if (tokens != null) request.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      return const Err<Object?>(TimeoutFailure());
    } on Object {
      // http.ClientException, SocketException, TLS errors and the like: nothing was received.
      return const Err<Object?>(NetworkFailure());
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.statusCode == 204 || response.body.trim().isEmpty) return const Ok<Object?>(null);
      try {
        return Ok<Object?>(jsonDecode(response.body));
      } on FormatException {
        return const Err<Object?>(ParseFailure(field: '(response body)', problem: 'is not valid JSON'));
      }
    }
    return Err<Object?>(failureFromResponse(response.statusCode, ProblemDetails.fromBody(response.body)));
  }
}

sealed class _RefreshOutcome {
  const _RefreshOutcome();
}

final class _Refreshed extends _RefreshOutcome {
  const _Refreshed();
}

final class _Rejected extends _RefreshOutcome {
  const _Rejected();
}

final class _Temporary extends _RefreshOutcome {
  const _Temporary(this.failure);

  final AppFailure failure;
}
