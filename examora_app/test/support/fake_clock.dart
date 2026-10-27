import 'package:examora_app/core/utilities/app_clock.dart';

/// A clock the test moves by hand, so timers and expiry are tested with no real delay.
final class FakeClock implements AppClock {
  /// Starts at [start] (UTC).
  FakeClock([DateTime? start]) : _now = (start ?? DateTime.utc(2026, 10, 27, 9)).toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the clock forward.
  void advance(Duration by) => _now = _now.add(by);

  /// Moves the clock to an exact instant (it may go backwards: that is how a changed device clock is simulated).
  void setTo(DateTime instant) => _now = instant.toUtc();
}
