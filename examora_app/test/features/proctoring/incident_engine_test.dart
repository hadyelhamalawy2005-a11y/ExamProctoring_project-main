import 'dart:ui' show AppLifecycleState;

import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:examora_app/features/proctoring/domain/incident_engine.dart';
import 'package:examora_app/features/proctoring/domain/monitors.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_clock.dart';

void main() {
  late FakeClock clock;
  late List<DetectedIncident> raised;
  late int limitCalls;

  IncidentEngine engine({
    Set<IncidentCategory> rules = const {
      IncidentCategory.windowFocusLost,
      IncidentCategory.networkLost,
      IncidentCategory.clipboardAttempt,
      IncidentCategory.screenshotDetected,
      IncidentCategory.appBackgrounded,
      IncidentCategory.cameraUnavailable,
    },
    int thresholdSeconds = 10,
    int maxWarnings = 20,
  }) => IncidentEngine(
    activeRules: rules,
    threshold: Duration(seconds: thresholdSeconds),
    maxWarnings: maxWarnings,
    clock: clock,
    onIncident: raised.add,
    onLimitReached: () => limitCalls++,
  );

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 10, 27, 9));
    raised = [];
    limitCalls = 0;
  });

  group('the sustained-behaviour threshold', () {
    test('fires AT the threshold, not before', () {
      final e = engine()..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(milliseconds: 9999));
      e.tick();
      expect(raised, isEmpty, reason: '9.999 seconds is not 10');
      clock.advance(const Duration(milliseconds: 1));
      e.tick();
      expect(raised.single.category, IncidentCategory.networkLost);
      expect(raised.single.duration, const Duration(seconds: 10));
    });

    test('the incident is dated when the behaviour BEGAN, not when the threshold was crossed', () {
      final start = clock.now();
      final e = engine()..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 12));
      e.tick();
      expect(raised.single.occurredAt, start);
    });

    test('a behaviour that continues fires ONCE, however long it lasts', () {
      final e = engine()..behaviourStarted(IncidentCategory.networkLost);
      for (var second = 0; second < 60; second++) {
        clock.advance(const Duration(seconds: 1));
        e.tick();
      }
      expect(raised.length, 1);
      expect(e.warnings, 1);
    });

    test('NINE separate one-second glances never add up to an incident', () {
      final e = engine();
      for (var glance = 0; glance < 9; glance++) {
        e.behaviourStarted(IncidentCategory.windowFocusLost);
        clock.advance(const Duration(seconds: 1));
        e.tick();
        e.behaviourStopped(IncidentCategory.windowFocusLost);
        clock.advance(const Duration(seconds: 1)); // a second of looking at the screen again
        e.tick();
      }
      expect(raised, isEmpty);
      expect(e.warnings, 0);
    });

    test('even twenty glances of nine seconds each never add up: the count starts over every time', () {
      final e = engine();
      for (var glance = 0; glance < 20; glance++) {
        e.behaviourStarted(IncidentCategory.windowFocusLost);
        clock.advance(const Duration(seconds: 9));
        e.tick();
        e.behaviourStopped(IncidentCategory.windowFocusLost);
      }
      expect(raised, isEmpty);
    });

    test('the count starts when the behaviour starts again after a stop', () {
      final e = engine()..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 6));
      e.behaviourStopped(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 100));
      e.behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 6));
      e.tick();
      expect(raised, isEmpty, reason: '6 + 6 is not 10: the first six seconds were forgotten');
      clock.advance(const Duration(seconds: 4));
      e.tick();
      expect(raised, hasLength(1));
    });

    test('announcing the same behaviour again while it continues does NOT restart the count', () {
      final e = engine()..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 6));
      e.behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 4));
      e.tick();
      expect(raised, hasLength(1));
    });

    test('a behaviour that ended after the threshold, with no tick in between, still counts when it stops', () {
      final e = engine()..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 30)); // the app was frozen, no ticks ran
      e.behaviourStopped(IncidentCategory.networkLost);
      expect(raised.single.duration, const Duration(seconds: 30));
    });

    test('after an incident, a new episode starts fresh and can fire again', () {
      final e = engine()..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 10));
      e.tick();
      e.behaviourStopped(IncidentCategory.networkLost);
      e.behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 9));
      e.tick();
      expect(raised, hasLength(1));
      clock.advance(const Duration(seconds: 1));
      e.tick();
      expect(raised, hasLength(2));
    });

    test('different behaviours are counted separately', () {
      final e = engine()..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 5));
      e.behaviourStarted(IncidentCategory.windowFocusLost);
      clock.advance(const Duration(seconds: 5));
      e.tick();
      expect(raised.map((i) => i.category), [IncidentCategory.networkLost]);
      clock.advance(const Duration(seconds: 5));
      e.tick();
      expect(raised.map((i) => i.category), [IncidentCategory.networkLost, IncidentCategory.windowFocusLost]);
    });

    test('the threshold is the exam\'s own setting', () {
      final short = engine(thresholdSeconds: 3)..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 3));
      short.tick();
      expect(raised, hasLength(1));

      raised.clear();
      final long = engine(thresholdSeconds: 30)..behaviourStarted(IncidentCategory.networkLost);
      clock.advance(const Duration(seconds: 29));
      long.tick();
      expect(raised, isEmpty);
      clock.advance(const Duration(seconds: 1));
      long.tick();
      expect(raised, hasLength(1));
    });
  });

  group('instant categories bypass the threshold', () {
    test('each fires at once', () {
      final e = engine();
      for (final category in [
        IncidentCategory.clipboardAttempt,
        IncidentCategory.screenshotDetected,
        IncidentCategory.appBackgrounded,
        IncidentCategory.cameraUnavailable,
      ]) {
        expect(category.immediate, isTrue, reason: '$category');
        e.event(category);
        clock.advance(const Duration(seconds: 2));
      }
      expect(raised.map((i) => i.category), [
        IncidentCategory.clipboardAttempt,
        IncidentCategory.screenshotDetected,
        IncidentCategory.appBackgrounded,
        IncidentCategory.cameraUnavailable,
      ]);
    });

    test('starting an instant behaviour also fires at once', () {
      engine().behaviourStarted(IncidentCategory.screenshotDetected);
      expect(raised, hasLength(1));
    });

    test('the sustained categories are exactly the ones that need to persist', () {
      expect(
        {
          for (final c in IncidentCategory.values)
            if (!c.immediate) c,
        },
        {
          IncidentCategory.windowFocusLost,
          IncidentCategory.networkLost,
          IncidentCategory.gazeAway,
          IncidentCategory.faceAbsent,
          IncidentCategory.speechDetected,
        },
      );
    });

    test('the same instant incident twice within a second counts once; a second later it counts again', () {
      final e = engine();
      e.event(IncidentCategory.clipboardAttempt);
      clock.advance(const Duration(milliseconds: 400));
      e.event(IncidentCategory.clipboardAttempt);
      expect(raised, hasLength(1));
      clock.advance(const Duration(milliseconds: 700));
      e.event(IncidentCategory.clipboardAttempt);
      expect(raised, hasLength(2));
    });

    test('an instant incident can carry how long it lasted, and is dated when it began', () {
      final e = engine();
      clock.advance(const Duration(seconds: 30));
      e.event(IncidentCategory.appBackgrounded, duration: const Duration(seconds: 20), detail: '20');
      expect(raised.single.duration, const Duration(seconds: 20));
      expect(raised.single.occurredAt, DateTime.utc(2026, 10, 27, 9, 0, 10));
    });
  });

  group('only rules that are on, and that this build can notice, ever fire', () {
    test('a rule the exam did not switch on is ignored', () {
      final e = engine(rules: {IncidentCategory.networkLost});
      e.event(IncidentCategory.clipboardAttempt);
      e.behaviourStarted(IncidentCategory.windowFocusLost);
      clock.advance(const Duration(minutes: 1));
      e.tick();
      expect(raised, isEmpty);
      expect(e.warnings, 0);
    });

    test('the AI rules cannot fire even if the exam lists them: there is no detector', () {
      final e = engine(
        rules: {
          IncidentCategory.gazeAway,
          IncidentCategory.faceAbsent,
          IncidentCategory.multipleFaces,
          IncidentCategory.speechDetected,
          IncidentCategory.deviceInterrupted,
          IncidentCategory.microphoneUnavailable,
        },
      );
      expect(e.watching, isEmpty);
      for (final category in IncidentCategory.values) {
        e.behaviourStarted(category);
        e.event(category);
      }
      clock.advance(const Duration(minutes: 5));
      e.tick();
      expect(raised, isEmpty);
    });
  });

  group('warnings', () {
    test('every incident is one warning, and the limit is announced exactly once', () {
      final e = engine(maxWarnings: 3);
      for (var i = 0; i < 5; i++) {
        e.event(IncidentCategory.clipboardAttempt);
        clock.advance(const Duration(seconds: 2));
      }
      expect(e.warnings, 5);
      expect(e.limitReached, isTrue);
      expect(limitCalls, 1, reason: 'said once, at the third warning');
    });

    test('below the limit nothing is announced', () {
      final e = engine(maxWarnings: 3);
      e.event(IncidentCategory.clipboardAttempt);
      clock.advance(const Duration(seconds: 2));
      e.event(IncidentCategory.clipboardAttempt);
      expect(e.limitReached, isFalse);
      expect(limitCalls, 0);
    });
  });

  group('the app lifecycle (leaving the app is detected, never prevented)', () {
    test('going to the background and coming back raises "app left the foreground" with the time away', () {
      final e = engine();
      final monitor = LifecycleMonitor(engine: e, clock: clock);
      monitor.onState(AppLifecycleState.inactive);
      clock.advance(const Duration(seconds: 1));
      monitor.onState(AppLifecycleState.hidden);
      monitor.onState(AppLifecycleState.paused);
      expect(monitor.isAway, isTrue);
      clock.advance(const Duration(seconds: 14));
      monitor.onState(AppLifecycleState.resumed);
      final incident = raised.single;
      expect(incident.category, IncidentCategory.appBackgrounded);
      expect(incident.duration, const Duration(seconds: 14), reason: 'measured from when the app left the screen');
      expect(monitor.isAway, isFalse);
    });

    test('a short pause of the window (a notification shade) is not an incident', () {
      final e = engine();
      final monitor = LifecycleMonitor(engine: e, clock: clock);
      monitor.onState(AppLifecycleState.inactive);
      clock.advance(const Duration(seconds: 2));
      monitor.onState(AppLifecycleState.resumed);
      expect(raised, isEmpty);
    });

    test('the window staying unfocused for the whole threshold (split screen) is "window lost focus"', () {
      final e = engine();
      final monitor = LifecycleMonitor(engine: e, clock: clock);
      monitor.onState(AppLifecycleState.inactive);
      clock.advance(const Duration(seconds: 10));
      e.tick();
      expect(raised.single.category, IncidentCategory.windowFocusLost);
    });

    test('each trip away is its own incident', () {
      final e = engine();
      final monitor = LifecycleMonitor(engine: e, clock: clock);
      for (var trip = 0; trip < 3; trip++) {
        monitor.onState(AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 5));
        monitor.onState(AppLifecycleState.resumed);
        clock.advance(const Duration(seconds: 5));
      }
      expect(raised.where((i) => i.category == IncidentCategory.appBackgrounded), hasLength(3));
    });

    test('resuming when the app never left raises nothing', () {
      final e = engine();
      LifecycleMonitor(engine: e, clock: clock).onState(AppLifecycleState.resumed);
      expect(raised, isEmpty);
    });
  });

  group('connectivity (losing the network must not end the exam)', () {
    test('a brief drop is not an incident; a lasting one is, and neither ends anything', () {
      final e = engine();
      final monitor = ConnectivityMonitor(e);
      monitor.onChanged(online: false);
      clock.advance(const Duration(seconds: 4));
      e.tick();
      monitor.onChanged(online: true);
      expect(raised, isEmpty);

      monitor.onChanged(online: false);
      clock.advance(const Duration(seconds: 10));
      e.tick();
      expect(raised.single.category, IncidentCategory.networkLost);
      expect(monitor.online, isFalse);
      monitor.onChanged(online: true);
      expect(monitor.online, isTrue);
    });

    test('flapping between online and offline never accumulates', () {
      final e = engine();
      final monitor = ConnectivityMonitor(e);
      for (var i = 0; i < 20; i++) {
        monitor.onChanged(online: false);
        clock.advance(const Duration(seconds: 5));
        monitor.onChanged(online: true);
        clock.advance(const Duration(seconds: 1));
      }
      expect(raised, isEmpty);
    });
  });
}
