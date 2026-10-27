import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:meta/meta.dart';

/// The signed-in person, as the app needs to know them.
///
/// The wire form matches the Examora API's `user` object plus `mustChangePassword`, so it does not change when the
/// server arrives.
@immutable
final class Account {
  /// Creates an account.
  const Account({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.mustChangePassword,
  });

  /// Reads an account. An unrecognised `role` is a parse error, never a default.
  factory Account.fromJson(JsonReader json) => Account(
    id: json.string('id'),
    fullName: json.string('fullName'),
    email: json.string('email'),
    role: json.enumValue('role', UserRole.byWireName),
    mustChangePassword: json.booleanOr('mustChangePassword', fallback: false),
  );

  /// A stable identifier.
  final String id;

  /// The person's name, as the administrator typed it.
  final String fullName;

  /// The sign-in email, lower case.
  final String email;

  /// What the person may do.
  final UserRole role;

  /// True while a temporary password is in use: the only reachable screen is "change password".
  final bool mustChangePassword;

  /// The wire form.
  Map<String, Object?> toJson() => {
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role.wireName,
    'mustChangePassword': mustChangePassword,
  };

  /// A copy with the given changes.
  Account copyWith({bool? mustChangePassword}) => Account(
    id: id,
    fullName: fullName,
    email: email,
    role: role,
    mustChangePassword: mustChangePassword ?? this.mustChangePassword,
  );

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.fullName == fullName &&
      other.email == email &&
      other.role == role &&
      other.mustChangePassword == mustChangePassword;

  @override
  int get hashCode => Object.hash(id, fullName, email, role, mustChangePassword);
}
