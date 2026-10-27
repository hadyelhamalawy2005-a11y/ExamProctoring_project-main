import 'dart:async';

import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';

/// Something a face, gaze or speech model would report.
class DetectorEvent {
  /// Creates an event.
  const DetectorEvent({required this.category, required this.active});

  /// gazeAway, faceAbsent, multipleFaces or speechDetected.
  final IncidentCategory category;

  /// True while it is happening.
  final bool active;
}

/// The face, gaze and speech detectors. NO such detector exists in this build, so the only implementation is
/// [NullDetectorSuite], which produces nothing. A rule that depends on it is switched off and says so; nothing here may be
/// presented as an AI detector that works.
abstract interface class DetectorSuite {
  /// True only when a real model is running. Always false in this build.
  bool get isActive;

  /// What the detectors see. Empty in this build.
  Stream<DetectorEvent> get events;
}

/// A suite with no detectors: it never reports anything and says it is inactive.
final class NullDetectorSuite implements DetectorSuite {
  /// Creates the suite.
  const NullDetectorSuite();

  @override
  bool get isActive => false;

  @override
  Stream<DetectorEvent> get events => const Stream<DetectorEvent>.empty();
}

/// The result of asking for the seconds of video before an incident.
sealed class EvidenceCapture {
  const EvidenceCapture();
}

/// There is no recording, for a stated reason.
final class EvidenceNotAvailable extends EvidenceCapture {
  /// Creates the result.
  const EvidenceNotAvailable(this.gap);

  /// Why.
  final EvidenceGap gap;
}

/// A recording exists at [reference].
final class EvidenceRecorded extends EvidenceCapture {
  /// Creates the result.
  const EvidenceRecorded(this.reference);

  /// Where the recording is.
  final String reference;
}

/// The retrospective video buffer.
///
/// Recording the seconds BEFORE an incident needs a circular buffer in the platform's own video encoder (Android MediaCodec,
/// iOS AVAssetWriter); no Flutter camera plugin offers it. So the only implementation here is [UnavailableEvidenceBuffer],
/// which always says "unavailable". It never produces a clip or a reference.
abstract interface class EvidenceBuffer {
  /// Asks for the [seconds] of video before [incidentAt].
  Future<EvidenceCapture> captureBefore(DateTime incidentAt, {required int seconds});
}

/// A buffer that cannot record, and says so.
final class UnavailableEvidenceBuffer implements EvidenceBuffer {
  /// Creates the buffer.
  const UnavailableEvidenceBuffer();

  @override
  Future<EvidenceCapture> captureBefore(DateTime incidentAt, {required int seconds}) async =>
      const EvidenceNotAvailable(EvidenceGap.noRetroactiveCapture);
}

/// What the platform could do to protect the exam screen.
class GuardStatus {
  /// Creates the status.
  const GuardStatus({required this.screenshotsBlocked, required this.screenshotsDetected});

  /// Nothing available (web, desktop, a build without the native part).
  static const GuardStatus none = GuardStatus(screenshotsBlocked: false, screenshotsDetected: false);

  /// The screen cannot be captured (Android FLAG_SECURE).
  final bool screenshotsBlocked;

  /// A screenshot or a screen recording is reported to the app.
  final bool screenshotsDetected;
}

/// The platform part of proctoring: blocking screenshots and hearing about them.
abstract interface class PlatformGuard {
  /// Turns protection on for the exam screen and reports what is really in force.
  Future<GuardStatus> enable();

  /// Turns it off again (when the exam is over).
  Future<void> disable();

  /// Screenshot or recording notices from the platform.
  Stream<void> get screenshotEvents;
}

/// A guard for platforms that have no protection to offer.
final class NoPlatformGuard implements PlatformGuard {
  /// Creates the guard.
  const NoPlatformGuard();

  @override
  Future<GuardStatus> enable() async => GuardStatus.none;

  @override
  Future<void> disable() async {}

  @override
  Stream<void> get screenshotEvents => const Stream<void>.empty();
}

/// Tells whether the device is online.
abstract interface class ConnectivitySource {
  /// The current state.
  Future<bool> isOnline();

  /// Changes in state.
  Stream<bool> get changes;
}
