import 'dart:convert';
import 'dart:typed_data';

import 'package:examora_app/core/security/password_hasher.dart';
import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_clock.dart';

String _hex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('PBKDF2-HMAC-SHA256 against the published test vectors', () {
    Uint8List derive(String password, String salt, int iterations) => PasswordHasher.deriveKey(
      password: password,
      salt: Uint8List.fromList(utf8.encode(salt)),
      iterations: iterations,
    );

    test('1 iteration', () {
      expect(_hex(derive('password', 'salt', 1)), '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
    });

    test('2 iterations', () {
      expect(_hex(derive('password', 'salt', 2)), 'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
    });

    test('4096 iterations', () {
      expect(
        _hex(derive('password', 'salt', 4096)),
        'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a',
      );
    });
  });

  group('PasswordHasher', () {
    const hasher = PasswordHasher(iterations: 3, useIsolate: false);

    test('hashes with a salt, so the same password gives different hashes', () async {
      final a = await hasher.hash('Examora#2026');
      final b = await hasher.hash('Examora#2026');
      expect(a, isNot(b));
    });

    test('the stored text never contains the password', () async {
      final stored = await hasher.hash('Examora#2026');
      expect(stored, isNot(contains('Examora')));
      expect(stored, startsWith(r'pbkdf2-sha256$3$'));
    });

    test('verifies the right password and refuses a wrong one', () async {
      final stored = await hasher.hash('Examora#2026');
      expect(await hasher.verify('Examora#2026', stored), isTrue);
      expect(await hasher.verify('Examora#2027', stored), isFalse);
      expect(await hasher.verify('', stored), isFalse);
    });

    test('uses the iteration count stored in the hash, so the cost can be raised later', () async {
      final stored = await const PasswordHasher(iterations: 5, useIsolate: false).hash('Secret1x');
      expect(await const PasswordHasher(iterations: 999, useIsolate: false).verify('Secret1x', stored), isTrue);
    });

    test('a malformed stored hash never matches and never throws', () async {
      for (final bad in [
        '',
        'plain',
        r'pbkdf2-sha256$x$y$z',
        r'pbkdf2-sha256$1$!!$!!',
        r'other$1$AA==$AA==',
        r'pbkdf2-sha256$0$AA==$AA==',
      ]) {
        expect(await hasher.verify('x', bad), isFalse, reason: bad);
      }
    });
  });

  group('stores', () {
    test('KeyValueStore reads back what was written and forgets what was deleted', () async {
      final store = InMemoryKeyValueStore();
      expect(await store.read('a'), isNull);
      await store.write('a', '1');
      expect(await store.read('a'), '1');
      await store.delete('a');
      expect(await store.read('a'), isNull);
    });

    test('SecureStore reads back what was written and forgets what was deleted', () async {
      final store = InMemorySecureStore({'k': 'v'});
      expect(await store.read('k'), 'v');
      await store.delete('k');
      expect(await store.read('k'), isNull);
    });
  });

  group('FakeClock', () {
    test('only moves when told to, forwards or backwards', () {
      final clock = FakeClock(DateTime.utc(2026));
      expect(clock.now(), DateTime.utc(2026));
      clock.advance(const Duration(hours: 2));
      expect(clock.now(), DateTime.utc(2026, 1, 1, 2));
      clock.setTo(DateTime.utc(2025));
      expect(clock.now(), DateTime.utc(2025));
    });
  });
}
