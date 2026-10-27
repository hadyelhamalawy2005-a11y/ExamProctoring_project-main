import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/network/api_client.dart';
import 'package:examora_app/core/network/missing_endpoints.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/features/administration/domain/admin_repository.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';

/// Account administration against the Examora HTTP API (`AdminAccountsController`, route `api/admin`).
///
/// Endpoints used, all of which exist: `GET /accounts`, `GET /accounts/{id}`, `POST /instructors`,
/// `POST /accounts/{id}/temporary-password`, `POST /accounts/{id}/deactivate`, `POST /accounts/{id}/reactivate`.
/// Creating a STUDENT has no endpoint (students sign themselves up on the server today, which this app does not offer), so
/// that call is refused with [MissingEndpoints.createStudentAccount] and never falls back to local data.
final class ApiAdminRepository implements AdminRepository {
  /// Creates the repository.
  const ApiAdminRepository({required this._client});

  final ApiClient _client;

  @override
  Future<Result<AccountPage>> listAccounts({
    UserRole? role,
    AccountStatus? status,
    int page = 1,
    int pageSize = AdminRepository.defaultPageSize,
  }) async {
    final response = await _client.get(
      '/api/admin/accounts',
      query: {
        if (role != null) 'role': role.wireName,
        if (status != null) 'status': status.wireName,
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    return _parse(response, AccountPage.fromJson);
  }

  @override
  Future<Result<ManagedAccount>> getAccount(String id) async {
    final response = await _client.get('/api/admin/accounts/${Uri.encodeComponent(id)}');
    return _parse(response, ManagedAccount.fromJson);
  }

  @override
  Future<Result<IssuedPassword>> createAccount({
    required UserRole role,
    required String fullName,
    required String email,
  }) async {
    switch (role) {
      case UserRole.student:
        return MissingEndpoints.createStudentAccount.refuse();
      case UserRole.administrator:
        return const Err(ForbiddenFailure(message: 'Administrator accounts cannot be created here.'));
      case UserRole.instructor:
        break;
    }
    final fields = <String, FieldProblem>{
      'fullName': ?Validators.fullName(fullName),
      'email': ?Validators.email(email),
    };
    if (fields.isNotEmpty) return Err(ValidationFailure(fields: fields));

    final response = await _client.post(
      '/api/admin/instructors',
      body: {'fullName': fullName.trim(), 'email': Validators.normalizeEmail(email)},
    );
    return _parse(
      response,
      (json) => IssuedPassword(
        email: json.string('email'),
        fullName: json.string('fullName'),
        temporaryPassword: json.string('temporaryPassword'),
        expiresAt: json.dateTime('temporaryPasswordExpiresAt'),
      ),
    );
  }

  @override
  Future<Result<IssuedPassword>> issueTemporaryPassword(String accountId) async {
    // The reply carries only the password and its expiry, so the person is read first to name who it is for.
    final account = await getAccount(accountId);
    switch (account) {
      case Err<ManagedAccount>(:final failure):
        return Err(failure);
      case Ok<ManagedAccount>(value: final person):
        final response = await _client.post('/api/admin/accounts/${Uri.encodeComponent(accountId)}/temporary-password');
        return _parse(
          response,
          (json) => IssuedPassword(
            email: person.email,
            fullName: person.fullName,
            temporaryPassword: json.string('temporaryPassword'),
            expiresAt: json.dateTime('temporaryPasswordExpiresAt'),
          ),
        );
    }
  }

  @override
  Future<Result<ManagedAccount>> deactivate(String accountId, {required String reason}) async {
    final problem = Validators.statusReason(reason, required: true);
    if (problem != null) return Err(ValidationFailure(fields: {'reason': problem}));
    return _changeStatus(accountId, 'deactivate', reason.trim(), 'account_already_deactivated');
  }

  @override
  Future<Result<ManagedAccount>> reactivate(String accountId, {String? reason}) async {
    final problem = Validators.statusReason(reason ?? '', required: false);
    if (problem != null) return Err(ValidationFailure(fields: {'reason': problem}));
    final trimmed = reason?.trim();
    return _changeStatus(
      accountId,
      'reactivate',
      trimmed == null || trimmed.isEmpty ? null : trimmed,
      'account_already_active',
    );
  }

  /// The status endpoints answer with an empty success, so the account is read again to show its new state.
  Future<Result<ManagedAccount>> _changeStatus(
    String accountId,
    String action,
    String? reason,
    String unchangedCode,
  ) async {
    final id = Uri.encodeComponent(accountId);
    final response = await _client.post('/api/admin/accounts/$id/$action', body: {'reason': reason});
    switch (response) {
      case Err<Object?>(:final failure):
        if (failure is ConflictFailure && failure.code == 'account_status_unchanged') {
          return Err(ConflictFailure(code: unchangedCode, serverDetail: failure.serverDetail));
        }
        return Err(failure);
      case Ok<Object?>():
        return getAccount(accountId);
    }
  }

  Result<T> _parse<T>(Result<Object?> response, T Function(JsonReader reader) build) => switch (response) {
    Ok<Object?>(:final value) => JsonReader.parse<T>(value, build),
    Err<Object?>(:final failure) => Err<T>(failure),
  };
}
