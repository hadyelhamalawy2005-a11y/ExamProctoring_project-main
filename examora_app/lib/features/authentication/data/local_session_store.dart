import 'dart:convert';

import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:meta/meta.dart';

/// A stored sign-in: which account, and when it stops being valid.
@immutable
final class StoredSession {
  /// Creates a session.
  const StoredSession({required this.accountId, required this.expiresAt});

  /// Reads a session.
  factory StoredSession.fromJson(JsonReader json) =>
      StoredSession(accountId: json.string('accountId'), expiresAt: json.dateTime('expiresAt'));

  /// The signed-in account.
  final String accountId;

  /// When the session ends (UTC). Sessions last 12 hours.
  final DateTime expiresAt;

  /// The stored form. It holds no password and no token: only who and until when.
  Map<String, Object?> toJson() => {'accountId': accountId, 'expiresAt': expiresAt.toUtc().toIso8601String()};
}

/// Keeps the current session in secure storage.
final class LocalSessionStore {
  /// Creates the store.
  const LocalSessionStore(this._store);

  static const String _key = 'local.session.v1';

  /// How long a session lasts.
  static const Duration lifetime = Duration(hours: 12);

  final SecureStore _store;

  /// The stored session, or null when there is none or the stored text is unreadable.
  Future<StoredSession?> read() async {
    final text = await _store.read(_key);
    if (text == null) return null;
    try {
      return StoredSession.fromJson(JsonReader.of(jsonDecode(text)));
    } on JsonParseException {
      await _store.delete(_key);
      return null;
    } on FormatException {
      await _store.delete(_key);
      return null;
    }
  }

  /// Stores [session].
  Future<void> write(StoredSession session) => _store.write(_key, jsonEncode(session.toJson()));

  /// Forgets the session.
  Future<void> clear() => _store.delete(_key);
}
