/// The source of "now" for the whole app.
///
/// Injected so the exam timer, session expiry and the sustained-behaviour threshold can be tested with a fake clock and
/// no real delays.
abstract interface class AppClock {
  /// The current instant, in UTC.
  DateTime now();
}

/// The real clock.
final class SystemClock implements AppClock {
  /// Creates the system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
