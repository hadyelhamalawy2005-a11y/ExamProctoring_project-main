import 'dart:math';

/// Generates temporary passwords for accounts an administrator creates or resets.
///
/// Same rules as the server's generator: 16 characters from a cryptographically secure source, letters and digits only,
/// without the look-alikes 0, O, 1, l and I (they get read aloud or copied by hand), with at least one upper-case letter,
/// one lower-case letter and one digit, so the result always meets the password policy.
abstract final class TemporaryPassword {
  /// How many characters a temporary password has.
  static const int length = 16;

  /// How long a temporary password works.
  static const Duration validity = Duration(hours: 72);

  /// Upper-case letters without O and I.
  static const String upperCase = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

  /// Lower-case letters without l.
  static const String lowerCase = 'abcdefghijkmnopqrstuvwxyz';

  /// Digits without 0 and 1.
  static const String digits = '23456789';

  /// Everything a temporary password may contain.
  static const String alphabet = upperCase + lowerCase + digits;

  /// Makes a new password. [random] defaults to a secure generator; tests pass a seeded one.
  static String generate([Random? random]) {
    final source = random ?? Random.secure();
    String pick(String set) => set[source.nextInt(set.length)];

    final characters = <String>[
      pick(upperCase),
      pick(lowerCase),
      pick(digits),
      for (var index = 3; index < length; index++) pick(alphabet),
    ];
    // Fisher-Yates, so the guaranteed characters are not always at the start.
    for (var index = length - 1; index > 0; index--) {
      final other = source.nextInt(index + 1);
      final swap = characters[index];
      characters[index] = characters[other];
      characters[other] = swap;
    }
    return characters.join();
  }
}
