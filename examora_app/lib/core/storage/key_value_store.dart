import 'package:shared_preferences/shared_preferences.dart';

/// Where non-sensitive local data (accounts, exams, attempts, results, incidents, preferences) lives.
///
/// Values are text (JSON). A separate type from [SecureStore] so session material can never be handed to the wrong place
/// by mistake.
abstract interface class KeyValueStore {
  /// The text stored under [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);
}

/// Where session material lives (encrypted by the platform keystore).
abstract interface class SecureStore {
  /// The text stored under [key], or null.
  Future<String?> read(String key);

  /// Stores [value] under [key].
  Future<void> write(String key, String value);

  /// Removes [key].
  Future<void> delete(String key);
}

/// [KeyValueStore] over `shared_preferences`.
final class SharedPreferencesKeyValueStore implements KeyValueStore {
  /// Creates the store.
  const SharedPreferencesKeyValueStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> delete(String key) async {
    await _preferences.remove(key);
  }
}

/// [KeyValueStore] kept in memory. Used by tests, and as an explicit choice for a run that must leave nothing behind.
class InMemoryKeyValueStore implements KeyValueStore {
  /// Creates an empty store.
  InMemoryKeyValueStore([Map<String, String>? initial]) : values = {...?initial};

  /// The stored values, visible so tests can inspect what was written.
  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

/// [SecureStore] kept in memory, for tests.
class InMemorySecureStore implements SecureStore {
  /// Creates an empty store.
  InMemorySecureStore([Map<String, String>? initial]) : values = {...?initial};

  /// The stored values, visible so tests can inspect what was written.
  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
