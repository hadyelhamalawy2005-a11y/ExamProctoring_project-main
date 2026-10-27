/// How serious an incident is.
enum IncidentSeverity {
  /// Probably harmless on its own.
  low('low'),

  /// Worth a look.
  medium('medium'),

  /// Likely a problem.
  high('high'),

  /// Needs attention first.
  critical('critical');

  const IncidentSeverity(this.wireName);

  /// The stored and wire name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, IncidentSeverity> byWireName = {
    'low': IncidentSeverity.low,
    'medium': IncidentSeverity.medium,
    'high': IncidentSeverity.high,
    'critical': IncidentSeverity.critical,
  };
}

/// Where a detection came from. Recorded honestly: an incident never claims a source that did not produce it.
enum DetectionSource {
  /// The app moved to or from the background (Flutter lifecycle).
  appLifecycle('appLifecycle'),

  /// The operating system told the app (focus loss, screenshot, interruption).
  platformApi('platformApi'),

  /// The app's own screen noticed it (a paste into an answer field).
  appUi('appUi'),

  /// A camera or microphone could not be used.
  deviceHardware('deviceHardware'),

  /// The network connection changed.
  connectivity('connectivity'),

  /// A face, gaze or speech model. No such detector exists in this build.
  aiDetector('aiDetector'),

  /// An instructor added it by hand.
  manual('manual');

  const DetectionSource(this.wireName);

  /// The stored and wire name.
  final String wireName;

  /// The accepted names. Anything else is a parse error.
  static const Map<String, DetectionSource> byWireName = {
    'appLifecycle': DetectionSource.appLifecycle,
    'platformApi': DetectionSource.platformApi,
    'appUi': DetectionSource.appUi,
    'deviceHardware': DetectionSource.deviceHardware,
    'connectivity': DetectionSource.connectivity,
    'aiDetector': DetectionSource.aiDetector,
    'manual': DetectionSource.manual,
  };
}

/// Every kind of incident the app knows about, with how it is detected and how serious it is by default.
enum IncidentCategory {
  /// The app went to the background.
  appBackgrounded('appBackgrounded', IncidentSeverity.medium, DetectionSource.appLifecycle, immediate: true),

  /// The app's window lost focus (split screen, an overlay) while still in front.
  windowFocusLost('windowFocusLost', IncidentSeverity.low, DetectionSource.platformApi, immediate: false),

  /// A call, alarm or system dialog interrupted the exam.
  deviceInterrupted('deviceInterrupted', IncidentSeverity.low, DetectionSource.platformApi, immediate: true),

  /// Copy, cut or paste was attempted in an answer field, or a large block of text appeared at once.
  clipboardAttempt('clipboardAttempt', IncidentSeverity.medium, DetectionSource.appUi, immediate: true),

  /// A screenshot or screen recording was detected.
  screenshotDetected('screenshotDetected', IncidentSeverity.high, DetectionSource.platformApi, immediate: true),

  /// The camera could not be used during the exam.
  cameraUnavailable('cameraUnavailable', IncidentSeverity.high, DetectionSource.deviceHardware, immediate: true),

  /// The microphone could not be used during the exam.
  microphoneUnavailable(
    'microphoneUnavailable',
    IncidentSeverity.medium,
    DetectionSource.deviceHardware,
    immediate: true,
  ),

  /// The network connection was lost. The exam continues.
  networkLost('networkLost', IncidentSeverity.low, DetectionSource.connectivity, immediate: false),

  /// The student looked away from the screen. Needs a gaze model: inactive in this build.
  gazeAway('gazeAway', IncidentSeverity.low, DetectionSource.aiDetector, immediate: false),

  /// No face in front of the camera. Needs a face model: inactive in this build.
  faceAbsent('faceAbsent', IncidentSeverity.high, DetectionSource.aiDetector, immediate: false),

  /// More than one face in front of the camera. Needs a face model: inactive in this build.
  multipleFaces('multipleFaces', IncidentSeverity.critical, DetectionSource.aiDetector, immediate: true),

  /// Speech was heard. Needs a speech model: inactive in this build.
  speechDetected('speechDetected', IncidentSeverity.medium, DetectionSource.aiDetector, immediate: false);

  const IncidentCategory(this.wireName, this.defaultSeverity, this.source, {required this.immediate});

  /// The stored and wire name.
  final String wireName;

  /// How serious this kind of incident is unless something says otherwise.
  final IncidentSeverity defaultSeverity;

  /// Where this kind of incident is detected.
  final DetectionSource source;

  /// True when the incident fires the moment it happens. False when the behaviour must last for the exam's
  /// sustained-behaviour threshold first (so a one-second glance is not an incident).
  final bool immediate;

  /// True when only an AI model can detect this. The build has none, so these rules are inactive.
  bool get needsAiDetector => source == DetectionSource.aiDetector;

  /// True when this build has a real way to notice this kind of incident. The others can be listed in an exam's rules but
  /// can never fire, and the screens say so instead of showing them as working:
  ///
  /// * the face, gaze and speech rules need an AI model, and there is none;
  /// * a device interruption (a call, an alarm) cannot be told apart from leaving the app;
  /// * the microphone is never opened during an exam, so its loss cannot be noticed.
  bool get hasDetector => switch (this) {
    IncidentCategory.appBackgrounded ||
    IncidentCategory.windowFocusLost ||
    IncidentCategory.clipboardAttempt ||
    IncidentCategory.screenshotDetected ||
    IncidentCategory.cameraUnavailable ||
    IncidentCategory.networkLost => true,
    IncidentCategory.deviceInterrupted ||
    IncidentCategory.microphoneUnavailable ||
    IncidentCategory.gazeAway ||
    IncidentCategory.faceAbsent ||
    IncidentCategory.multipleFaces ||
    IncidentCategory.speechDetected => false,
  };

  /// The accepted names. Anything else is a parse error.
  static final Map<String, IncidentCategory> byWireName = {for (final value in values) value.wireName: value};
}
