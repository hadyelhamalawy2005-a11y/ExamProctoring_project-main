import 'dart:ui' show AppLifecycleState;

import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:examora_app/features/proctoring/domain/incident_engine.dart';

/// Turns the app's lifecycle changes into engine calls. Leaving the app is DETECTED here, never prevented.
///
/// * `inactive` (a split screen, an overlay, the app switcher) starts a "window lost focus" behaviour, which only counts if
///   it lasts as long as the exam's threshold.
/// * `paused` / `hidden` (the app is off screen) ends that, and the time away is measured.
/// * `resumed` raises "app left the foreground" at once, with how long the student was away.
final class LifecycleMonitor {
  /// Creates the monitor.
  LifecycleMonitor({required this._engine, required this._clock});

  final IncidentEngine _engine;
  final AppClock _clock;
  DateTime? _leftAt;

  /// True while the app is off screen.
  bool get isAway => _leftAt != null;

  /// Reports a new lifecycle state.
  void onState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        if (_leftAt == null) _engine.behaviourStarted(IncidentCategory.windowFocusLost);
      case AppLifecycleState.paused || AppLifecycleState.hidden:
        _engine.behaviourStopped(IncidentCategory.windowFocusLost);
        _leftAt ??= _clock.now();
      case AppLifecycleState.resumed:
        _engine.behaviourStopped(IncidentCategory.windowFocusLost);
        final left = _leftAt;
        _leftAt = null;
        if (left != null) {
          final away = _clock.now().difference(left);
          _engine.event(IncidentCategory.appBackgrounded, duration: away, detail: '${away.inSeconds}');
        }
      case AppLifecycleState.detached:
        break;
    }
  }
}

/// Turns the network going and coming back into engine calls. Losing the network NEVER ends the exam; it is only recorded
/// if it lasts as long as the threshold.
final class ConnectivityMonitor {
  /// Creates the monitor.
  ConnectivityMonitor(this._engine);

  final IncidentEngine _engine;
  bool? _online;

  /// The last state reported, or null before the first report.
  bool? get online => _online;

  /// Reports whether the device is online.
  void onChanged({required bool online}) {
    _online = online;
    if (online) {
      _engine.behaviourStopped(IncidentCategory.networkLost);
    } else {
      _engine.behaviourStarted(IncidentCategory.networkLost);
    }
  }
}
