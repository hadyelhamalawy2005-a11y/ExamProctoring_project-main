/// The three roles. Nobody picks their own: an administrator creates every account and its role.
enum UserRole {
  /// Takes exams.
  student('Student'),

  /// Creates exams and reviews incidents for the exams they own.
  instructor('Instructor'),

  /// Creates and manages accounts. Cannot be listed, deactivated or created through the app.
  administrator('Admin');

  const UserRole(this.wireName);

  /// The name used on the wire; the same text the Examora API uses for `role`.
  final String wireName;

  /// The accepted wire names. A name that is not in this map is a parse error, never a default role.
  static const Map<String, UserRole> byWireName = {
    'Student': UserRole.student,
    'Instructor': UserRole.instructor,
    'Admin': UserRole.administrator,
  };
}
