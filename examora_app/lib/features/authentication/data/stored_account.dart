import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:meta/meta.dart';

/// Wraps a value so [StoredAccount.copyWith] can tell "leave it" (null wrapper) from "set it to null" (a wrapper
/// holding null).
@immutable
final class Nullable<T> {
  /// Creates a wrapper.
  const Nullable(this.value);

  /// The new value, possibly null.
  final T? value;
}

/// An account as the device stores it: everything the administrator manages, plus the salted password hash.
///
/// Only the hash is kept, never the password. Exposed to the rest of the app as an [Account] (identity) or as the
/// administrator's managed-account view.
@immutable
final class StoredAccount {
  /// Creates a stored account.
  const StoredAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.passwordHash,
    required this.mustChangePassword,
    required this.status,
    required this.createdAt,
    this.temporaryPasswordExpiresAt,
    this.statusReason,
    this.statusChangedAt,
    this.lastLoginAt,
    this.failedAttempts = 0,
    this.lockoutUntil,
  });

  /// Reads a stored account.
  factory StoredAccount.fromJson(JsonReader json) => StoredAccount(
    id: json.string('id'),
    fullName: json.string('fullName'),
    email: json.string('email'),
    role: json.enumValue('role', UserRole.byWireName),
    passwordHash: json.string('passwordHash'),
    mustChangePassword: json.boolean('mustChangePassword'),
    temporaryPasswordExpiresAt: json.optionalDateTime('temporaryPasswordExpiresAt'),
    status: json.enumValue('accountStatus', AccountStatus.byWireName),
    statusReason: json.optionalString('statusReason'),
    statusChangedAt: json.optionalDateTime('statusChangedAt'),
    createdAt: json.dateTime('createdAt'),
    lastLoginAt: json.optionalDateTime('lastLoginAt'),
    failedAttempts: json.integer('failedAttempts'),
    lockoutUntil: json.optionalDateTime('lockoutUntil'),
  );

  /// A stable identifier.
  final String id;

  /// The person's name.
  final String fullName;

  /// The sign-in email, lower case.
  final String email;

  /// What the person may do.
  final UserRole role;

  /// Salted PBKDF2 hash of the password (never the password).
  final String passwordHash;

  /// True while a temporary password is in use.
  final bool mustChangePassword;

  /// When the temporary password stops working, if there is one.
  final DateTime? temporaryPasswordExpiresAt;

  /// Whether the account may sign in.
  final AccountStatus status;

  /// Why the status last changed (required when deactivating).
  final String? statusReason;

  /// When the status last changed.
  final DateTime? statusChangedAt;

  /// When the account was created.
  final DateTime createdAt;

  /// The last successful sign-in.
  final DateTime? lastLoginAt;

  /// Consecutive wrong passwords since the last success.
  final int failedAttempts;

  /// While in the future, sign-in is refused.
  final DateTime? lockoutUntil;

  /// True when the account is locked at [now].
  bool isLockedAt(DateTime now) => lockoutUntil != null && lockoutUntil!.isAfter(now);

  /// The identity part, for the signed-in session.
  Account toAccount() =>
      Account(id: id, fullName: fullName, email: email, role: role, mustChangePassword: mustChangePassword);

  /// A copy with the given changes.
  StoredAccount copyWith({
    String? passwordHash,
    bool? mustChangePassword,
    Nullable<DateTime>? temporaryPasswordExpiresAt,
    AccountStatus? status,
    Nullable<String>? statusReason,
    Nullable<DateTime>? statusChangedAt,
    Nullable<DateTime>? lastLoginAt,
    int? failedAttempts,
    Nullable<DateTime>? lockoutUntil,
  }) => StoredAccount(
    id: id,
    fullName: fullName,
    email: email,
    role: role,
    passwordHash: passwordHash ?? this.passwordHash,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    temporaryPasswordExpiresAt: temporaryPasswordExpiresAt == null
        ? this.temporaryPasswordExpiresAt
        : temporaryPasswordExpiresAt.value,
    status: status ?? this.status,
    statusReason: statusReason == null ? this.statusReason : statusReason.value,
    statusChangedAt: statusChangedAt == null ? this.statusChangedAt : statusChangedAt.value,
    createdAt: createdAt,
    lastLoginAt: lastLoginAt == null ? this.lastLoginAt : lastLoginAt.value,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    lockoutUntil: lockoutUntil == null ? this.lockoutUntil : lockoutUntil.value,
  );

  /// The stored form.
  Map<String, Object?> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role.wireName,
    'passwordHash': passwordHash,
    'mustChangePassword': mustChangePassword,
    'temporaryPasswordExpiresAt': temporaryPasswordExpiresAt?.toUtc().toIso8601String(),
    'accountStatus': status.wireName,
    'statusReason': statusReason,
    'statusChangedAt': statusChangedAt?.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'lastLoginAt': lastLoginAt?.toUtc().toIso8601String(),
    'failedAttempts': failedAttempts,
    'lockoutUntil': lockoutUntil?.toUtc().toIso8601String(),
  };
}
