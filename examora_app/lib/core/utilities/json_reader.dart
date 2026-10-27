import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';

/// Thrown by [JsonReader] when a field is missing or has the wrong type. Names the offending field.
final class JsonParseException implements Exception {
  /// Creates the exception.
  const JsonParseException(this.field, this.problem);

  /// The path of the field, for example `user.role`.
  final String field;

  /// What was wrong, for example `is missing` or `must be a string`.
  final String problem;

  @override
  String toString() => 'JsonParseException($field $problem)';
}

/// Reads one JSON object with every field checked for presence and type.
///
/// Nothing in the app indexes a raw map. A bad payload fails loudly with the name of the field instead of becoming a
/// default value: in particular an unrecognised role is a parse error, so a malformed payload can never give a student
/// instructor privileges.
final class JsonReader {
  JsonReader._(this._map, this._path);

  final Map<String, Object?> _map;
  final String _path;

  /// Wraps [json], which must be a JSON object.
  factory JsonReader.of(Object? json, [String path = '']) {
    if (json is Map<String, Object?>) {
      return JsonReader._(json, path);
    }
    if (json is Map) {
      return JsonReader._(json.map((key, value) => MapEntry(key.toString(), value as Object?)), path);
    }
    throw JsonParseException(path.isEmpty ? '(root)' : path, 'must be an object');
  }

  /// Runs [build] over [json] and turns a [JsonParseException] into an [Err] naming the field.
  static Result<T> parse<T>(Object? json, T Function(JsonReader reader) build) {
    try {
      return Ok<T>(build(JsonReader.of(json)));
    } on JsonParseException catch (error) {
      return Err<T>(ParseFailure(field: error.field, problem: error.problem));
    }
  }

  String _name(String key) => _path.isEmpty ? key : '$_path.$key';

  Object? _raw(String key) => _map[key];

  /// A required string.
  String string(String key) {
    final value = _raw(key);
    if (value == null) throw JsonParseException(_name(key), 'is missing');
    if (value is! String) throw JsonParseException(_name(key), 'must be a string');
    return value;
  }

  /// A string that may be absent or null.
  String? optionalString(String key) {
    final value = _raw(key);
    if (value == null) return null;
    if (value is! String) throw JsonParseException(_name(key), 'must be a string');
    return value;
  }

  /// A required whole number.
  int integer(String key) {
    final value = _raw(key);
    if (value == null) throw JsonParseException(_name(key), 'is missing');
    if (value is int) return value;
    if (value is double && value == value.truncateToDouble()) return value.toInt();
    throw JsonParseException(_name(key), 'must be a whole number');
  }

  /// A whole number that may be absent or null.
  int? optionalInteger(String key) => _raw(key) == null ? null : integer(key);

  /// A required number (whole or fractional).
  double number(String key) {
    final value = _raw(key);
    if (value == null) throw JsonParseException(_name(key), 'is missing');
    if (value is num) return value.toDouble();
    throw JsonParseException(_name(key), 'must be a number');
  }

  /// A number that may be absent or null.
  double? optionalNumber(String key) => _raw(key) == null ? null : number(key);

  /// A required boolean.
  bool boolean(String key) {
    final value = _raw(key);
    if (value == null) throw JsonParseException(_name(key), 'is missing');
    if (value is! bool) throw JsonParseException(_name(key), 'must be true or false');
    return value;
  }

  /// A boolean that may be absent, with an explicit [fallback].
  bool booleanOr(String key, {required bool fallback}) => _raw(key) == null ? fallback : boolean(key);

  /// A required ISO 8601 date-time, returned in UTC.
  DateTime dateTime(String key) {
    final text = string(key);
    final parsed = DateTime.tryParse(text);
    if (parsed == null) throw JsonParseException(_name(key), 'must be an ISO 8601 date-time');
    return parsed.toUtc();
  }

  /// An ISO 8601 date-time that may be absent or null.
  DateTime? optionalDateTime(String key) => _raw(key) == null ? null : dateTime(key);

  /// A required value from a closed set. [wire] maps each accepted text to its value; anything else is a parse error.
  T enumValue<T>(String key, Map<String, T> wire) {
    final text = string(key);
    final value = wire[text];
    if (value == null) {
      throw JsonParseException(_name(key), 'has the unrecognised value "$text"');
    }
    return value;
  }

  /// A required nested object.
  JsonReader object(String key) {
    final value = _raw(key);
    if (value == null) throw JsonParseException(_name(key), 'is missing');
    return JsonReader.of(value, _name(key));
  }

  /// A nested object that may be absent or null.
  JsonReader? optionalObject(String key) => _raw(key) == null ? null : object(key);

  /// A required list whose items are read with [item].
  List<T> list<T>(String key, T Function(JsonReader reader) item) {
    final value = _raw(key);
    if (value == null) throw JsonParseException(_name(key), 'is missing');
    if (value is! List) throw JsonParseException(_name(key), 'must be a list');
    final result = <T>[];
    for (var index = 0; index < value.length; index++) {
      result.add(item(JsonReader.of(value[index], '${_name(key)}[$index]')));
    }
    return result;
  }

  /// A required list of strings.
  List<String> stringList(String key) {
    final value = _raw(key);
    if (value == null) throw JsonParseException(_name(key), 'is missing');
    if (value is! List) throw JsonParseException(_name(key), 'must be a list');
    final result = <String>[];
    for (var index = 0; index < value.length; index++) {
      final entry = value[index];
      if (entry is! String) throw JsonParseException('${_name(key)}[$index]', 'must be a string');
      result.add(entry);
    }
    return result;
  }

  /// True when [key] is present (even if null).
  bool has(String key) => _map.containsKey(key);
}
