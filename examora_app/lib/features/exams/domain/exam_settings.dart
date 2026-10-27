import 'package:examora_app/core/utilities/json_reader.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:meta/meta.dart';

/// Limits shared by the wizard, the importer and the repositories, so none of them can disagree.
abstract final class ExamLimits {
  /// Longest exam title.
  static const int titleMax = 200;

  /// Longest course name.
  static const int courseNameMax = 120;

  /// Longest description.
  static const int descriptionMax = 2000;

  /// Longest instructions text.
  static const int instructionsMax = 4000;

  /// Shortest exam, in minutes.
  static const int durationMin = 1;

  /// Longest exam, in minutes (the server's limit).
  static const int durationMax = 360;

  /// Longest question text.
  static const int questionTextMax = 4000;

  /// Longest model answer or explanation.
  static const int modelAnswerMax = 4000;

  /// Longest option text.
  static const int optionTextMax = 1000;

  /// Fewest options of a choice question.
  static const int optionsMin = 2;

  /// Most options of a choice question (the server's default maximum).
  static const int optionsMax = 8;

  /// Largest marks for one question.
  static const double marksMax = 9999.99;

  /// Smallest and largest sustained-behaviour threshold, in seconds.
  static const int thresholdMin = 3;

  /// See [thresholdMin].
  static const int thresholdMax = 60;

  /// Smallest and largest evidence buffer, in seconds.
  static const int bufferMin = 1;

  /// See [bufferMin].
  static const int bufferMax = 30;

  /// Fewest and most warnings an exam can allow.
  static const int warningsMin = 1;

  /// See [warningsMin].
  static const int warningsMax = 20;
}

/// How an exam behaves. Every default is stated here, in one place.
@immutable
final class ExamSettings {
  /// Creates settings. Anything not given takes the documented default.
  const ExamSettings({
    this.randomizeQuestions = false,
    this.randomizeOptions = false,
    this.calculatorEnabled = false,
    this.allowBackwardNavigation = true,
    this.showResultImmediately = true,
    this.showExplanations = false,
    this.enabledRules = defaultRules,
    this.sustainedThresholdSeconds = defaultThresholdSeconds,
    this.evidenceBufferSeconds = defaultBufferSeconds,
    this.maxWarnings = defaultMaxWarnings,
  });

  /// Reads settings.
  factory ExamSettings.fromJson(JsonReader json) => ExamSettings(
    randomizeQuestions: json.boolean('randomizeQuestions'),
    randomizeOptions: json.boolean('randomizeOptions'),
    calculatorEnabled: json.boolean('calculatorEnabled'),
    allowBackwardNavigation: json.boolean('allowBackwardNavigation'),
    showResultImmediately: json.boolean('showResultImmediately'),
    showExplanations: json.boolean('showExplanations'),
    enabledRules: {
      for (final name in json.stringList('enabledRules'))
        IncidentCategory.byWireName[name] ??
            (throw JsonParseException('enabledRules', 'has the unrecognised value "$name"')),
    },
    sustainedThresholdSeconds: json.integer('sustainedThresholdSeconds'),
    evidenceBufferSeconds: json.integer('evidenceBufferSeconds'),
    maxWarnings: json.integer('maxWarnings'),
  );

  /// A behaviour must last this many seconds before it becomes an incident (unless its category fires immediately).
  static const int defaultThresholdSeconds = 10;

  /// Seconds of video kept before an incident. The app cannot record this retrospectively; the number is the instructor's
  /// request and is reported as unavailable.
  static const int defaultBufferSeconds = 3;

  /// Warnings after which the attempt is flagged for the instructor (it is not ended and marks never change).
  static const int defaultMaxWarnings = 20;

  /// Every kind of incident this build can actually notice is switched on by default; the others are listed but cannot fire.
  static const Set<IncidentCategory> defaultRules = {
    IncidentCategory.appBackgrounded,
    IncidentCategory.windowFocusLost,
    IncidentCategory.clipboardAttempt,
    IncidentCategory.screenshotDetected,
    IncidentCategory.cameraUnavailable,
    IncidentCategory.networkLost,
  };

  /// Shuffle the order of questions for each student.
  final bool randomizeQuestions;

  /// Shuffle the order of options for each student.
  final bool randomizeOptions;

