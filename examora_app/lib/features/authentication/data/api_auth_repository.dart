import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/network/api_client.dart';
import 'package:examora_app/core/network/api_tokens.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:examora_app/features/authentication/domain/auth_repository.dart';

/// Authentication against the Examora HTTP API (`AuthController`).
///
/// Every endpoint used here exists in the backend: `POST /api/auth/login`, `/refresh` (inside [ApiClient]), `/logout`,
/// `/change-password` and `GET /api/auth/me`. Tokens go to secure storage and nowhere else.
final class ApiAuthRepository implements AuthRepository {
  /// Creates the repository.
  const ApiAuthRepository({required this._client, required this._tokens});

  final ApiClient _client;
  final ApiTokenStore _tokens;

  @override
  Future<Result<Account>> signIn({required String email, required String password}) async {
    final fields = <String, FieldProblem>{
      'email': ?Validators.email(email),
      'password': ?Validators.requiredPassword(password),
    };
    if (fields.isNotEmpty) return Err(ValidationFailure(fields: fields));

    final response = await _client.post(
      '/api/auth/login',
      body: {'email': Validators.normalizeEmail(email), 'password': password},
      authenticated: false,
    );
    return _storeTokenResponse(response);
  }

  @override
  Future<Result<Account?>> restoreSession() async {
    final tokens = await _tokens.read();
    if (tokens == null) return const Ok(null);

    final response = await _client.get('/api/auth/me');
    switch (response) {
      case Ok<Object?>(:final value):
        return JsonReader.parse<Account?>(value, Account.fromJson);
      case Err<Object?>(:final failure):
        // A rejected session is "signed out"; a network problem is an error the caller must see, so a still-valid session
        // is not thrown away because the server was briefly unreachable.
        if (failure is SessionExpiredFailure) return const Ok(null);
        return Err(failure);
    }
  }

  @override
  Future<void> signOut() async {
    final tokens = await _tokens.read();
    if (tokens != null) {
      // Best effort: ends the server-side session, but the local sign-out below happens whatever the answer.
      await _client.post('/api/auth/logout', body: {'refreshToken': tokens.refreshToken});
    }
    await _tokens.clear();
  }

  @override
  Future<Result<Account>> changePassword({required String currentPassword, required String newPassword}) async {
    final fields = <String, FieldProblem>{
      'currentPassword': ?Validators.requiredPassword(currentPassword),
      'newPassword': ?Validators.newPassword(newPassword),
    };
    if (fields.isNotEmpty) return Err(ValidationFailure(fields: fields));

    final response = await _client.post(
      '/api/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    return _storeTokenResponse(response);
  }

  /// A `TokenResponse` carries the new tokens, the user and `mustChangePassword`.
  Future<Result<Account>> _storeTokenResponse(Result<Object?> response) async {
    switch (response) {
      case Err<Object?>(:final failure):
        return Err(failure);
      case Ok<Object?>(:final value):
        final parsed = JsonReader.parse<(ApiTokens, Account)>(value, (json) {
          final user = json.object('user');
          return (
            ApiTokens.fromJson(json),
            Account.fromJson(user).copyWith(mustChangePassword: json.boolean('mustChangePassword')),
          );
        });
        switch (parsed) {
          case Err<(ApiTokens, Account)>(:final failure):
            return Err(failure);
          case Ok<(ApiTokens, Account)>(:final value):
            final (tokens, account) = value;
            await _tokens.write(tokens);
            return Ok(account);
        }
    }
  }
}
