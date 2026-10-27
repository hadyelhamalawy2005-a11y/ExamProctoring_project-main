import 'package:examora_app/core/errors/exam_problems.dart';
import 'package:meta/meta.dart';

/// A reason a single form field was refused.
///
/// A closed set of reasons (plus verbatim server text) so the UI can translate each one; nothing is shown as an
/// untranslated code.
@immutable
sealed class FieldProblem {
  /// Creates a field problem.
  const FieldProblem();
}

/// A named reason the app itself detected.
final class KnownFieldProblem extends FieldProblem {
  /// Creates a known problem.
  const KnownFieldProblem(this.reason);

  /// The reason.
  final FieldReason reason;

  @override
  bool operator ==(Object other) => other is KnownFieldProblem && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}

/// A message written by the server (English). Shown as sent, never invented.
final class ServerFieldProblem extends FieldProblem {
  /// Creates a server problem.
  const ServerFieldProblem(this.text);

  /// The server's own text.
  final String text;

  @override
  bool operator ==(Object other) => other is ServerFieldProblem && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// The reasons the app itself can refuse a field.
enum FieldReason {
  /// The field is empty.
  required,

  /// The text is not an email address.
  invalidEmail,

  /// The password does not meet the password policy.
  passwordPolicy,

  /// The confirmation does not equal the new password.
  passwordsDiffer,

  /// The current password is wrong.
  currentPasswordIncorrect,

  /// The new password equals the current one.
  newPasswordSameAsCurrent,

  /// The text is longer than allowed.
  tooLong,

  /// The text contains control characters.
  invalidCharacters,

  /// A number is outside the allowed range.
  outOfRange,

  /// The availability window is shorter than the exam's duration (or closes before it opens).
  windowTooShort,
}

/// Why an operation failed.
///
/// Every failure carries a stable machine [code] and an English [message] that is safe to show; the UI translates by
/// switching exhaustively over the subtypes.
@immutable
sealed class AppFailure {
  /// Creates a failure.
  const AppFailure({required this.code, required this.message});

  /// A stable machine-readable code (the server's `code` extension when there is one).
  final String code;

  /// An English description that is safe to show to a user.
  final String message;

  @override
  String toString() => '$runtimeType($code)';
}

/// One or more fields were refused.
final class ValidationFailure extends AppFailure {
  /// Creates a validation failure.
  const ValidationFailure({
    this.fields = const {},
    super.code = 'validation_failed',
    super.message = 'Some fields are invalid.',
  });

  /// What was wrong, by field name (camelCase, as the server names them).
  final Map<String, FieldProblem> fields;
}

/// The email and password did not match an account. Deliberately the same for a wrong password and an unknown email.
final class InvalidCredentialsFailure extends AppFailure {
  /// Creates the failure.
  const InvalidCredentialsFailure() : super(code: 'invalid_credentials', message: 'Incorrect email or password.');
}

/// The account is locked after too many failed attempts.
final class AccountLockedFailure extends AppFailure {
  /// Creates the failure.
  const AccountLockedFailure()
    : super(
        code: 'account_locked',
        message: 'This account is temporarily locked after too many failed attempts. Try again later.',
      );
}

/// The account was deactivated by an administrator.
final class AccountDeactivatedFailure extends AppFailure {
  /// Creates the failure.
  const AccountDeactivatedFailure()
    : super(code: 'account_deactivated', message: 'This account has been deactivated. Contact your administrator.');
}

/// The temporary password was not used before it expired.
final class TemporaryPasswordExpiredFailure extends AppFailure {
  /// Creates the failure.
  const TemporaryPasswordExpiredFailure()
    : super(
        code: 'temporary_password_expired',
        message: 'The temporary password has expired. Ask an administrator for a new one.',
      );
}

/// The session ended (expired, was revoked, or the account no longer exists).
final class SessionExpiredFailure extends AppFailure {
  /// Creates the failure.
  const SessionExpiredFailure()
    : super(code: 'session_expired', message: 'Your session has ended. Please sign in again.');
}

/// The account must change its password before doing anything else.
final class PasswordChangeRequiredFailure extends AppFailure {
  /// Creates the failure.
  const PasswordChangeRequiredFailure()
    : super(code: 'password_change_required', message: 'You must change your password before continuing.');
}

/// The signed-in role may not do this.
final class ForbiddenFailure extends AppFailure {
  /// Creates the failure.
  const ForbiddenFailure({super.code = 'forbidden', super.message = 'You do not have permission to do this.'});
}

/// The item does not exist (or is not visible to the caller).
final class NotFoundFailure extends AppFailure {
  /// Creates the failure.
  const NotFoundFailure({super.code = 'not_found', super.message = 'The requested item was not found.'});
}

/// The action conflicts with the current state of the data.
final class ConflictFailure extends AppFailure {
  /// Creates the failure.
  const ConflictFailure({
    super.code = 'conflict',
    super.message = 'This action conflicts with the current state.',
    this.serverDetail,
  });

