import 'package:examora_app/core/utilities/app_clock.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:meta/meta.dart';

/// An incident the engine decided to raise.
@immutable
final class DetectedIncident {
  /// Creates the record.
  const DetectedIncident({required this.category, required this.occurredAt, this.duration, this.detail});

  /// What kind of incident.
  final IncidentCategory category;

  /// When it began.
  final DateTime occurredAt;

  /// How long it lasted, when that is known.
  final Duration? duration;

  /// A short factual note.
  final String? detail;
}

/// Decides when something that is happening becomes an incident.
///
/// The one rule that matters: a behaviour must PERSIST for the exam's sustained-behaviour threshold (10 seconds unless the
/// instructor changed it) before it counts. The count starts when the behaviour starts and starts over when it stops, so
/// nine separate one-second glances never add up to one incident. A few kinds of incident are instant (a paste attempt, a
/// screenshot, the app leaving the screen) and skip the wait.
///
/// The engine only watches the rules the exam switched on, and only the ones this build can notice at all. It counts every
/// incident as a warning and says once when the exam's warning limit is reached. It knows nothing about marks.
final class IncidentEngine {
  /// Creates the engine.
  IncidentEngine({
    required Set<IncidentCategory> activeRules,
    required this.threshold,
    required this.maxWarnings,
    required this._clock,
    required this.onIncident,
    this.onLimitReached,
    this.repeatGap = const Duration(seconds: 1),
  }) : _rules = {
         for (final rule in activeRules)
           if (rule.hasDetector) rule,
       };

  /// How long a sustained behaviour must last.
  final Duration threshold;

  /// Warnings after which the attempt is flagged.
  final int maxWarnings;

  /// Called for every incident.
  final void Function(DetectedIncident incident) onIncident;

  /// Called once, when the number of warnings reaches [maxWarnings].
  final void Function()? onLimitReached;

  /// The same instant kind of incident twice within this gap counts once (one paste shortcut can be seen by two listeners).
  final Duration repeatGap;

  final Set<IncidentCategory> _rules;
  final AppClock _clock;
  final Map<IncidentCategory, _Episode> _episodes = {};
  final Map<IncidentCategory, DateTime> _lastInstant = {};
  int _warnings = 0;
  bool _limitSaid = false;

  /// How many incidents have been raised.
  int get warnings => _warnings;

  /// True once [warnings] reached [maxWarnings].
  bool get limitReached => _warnings >= maxWarnings;

  /// The rules being watched.
  Set<IncidentCategory> get watching => Set.unmodifiable(_rules);

  /// True while [category] is being watched and is in the middle of a behaviour.
  bool isBehaving(IncidentCategory category) => _episodes.containsKey(category);

  /// A behaviour began. For a sustained category the count starts now; for an instant one the incident is raised now.
  /// Calling it again while the behaviour continues changes nothing (it does not restart the count).
  void behaviourStarted(IncidentCategory category, {String? detail}) {
    if (!_rules.contains(category)) return;
    if (category.immediate) {
      event(category, detail: detail);
      return;
    }
    _episodes.putIfAbsent(category, () => _Episode(_clock.now(), detail));
  }

  /// The behaviour stopped. If it had lasted long enough without anyone checking, it counts now; either way the count
  /// starts over for next time.
  void behaviourStopped(IncidentCategory category) {
    _check(category);
    _episodes.remove(category);
  }

  /// Looks at every running behaviour. Call it about once a second.
  void tick() {
    for (final category in _episodes.keys.toList()) {
      _check(category);
    }
  }

  /// Something instant happened (optionally having lasted [duration]). Ignored if the rule is off.
  void event(IncidentCategory category, {Duration? duration, String? detail}) {
    if (!_rules.contains(category)) return;
    final now = _clock.now();
    final last = _lastInstant[category];
    if (last != null && now.difference(last) < repeatGap) return;
    _lastInstant[category] = now;
    _raise(
      DetectedIncident(
        category: category,
        occurredAt: now.subtract(duration ?? Duration.zero),
        duration: duration,
        detail: detail,
      ),
    );
  }

  void _check(IncidentCategory category) {
    final episode = _episodes[category];
    if (episode == null || episode.fired) return;
    final elapsed = _clock.now().difference(episode.since);
    if (elapsed < threshold) return;
    episode.fired = true;
    _raise(DetectedIncident(category: category, occurredAt: episode.since, duration: elapsed, detail: episode.detail));
  }

  void _raise(DetectedIncident incident) {
    _warnings++;
    onIncident(incident);
    if (limitReached && !_limitSaid) {
      _limitSaid = true;
      onLimitReached?.call();
    }
  }
}

final class _Episode {
  _Episode(this.since, this.detail);

  final DateTime since;
  final String? detail;
  bool fired = false;
}
