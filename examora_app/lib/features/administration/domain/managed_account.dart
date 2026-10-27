import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:meta/meta.dart';

/// An account as the administrator sees it: everything the account list and detail show, and nothing secret (no password
/// hash, no attempt counter). The wire form is the .NET `AccountSummaryResponse`.
@immutable
final class ManagedAccount {
  /// Creates a managed account.
  const ManagedAccount({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.mustChangePassword,
    required this.isLockedOut,
    required this.createdAt,
    this.temporaryPasswordExpiresAt,
    this.lastLoginAt,
    this.statusChangedAt,
    this.statusReason,
  });

  /// Reads one account. An unrecognised role or status is a parse error.
  factory ManagedAccount.fromJson(JsonReader json) => ManagedAccount(
    id: json.string('id'),
    fullName: json.string('fullName'),
    email: json.string('email'),
    role: json.enumValue('role', UserRole.byWireName),
    status: json.enumValue('accountStatus', AccountStatus.byWireName),
    mustChangePassword: json.boolean('mustChangePassword'),
    temporaryPasswordExpiresAt: json.optionalDateTime('temporaryPasswordExpiresAt'),
    isLockedOut: json.boolean('isLockedOut'),
    createdAt: json.dateTime('createdAt'),
    lastLoginAt: json.optionalDateTime('lastLoginAt'),
    statusChangedAt: json.optionalDateTime('statusChangedAt'),
    statusReason: json.optionalString('statusReason'),
  );

  /// A stable identifier.
  final String id;

  /// The person's name.
  final String fullName;

  /// The sign-in email.
  final String email;

  /// Student or instructor (administrators are never listed).
  final UserRole role;

  /// Whether the account may sign in.
  final AccountStatus status;

  /// True while a temporary password is in use.
  final bool mustChangePassword;

  /// When the temporary password stops working.
  final DateTime? temporaryPasswordExpiresAt;

  /// True while sign-in is locked after too many wrong passwords.
  final bool isLockedOut;

  /// When the account was created.
  final DateTime createdAt;

  /// The last successful sign-in, if any.
  final DateTime? lastLoginAt;

  /// When the status last changed.
  final DateTime? statusChangedAt;

  /// Why the status last changed.
  final String? statusReason;

  @override
  bool operator ==(Object other) =>
      other is ManagedAccount &&
      other.id == id &&
      other.fullName == fullName &&
      other.email == email &&
      other.role == role &&
      other.status == status &&
      other.mustChangePassword == mustChangePassword &&
      other.temporaryPasswordExpiresAt == temporaryPasswordExpiresAt &&
      other.isLockedOut == isLockedOut &&
      other.createdAt == createdAt &&
      other.lastLoginAt == lastLoginAt &&
      other.statusChangedAt == statusChangedAt &&
      other.statusReason == statusReason;

  @override
  int get hashCode => Object.hash(
    id,
    fullName,
    email,
    role,
    status,
    mustChangePassword,
    temporaryPasswordExpiresAt,
    isLockedOut,
    createdAt,
    lastLoginAt,
    statusChangedAt,
    statusReason,
  );
}

/// One page of the account list. [totalCount] counts every matching account, not only this page.
@immutable
final class AccountPage {
  /// Creates a page.
  const AccountPage({required this.items, required this.page, required this.pageSize, required this.totalCount});

  /// Reads a page (the .NET `AccountListResponse`).
  factory AccountPage.fromJson(JsonReader json) => AccountPage(
    items: json.list('items', ManagedAccount.fromJson),
    page: json.integer('page'),
    pageSize: json.integer('pageSize'),
    totalCount: json.integer('totalCount'),
  );

  /// The accounts on this page, newest first.
  final List<ManagedAccount> items;

  /// The page number, starting at 1.
  final int page;

  /// How many accounts a page holds.
  final int pageSize;

  /// How many accounts match in total.
  final int totalCount;

  /// True when more accounts follow this page.
  bool get hasNext => page * pageSize < totalCount;

  /// True when an earlier page exists.
  bool get hasPrevious => page > 1;
}

/// A temporary password the administrator can see exactly once.
///
/// It exists only in memory: it is never stored, never logged ([toString] leaves it out), and the sheet that shows it
/// cannot be reopened.
@immutable
final class IssuedPassword {
  /// Creates the value.
  const IssuedPassword({
    required this.email,
    required this.fullName,
    required this.temporaryPassword,
    required this.expiresAt,
  });

  /// Who it is for.
  final String email;

  /// The person's name.
  final String fullName;

  /// The password itself.
  final String temporaryPassword;

  /// When it stops working.
  final DateTime expiresAt;

  @override
  String toString() => 'IssuedPassword(email: $email, expiresAt: $expiresAt)';
}
