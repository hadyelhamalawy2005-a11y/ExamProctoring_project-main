import 'package:examora_app/core/errors/app_failure.dart';

/// Field rules shared by every screen and repository, so the screen and the data layer can never disagree.
abstract final class Validators {
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Why [value] is not a usable email, or null when it is.
  static FieldProblem? email(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const KnownFieldProblem(FieldReason.required);
    if (trimmed.length > 256 || !_email.hasMatch(trimmed)) return const KnownFieldProblem(FieldReason.invalidEmail);
    return null;
  }

  /// A password is required (used where only presence matters, such as sign-in).
  static FieldProblem? requiredPassword(String value) =>
      value.isEmpty ? const KnownFieldProblem(FieldReason.required) : null;

  /// The password policy: at least 8 characters, an uppercase letter, a lowercase letter and a digit.
  static FieldProblem? newPassword(String value) {
    if (value.isEmpty) return const KnownFieldProblem(FieldReason.required);
    final ok =
        value.length >= 8 &&
        RegExp('[A-Z]').hasMatch(value) &&
        RegExp('[a-z]').hasMatch(value) &&
        RegExp('[0-9]').hasMatch(value);
    return ok ? null : const KnownFieldProblem(FieldReason.passwordPolicy);
  }

  /// A required text with an upper limit on its trimmed length.
  static FieldProblem? text(String value, {required int maxLength}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const KnownFieldProblem(FieldReason.required);
    if (trimmed.length > maxLength) return const KnownFieldProblem(FieldReason.tooLong);
    return null;
  }

  /// The longest person name the server accepts.
  static const int fullNameMaxLength = 150;

  /// The longest reason for deactivating or reactivating an account.
  static const int statusReasonMaxLength = 500;

  /// A person's name: required, at most [fullNameMaxLength] characters, no control characters.
  static FieldProblem? fullName(String value) {
    final problem = text(value, maxLength: fullNameMaxLength);
    if (problem != null) return problem;
    if (value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune < 0xa0))) {
      return const KnownFieldProblem(FieldReason.invalidCharacters);
    }
    return null;
  }

  /// The reason for a status change. Required when [required] is true; when it is optional an empty text is fine.
  static FieldProblem? statusReason(String value, {required bool required}) {
    if (!required && value.trim().isEmpty) return null;
    return text(value, maxLength: statusReasonMaxLength);
  }

  /// Normalises an email for comparison: trimmed and lower case.
  static String normalizeEmail(String value) => value.trim().toLowerCase();
}
