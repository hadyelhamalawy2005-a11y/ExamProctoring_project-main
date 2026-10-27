import 'dart:async';

import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/proctoring/domain/capabilities.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:examora_app/features/proctoring/domain/incident_engine.dart';
import 'package:examora_app/features/proctoring/domain/incident_repositories.dart';
import 'package:examora_app/features/proctoring/domain/monitors.dart';
import 'package:flutter/widgets.dart';

/// Everything that watches one attempt while it is open: the app's lifecycle, the network, the screenshot guard and the
/// answer boxes. It feeds an [IncidentEngine], records each incident through the [IncidentRecorder], and tells the screen so
/// the student is told at once that a warning was recorded.
///
/// Leaving the app is detected, never prevented. Losing the network never ends anything. Nothing here touches a mark.
class ProctoringSession with WidgetsBindingObserver {
  /// Creates the session for [attemptId] under [plan].
  ProctoringSession({
    required this.attemptId,
    required this.plan,
    required this._clock,
    required this._recorder,
    required this._connectivity,
    required this._guard,
    required this.onWarning,
    required this.onLimitReached,
    required this.onConnectivityChanged,
  });

  /// The attempt being watched.
  final String attemptId;

  /// The rules.
  final ProctoringPlan plan;

  /// Called with each incident and the number of warnings so far.
  final void Function(DetectedIncident incident, int warnings) onWarning;

  /// Called once, when the warning limit is reached.
  final void Function() onLimitReached;

  /// Called when the device goes online or offline.
  final void Function({required bool online}) onConnectivityChanged;

  final AppClock _clock;
  final IncidentRecorder _recorder;
  final ConnectivitySource _connectivity;
  final PlatformGuard _guard;

  late final IncidentEngine _engine = IncidentEngine(
    activeRules: plan.activeRules,
    threshold: Duration(seconds: plan.sustainedThresholdSeconds),
    maxWarnings: plan.maxWarnings,
    clock: _clock,
    onIncident: _handle,
    onLimitReached: onLimitReached,
  );
  late final LifecycleMonitor _lifecycle = LifecycleMonitor(engine: _engine, clock: _clock);
  late final ConnectivityMonitor _network = ConnectivityMonitor(_engine);
  StreamSubscription<bool>? _networkSubscription;
  StreamSubscription<void>? _screenshotSubscription;
  Timer? _ticker;
  bool _closed = false;

  /// What the platform could protect, once [start] has run.
  GuardStatus guardStatus = GuardStatus.none;

  /// How many warnings have been recorded.
  int get warnings => _engine.warnings;

  /// Starts watching.
  Future<void> start({required bool cameraMissing}) async {
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _engine.tick());

    if (cameraMissing) _engine.event(IncidentCategory.cameraUnavailable, detail: 'started without a camera');

    final online = await _connectivity.isOnline();
    _network.onChanged(online: online);
    onConnectivityChanged(online: online);
    _networkSubscription = _connectivity.changes.listen((value) {
      _network.onChanged(online: value);
      onConnectivityChanged(online: value);
    });

    guardStatus = await _guard.enable();
    _screenshotSubscription = _guard.screenshotEvents.listen((_) {
      _engine.event(IncidentCategory.screenshotDetected);
    });
  }

  /// A copy, cut, paste or large insertion was refused in an answer box.
  void clipboardAttempt(String detail) => _engine.event(IncidentCategory.clipboardAttempt, detail: detail);

  /// The app was away for a while before this session began (it was closed or in the background and came back).
  void resumedAfter(Duration away) =>
      _engine.event(IncidentCategory.appBackgrounded, duration: away, detail: '${away.inSeconds}');

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_closed) _lifecycle.onState(state);
  }

  void _handle(DetectedIncident incident) {
    onWarning(incident, _engine.warnings);
    // Written in the background: a slow save must never hold up the exam, and a failed one must never end it.
    unawaited(
      _recorder
          .record(
            NewIncident(
              attemptId: attemptId,
              category: incident.category,
              occurredAt: incident.occurredAt,
              durationMs: incident.duration?.inMilliseconds,
              detail: incident.detail,
            ),
          )
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  /// Stops watching and gives the platform guard back.
  ///
  /// Nothing is awaited on the way out: leaving the exam (submitting, running out of time) must never wait on a stream or
  /// a platform call that is slow to answer.
  void close() {
    if (_closed) return;
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    unawaited(_networkSubscription?.cancel());
    unawaited(_screenshotSubscription?.cancel());
    unawaited(_guard.disable());
  }
}