  /// The server's explanation (English), when it gave one.
  final String? serverDetail;
}

/// The device could not reach the server.
final class NetworkFailure extends AppFailure {
  /// Creates the failure.
  const NetworkFailure()
    : super(code: 'network', message: 'Cannot reach the server. Check your connection and try again.');
}

/// The server did not answer in time.
final class TimeoutFailure extends AppFailure {
  /// Creates the failure.
  const TimeoutFailure() : super(code: 'timeout', message: 'The server took too long to respond. Try again.');
}

/// The server answered with a rate limit.
final class RateLimitedFailure extends AppFailure {
  /// Creates the failure.
  const RateLimitedFailure()
    : super(code: 'rate_limited', message: 'Too many attempts. Please wait a minute and try again.');
}

/// The server failed. Its details are never shown: in development they can contain internal exception text.
final class ServerFailure extends AppFailure {
  /// Creates the failure.
  const ServerFailure({this.statusCode})
    : super(code: 'server_error', message: 'The server had a problem. Please try again later.');

  /// The HTTP status, when there was one.
  final int? statusCode;
}

/// Data on this device could not be read or written.
final class StorageFailure extends AppFailure {
  /// Creates the failure.
  const StorageFailure() : super(code: 'storage_error', message: 'Could not read or write data on this device.');
}

/// A payload did not have the expected shape. Names the offending field.
final class ParseFailure extends AppFailure {
  /// Creates the failure.
  const ParseFailure({required this.field, required String problem})
    : super(code: 'parse_error', message: 'The data could not be read: $field $problem.');

  /// The field that was missing or of the wrong type.
  final String field;
}

/// An exam cannot be published yet. Every reason is listed, in the order the instructor should fix them.
final class ExamNotPublishableFailure extends AppFailure {
  /// Creates the failure.
  const ExamNotPublishableFailure(this.problems)
    : super(code: 'exam_not_publishable', message: 'The exam cannot be published yet.');

  /// What stands in the way (never empty).
  final List<PublishProblem> problems;
}

/// A question is not valid. Every problem is listed.
final class QuestionInvalidFailure extends AppFailure {
  /// Creates the failure.
  const QuestionInvalidFailure(this.problems) : super(code: 'question_invalid', message: 'The question is not valid.');

  /// What is wrong (never empty).
  final List<QuestionProblem> problems;
}

/// A Word file was turned away.
final class DocumentRejectedFailure extends AppFailure {
  /// Creates the failure.
  const DocumentRejectedFailure(this.reason)
    : super(code: 'document_rejected', message: 'The file cannot be imported.');

  /// Why.
  final DocumentRejection reason;
}

/// The server endpoint this operation needs has not been built yet.
///
/// Never replaced by local data: the caller must see that the feature does not exist yet.
final class EndpointMissingFailure extends AppFailure {
  /// Creates the failure.
  const EndpointMissingFailure({required this.endpoint, this.reason})
    : super(
        code: 'endpoint_missing',
        message: 'This has not been built yet: the server endpoint it needs does not exist.',
      );

  /// The endpoint that would be needed, for example `POST /api/attempts`.
  final String endpoint;

  /// Why the existing API cannot serve this, when it matters.
  final String? reason;
}

/// A capability that cannot work on this device or in this build (for example the retrospective video buffer).
final class UnavailableFailure extends AppFailure {
  /// Creates the failure.
  const UnavailableFailure({required this.capability, this.because})
    : super(code: 'unavailable', message: 'This capability is not available.');

  /// What is unavailable.
  final String capability;

  /// Why, in plain words.
  final String? because;
}
