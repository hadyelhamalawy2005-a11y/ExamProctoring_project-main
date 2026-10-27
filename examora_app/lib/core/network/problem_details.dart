import 'dart:convert';

import 'package:examora_app/core/errors/app_failure.dart';

/// An RFC 9457 `application/problem+json` body as the Examora API sends it.
///
/// The human-readable text lives in [detail]; [code] is the stable `code` extension; field errors are under [errors],
/// keyed in camelCase (`startsAt`, `options[1].text`, ...). Parsed leniently: an unusable body gives an empty value
/// rather than an exception, because the HTTP status alone still decides the failure.
final class ProblemDetails {
  /// Creates a problem.
  const ProblemDetails({this.status, this.detail, this.code, this.errors = const {}});

  /// The HTTP status echoed in the body, when present.
  final int? status;

  /// The human-readable explanation (English).
  final String? detail;

  /// The stable machine code, for example `exam_not_editable`.
  final String? code;

  /// Field messages by camelCase field name.
  final Map<String, List<String>> errors;

  /// A problem with nothing in it.
  static const ProblemDetails empty = ProblemDetails();

  /// Parses a response body, returning [empty] when it is not a problem document.
  factory ProblemDetails.fromBody(String body) {
    if (body.trim().isEmpty) return empty;
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return empty;
    }
    if (decoded is! Map<String, Object?>) return empty;
    final rawErrors = decoded['errors'];
    final errors = <String, List<String>>{};
    if (rawErrors is Map<String, Object?>) {
      rawErrors.forEach((field, messages) {
        if (messages is List) {
          errors[field] = messages.whereType<String>().toList();
        }
      });
    }
    final status = decoded['status'];
    final detail = decoded['detail'];
    final code = decoded['code'];
    return ProblemDetails(
      status: status is int ? status : null,
      detail: detail is String ? detail : null,
      code: code is String ? code : null,
      errors: errors,
    );
  }

  /// The field errors as [FieldProblem]s carrying the server's own text.
  Map<String, FieldProblem> toFieldProblems() => {
    for (final entry in errors.entries)
      if (entry.value.isNotEmpty) entry.key: ServerFieldProblem(entry.value.join(' ')),
  };
}

/// Turns an HTTP error response into the matching [AppFailure].
///
/// The `code` decides first (the same code can arrive with different statuses, for example `account_locked`), then the
/// status. 5xx details are never kept.
AppFailure failureFromResponse(int status, ProblemDetails problem) {
  switch (problem.code) {
    case 'invalid_credentials':
      return const InvalidCredentialsFailure();
    case 'account_locked':
      return const AccountLockedFailure();
    case 'account_deactivated':
      return const AccountDeactivatedFailure();
    case 'temporary_password_expired':
      return const TemporaryPasswordExpiredFailure();
    case 'password_change_required':
      return const PasswordChangeRequiredFailure();
    case 'token_invalid':
    case 'refresh_token_reused':
      return const SessionExpiredFailure();
  }

  if (status == 400) {
    return ValidationFailure(fields: problem.toFieldProblems());
  }
  if (status == 401) {
    return const SessionExpiredFailure();
  }
  if (status == 403) {
    return ForbiddenFailure(code: problem.code ?? 'forbidden');
  }
  if (status == 404) {
    return NotFoundFailure(code: problem.code ?? 'not_found');
  }
  if (status == 409) {
    return ConflictFailure(code: problem.code ?? 'conflict', serverDetail: problem.detail);
  }
  if (status == 429) {
    return const RateLimitedFailure();
  }
  if (status == 413) {
    return const ValidationFailure(code: 'payload_too_large', message: 'The request is too large.');
  }
  return ServerFailure(statusCode: status);
}
