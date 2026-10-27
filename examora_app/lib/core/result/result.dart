import 'package:examora_app/core/errors/app_failure.dart';

/// The outcome of an operation that can fail in an expected way.
///
/// Repositories return this instead of throwing, so Dart's exhaustive `switch` turns a forgotten failure case into a
/// compile error.
sealed class Result<T> {
  /// Creates a result.
  const Result();

  /// True when this holds a value.
  bool get isOk => this is Ok<T>;

  /// True when this holds a failure.
  bool get isErr => this is Err<T>;

  /// The value, or null when this is a failure.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  /// The failure, or null when this holds a value.
  AppFailure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Transforms the value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Chains another fallible step after a successful one.
  Future<Result<R>> andThen<R>(Future<Result<R>> Function(T value) next) async => switch (this) {
    Ok<T>(:final value) => await next(value),
    Err<T>(:final failure) => Err<R>(failure),
  };
}

/// A successful result carrying [value].
final class Ok<T> extends Result<T> {
  /// Creates a successful result.
  const Ok(this.value);

  /// The value produced by the operation.
  final T value;
}

/// A failed result carrying a [failure] written to be shown to a user.
final class Err<T> extends Result<T> {
  /// Creates a failed result.
  const Err(this.failure);

  /// Why the operation failed.
  final AppFailure failure;
}
