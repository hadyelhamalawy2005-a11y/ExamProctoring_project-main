import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Hashes and checks passwords with salted PBKDF2-HMAC-SHA256.
///
/// Only the hash is ever stored, never the password. The stored text is
/// `pbkdf2-sha256$<iterations>$<salt base64>$<hash base64>`, so the cost can be raised later without breaking old hashes.
final class PasswordHasher {
  /// Creates a hasher.
  ///
  /// [iterations] is the PBKDF2 cost. [useIsolate] runs the work off the UI thread (turn it off in tests).
  const PasswordHasher({this.iterations = defaultIterations, this.useIsolate = true});

  /// The cost used in the app. Pure Dart is slower than native code, so this is lower than the 600,000 that OWASP
  /// recommends for native PBKDF2-SHA256; the work runs in a background isolate so the UI does not freeze.
  static const int defaultIterations = 120000;

  static const String _scheme = 'pbkdf2-sha256';
  static const int _saltLength = 16;

  /// The PBKDF2 iteration count used for new hashes.
  final int iterations;

  /// Whether the work runs in a background isolate.
  final bool useIsolate;

  /// Hashes [password] with a fresh random salt.
  Future<String> hash(String password) async {
    final random = Random.secure();
    final salt = Uint8List.fromList(List<int>.generate(_saltLength, (_) => random.nextInt(256)));
    final bytes = await _derive(_Job(password, salt, iterations));
    return '$_scheme\$$iterations\$${base64.encode(salt)}\$${base64.encode(bytes)}';
  }

  /// True when [password] produces [stored]. A malformed [stored] never matches.
  Future<bool> verify(String password, String stored) async {
    final parts = stored.split(r'$');
    if (parts.length != 4 || parts[0] != _scheme) return false;
    final count = int.tryParse(parts[1]);
    if (count == null || count < 1) return false;
    final Uint8List salt;
    final Uint8List expected;
    try {
      salt = base64.decode(parts[2]);
      expected = base64.decode(parts[3]);
    } on FormatException {
      return false;
    }
    final actual = await _derive(_Job(password, salt, count));
    return _constantTimeEquals(actual, expected);
  }

  /// PBKDF2-HMAC-SHA256 (RFC 8018) producing one 32-byte block. Public so the algorithm can be checked against the
  /// published test vectors.
  static Uint8List deriveKey({required String password, required Uint8List salt, required int iterations}) =>
      _run(_Job(password, salt, iterations));

  Future<Uint8List> _derive(_Job job) => useIsolate ? compute(_run, job) : Future<Uint8List>.value(_run(job));

  static bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var index = 0; index < a.length; index++) {
      difference |= a[index] ^ b[index];
    }
    return difference == 0;
  }
}

/// Everything one PBKDF2 run needs (kept as one object so it can cross an isolate boundary).
final class _Job {
  const _Job(this.password, this.salt, this.iterations);

  final String password;
  final Uint8List salt;
  final int iterations;
}

/// PBKDF2 (RFC 8018) with HMAC-SHA256 producing one 32-byte block.
Uint8List _run(_Job job) {
  final hmac = Hmac(sha256, utf8.encode(job.password));
  var u = Uint8List.fromList(hmac.convert([...job.salt, 0, 0, 0, 1]).bytes);
  final result = Uint8List.fromList(u);
  for (var round = 1; round < job.iterations; round++) {
    u = Uint8List.fromList(hmac.convert(u).bytes);
    for (var index = 0; index < result.length; index++) {
      result[index] ^= u[index];
    }
  }
  return result;
}
