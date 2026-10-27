import 'dart:convert';

import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:meta/meta.dart';

/// The token pair the Examora API issues on sign-in, refresh and password change.
@immutable
final class ApiTokens {
  /// Creates a token pair.
  const ApiTokens({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  /// Reads the fields of the API's `TokenResponse` (extra fields such as `user` are ignored here).
  factory ApiTokens.fromJson(JsonReader json) => ApiTokens(
    accessToken: json.string('accessToken'),
    accessTokenExpiresAt: json.dateTime('accessTokenExpiresAt'),
    refreshToken: json.string('refreshToken'),
    refreshTokenExpiresAt: json.dateTime('refreshTokenExpiresAt'),
  );

  /// The short-lived bearer token.
  final String accessToken;

  /// When [accessToken] stops working (UTC).
  final DateTime accessTokenExpiresAt;

  /// The rotating refresh token.
  final String refreshToken;

  /// When [refreshToken] stops working (UTC).
  final DateTime refreshTokenExpiresAt;

  /// The wire form, also used to persist the tokens in secure storage.
  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'accessTokenExpiresAt': accessTokenExpiresAt.toUtc().toIso8601String(),
    'refreshToken': refreshToken,
    'refreshTokenExpiresAt': refreshTokenExpiresAt.toUtc().toIso8601String(),
  };

  /// Never prints the tokens.
  @override
  String toString() => 'ApiTokens(expires ${accessTokenExpiresAt.toIso8601String()})';
}

/// Keeps the API's tokens in secure storage, and nowhere else. Tokens are never logged.
final class ApiTokenStore {
  /// Creates the store over [secureStore].
  ApiTokenStore(this._secureStore);

  static const String _key = 'api.tokens.v1';

  final SecureStore _secureStore;

  /// The stored tokens, or null when signed out or when the stored text is unreadable.
  Future<ApiTokens?> read() async {
    final text = await _secureStore.read(_key);
    if (text == null) return null;
    try {
      return ApiTokens.fromJson(JsonReader.of(jsonDecode(text)));
    } on JsonParseException {
      await _secureStore.delete(_key);
      return null;
    } on FormatException {
      await _secureStore.delete(_key);
      return null;
    }
  }

  /// Stores [tokens].
  Future<void> write(ApiTokens tokens) => _secureStore.write(_key, jsonEncode(tokens.toJson()));

  /// Forgets the tokens.
  Future<void> clear() => _secureStore.delete(_key);
}