  /// Offer the scientific calculator.
  final bool calculatorEnabled;

  /// Let students go back to earlier questions.
  final bool allowBackwardNavigation;

  /// Show the result as soon as the exam is submitted.
  final bool showResultImmediately;

  /// Show explanations with the result.
  final bool showExplanations;

  /// The incident categories that are watched.
  final Set<IncidentCategory> enabledRules;

  /// Seconds a sustained behaviour must last.
  final int sustainedThresholdSeconds;

  /// Seconds of evidence requested before an incident.
  final int evidenceBufferSeconds;

  /// Warnings that flag the attempt.
  final int maxWarnings;

  /// A copy with the given changes.
  ExamSettings copyWith({
    bool? randomizeQuestions,
    bool? randomizeOptions,
    bool? calculatorEnabled,
    bool? allowBackwardNavigation,
    bool? showResultImmediately,
    bool? showExplanations,
    Set<IncidentCategory>? enabledRules,
    int? sustainedThresholdSeconds,
    int? evidenceBufferSeconds,
    int? maxWarnings,
  }) => ExamSettings(
    randomizeQuestions: randomizeQuestions ?? this.randomizeQuestions,
    randomizeOptions: randomizeOptions ?? this.randomizeOptions,
    calculatorEnabled: calculatorEnabled ?? this.calculatorEnabled,
    allowBackwardNavigation: allowBackwardNavigation ?? this.allowBackwardNavigation,
    showResultImmediately: showResultImmediately ?? this.showResultImmediately,
    showExplanations: showExplanations ?? this.showExplanations,
    enabledRules: enabledRules ?? this.enabledRules,
    sustainedThresholdSeconds: sustainedThresholdSeconds ?? this.sustainedThresholdSeconds,
    evidenceBufferSeconds: evidenceBufferSeconds ?? this.evidenceBufferSeconds,
    maxWarnings: maxWarnings ?? this.maxWarnings,
  );

  /// The names of the settings that are out of range (empty when all are fine).
  List<String> get invalidFields => [
    if (sustainedThresholdSeconds < ExamLimits.thresholdMin || sustainedThresholdSeconds > ExamLimits.thresholdMax)
      'sustainedThresholdSeconds',
    if (evidenceBufferSeconds < ExamLimits.bufferMin || evidenceBufferSeconds > ExamLimits.bufferMax)
      'evidenceBufferSeconds',
    if (maxWarnings < ExamLimits.warningsMin || maxWarnings > ExamLimits.warningsMax) 'maxWarnings',
  ];

  /// The stored form.
  Map<String, Object?> toJson() => {
    'randomizeQuestions': randomizeQuestions,
    'randomizeOptions': randomizeOptions,
    'calculatorEnabled': calculatorEnabled,
    'allowBackwardNavigation': allowBackwardNavigation,
    'showResultImmediately': showResultImmediately,
    'showExplanations': showExplanations,
    'enabledRules': ([for (final rule in enabledRules) rule.wireName]..sort()),
    'sustainedThresholdSeconds': sustainedThresholdSeconds,
    'evidenceBufferSeconds': evidenceBufferSeconds,
    'maxWarnings': maxWarnings,
  };

  @override
  bool operator ==(Object other) =>
      other is ExamSettings &&
      other.randomizeQuestions == randomizeQuestions &&
      other.randomizeOptions == randomizeOptions &&
      other.calculatorEnabled == calculatorEnabled &&
      other.allowBackwardNavigation == allowBackwardNavigation &&
      other.showResultImmediately == showResultImmediately &&
      other.showExplanations == showExplanations &&
      other.enabledRules.length == enabledRules.length &&
      other.enabledRules.containsAll(enabledRules) &&
      other.sustainedThresholdSeconds == sustainedThresholdSeconds &&
      other.evidenceBufferSeconds == evidenceBufferSeconds &&
      other.maxWarnings == maxWarnings;

  @override
  int get hashCode => Object.hash(
    randomizeQuestions,
    randomizeOptions,
    calculatorEnabled,
    allowBackwardNavigation,
    showResultImmediately,
    showExplanations,
    Object.hashAllUnordered(enabledRules),
    sustainedThresholdSeconds,
    evidenceBufferSeconds,
    maxWarnings,
  );
}
