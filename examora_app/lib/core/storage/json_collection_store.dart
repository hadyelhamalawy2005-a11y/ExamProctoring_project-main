import 'dart:async';
import 'dart:convert';

import 'package:examora_app/core/storage/key_value_store.dart';
import 'package:examora_app/core/utilities/json_reader.dart';

/// A list of records kept as one JSON document under one key, with every change running one at a time.
///
/// Two overlapping changes can therefore never overwrite each other's write. The list is read fresh for every change, so
/// nothing is cached that could go stale. A record that cannot be parsed makes the whole read fail with a
/// [JsonParseException] naming the field: stored data is never silently skipped.
final class JsonCollectionStore<T> {
  /// Creates the store for the records under [key].
  JsonCollectionStore({required this._store, required this._key, required this._fromJson, required this._toJson});

  final KeyValueStore _store;
  final String _key;
  final T Function(JsonReader reader) _fromJson;
  final Map<String, Object?> Function(T record) _toJson;

  Future<void> _tail = Future<void>.value();

  /// All records, in the order they were stored.
  Future<List<T>> all() => _synchronized(_load);

  /// Runs [change] over the list while no other change can run, then saves the list. What [change] returns is passed
  /// back. If [change] throws, nothing is saved. [change] must not call back into this store (it would wait for itself).
  Future<R> mutate<R>(FutureOr<R> Function(List<T> records) change) => _synchronized(() async {
    final records = await _load();
    final result = await change(records);
    await _store.write(_key, jsonEncode([for (final record in records) _toJson(record)]));
    return result;
  });

  Future<R> _synchronized<R>(Future<R> Function() action) {
    final completer = Completer<R>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<List<T>> _load() async {
    final text = await _store.read(_key);
    if (text == null) return [];
    final decoded = jsonDecode(text);
    if (decoded is! List) throw JsonParseException(_key, 'must be a list');
    return [
      for (var index = 0; index < decoded.length; index++) _fromJson(JsonReader.of(decoded[index], '$_key[$index]')),
    ];
  }
}
