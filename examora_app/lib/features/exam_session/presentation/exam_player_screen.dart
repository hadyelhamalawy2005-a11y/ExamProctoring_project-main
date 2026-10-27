import 'dart:async';

import 'package:examora_app/app/configuration/app_providers.dart';
import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_dialogs.dart';
import 'package:examora_app/core/widgets/app_error_view.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/data/exam_session_providers.dart';
import 'package:examora_app/features/exam_session/domain/answer.dart';
import 'package:examora_app/features/exam_session/domain/attempt.dart';
import 'package:examora_app/features/exam_session/domain/exam_session_repositories.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exam_session/presentation/calculator_sheet.dart';
import 'package:examora_app/features/exam_session/presentation/guarded_answer_field.dart';
import 'package:examora_app/features/exam_session/presentation/student_queries.dart';
import 'package:examora_app/features/exams/domain/question.dart';
import 'package:examora_app/features/exams/presentation/number_text.dart';
import 'package:examora_app/features/proctoring/data/platform_services.dart';
import 'package:examora_app/features/proctoring/presentation/proctoring_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The exam itself.
///
/// * The time left is always worked out from the attempt's fixed deadline and a clock that never goes backwards; nothing is
///   counted down, so leaving the app, killing it or changing the device clock cannot gain a second.
/// * Every answer is saved the moment it is given. Resuming restores them and does not move the deadline.
/// * At the deadline the saved answers are submitted, once.
/// * Answers refer to option ids, so shuffling the order never changes what an answer means.
class ExamPlayerScreen extends ConsumerStatefulWidget {
  /// Creates the player for [attemptId]. [cameraMissing] is true when the student started without a working camera.
  const ExamPlayerScreen({required this.attemptId, this.cameraMissing = false, super.key});

  /// The attempt.
  final String attemptId;

  /// Whether the camera check found no working camera.
  final bool cameraMissing;

  @override
  ConsumerState<ExamPlayerScreen> createState() => _ExamPlayerScreenState();
}

class _ExamPlayerScreenState extends ConsumerState<ExamPlayerScreen> {
  static const Duration _saveDelay = Duration(milliseconds: 400);
  static const int _heartbeatSeconds = 10;

  StudentAttemptSession? _session;
  AppFailure? _loadFailure;
  AttemptTimer? _timer;
  Timer? _ticker;
  ProctoringSession? _proctoring;
  Map<String, AnswerValue> _answers = {};
  int _index = 0;
  Duration _remaining = Duration.zero;
  bool _submitting = false;
  bool _leaving = false;
  bool _online = true;
  bool _limitReached = false;
  String? _warning;
  AppFailure? _saveFailure;
  int _ticks = 0;
  final Map<String, TextEditingController> _texts = {};
  final Map<String, Timer> _pendingSaves = {};
  AttemptRepository get _attempts => ref.read(attemptRepositoryProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final timer in _pendingSaves.values) {
      timer.cancel();
    }
    for (final controller in _texts.values) {
      controller.dispose();
    }
    _proctoring?.close();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await _attempts.getSession(widget.attemptId);
    if (!mounted) return;
    switch (result) {
      case Err<StudentAttemptSession>(:final failure):
        setState(() => _loadFailure = failure);
      case Ok<StudentAttemptSession>(:final value):
        if (value.status == AttemptStatus.submitted) {
          context.go(RoutePaths.studentAttemptResult(value.attemptId));
          return;
        }
        final clock = ref.read(clockProvider);
        final timer = AttemptTimer(deadline: value.deadline, seenUpTo: value.lastSeenAt);
        setState(() {
          _session = value;
          _answers = {...value.answers};
          _index = value.currentIndex.clamp(0, value.questions.isEmpty ? 0 : value.questions.length - 1);
          _timer = timer;
          _remaining = timer.remaining(clock.now());
        });
        await _startProctoring(value);
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_onTick()));
        if (_remaining == Duration.zero) unawaited(_submit(auto: true));
    }
  }

  Future<void> _startProctoring(StudentAttemptSession session) async {
    final clock = ref.read(clockProvider);
    final proctoring = ProctoringSession(
      attemptId: session.attemptId,
      plan: session.plan,
      clock: clock,
      recorder: ref.read(incidentRecorderProvider),
      connectivity: ref.read(connectivitySourceProvider),
      guard: ref.read(platformGuardProvider),
      onWarning: (incident, count) {
        if (!mounted) return;
        setState(
          () => _warning = context.strings.warningRecorded(
            context.strings.incidentCategoryName(incident.category),
            count,
          ),
        );
      },
      onLimitReached: () {
        if (mounted) setState(() => _limitReached = true);
      },
      onConnectivityChanged: ({required online}) {
        if (mounted) setState(() => _online = online);
      },
    );
    _proctoring = proctoring;
    await proctoring.start(cameraMissing: widget.cameraMissing);
    // The attempt was open before and the app was away from it for a while: that is recorded too.
    final gap = clock.now().difference(session.lastSeenAt);
    if (session.lastSeenAt.isAfter(session.startedAt) && gap > const Duration(seconds: 30)) {
      proctoring.resumedAfter(gap);
    }
  }

  Future<void> _onTick() async {
    final timer = _timer;
    final session = _session;
    if (timer == null || session == null || _submitting || _leaving) return;
    final remaining = timer.remaining(ref.read(clockProvider).now());
    if (!mounted) return;
    setState(() => _remaining = remaining);
    if (remaining == Duration.zero) {
      await _submit(auto: true);
      return;
    }
    _ticks++;
    if (_ticks % _heartbeatSeconds == 0) {
      // Records how far the clock has got, so a rewound device clock cannot give time back after a restart.
      await _attempts.saveProgress(session.attemptId, _index);
    }
  }

  // ---- answers ----

  AnswerValue? _answerFor(StudentQuestion question) => _answers[question.id];

  Future<void> _persist(StudentQuestion question, AnswerValue? answer) async {
    final session = _session;
    if (session == null) return;
    final result = await _attempts.saveAnswer(session.attemptId, question.id, answer);
    if (!mounted) return;
    switch (result) {
      case Ok<void>():
        if (_saveFailure != null) setState(() => _saveFailure = null);
      case Err<void>(:final failure):
        if (failure is ConflictFailure && failure.code == 'attempt_time_over') {
          unawaited(_submit(auto: true));
        } else {
          setState(() => _saveFailure = failure);
        }
    }
  }

  void _setChoice(StudentQuestion question, String optionId) {
    final current = _answers[question.id];
    final selected = current is ChoiceAnswer ? {...current.optionIds} : <String>{};
    if (question.type == QuestionType.singleChoice) {
      selected
        ..clear()
        ..add(optionId);
    } else if (!selected.remove(optionId)) {
      selected.add(optionId);
    }
    final answer = selected.isEmpty ? null : ChoiceAnswer(selected);
    setState(() {
      if (answer == null) {
        _answers.remove(question.id);
      } else {
        _answers[question.id] = answer;
      }
    });
    unawaited(_persist(question, answer));
  }

  void _typed(StudentQuestion question, String text) {
    setState(() => _answers[question.id] = TextAnswer(text));
    _pendingSaves[question.id]?.cancel();
    _pendingSaves[question.id] = Timer(_saveDelay, () {
      _pendingSaves.remove(question.id);
      unawaited(_persist(question, TextAnswer(text)));
    });
  }

  /// Saves any typed answer that is still waiting for its short delay.
  Future<void> _flushTyped() async {
    final session = _session;
    if (session == null) return;
    final waiting = _pendingSaves.keys.toList();
    for (final id in waiting) {
      _pendingSaves.remove(id)?.cancel();
      final answer = _answers[id];
      final question = session.questions.where((q) => q.id == id).firstOrNull;
      if (question != null) await _persist(question, answer);
    }
  }

  void _blocked(String what) {
    _proctoring?.clipboardAttempt(what);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(context.strings.pasteBlocked)));
  }

  // ---- navigation ----

  Future<void> _goTo(int index) async {
    final session = _session;
    if (session == null || index == _index) return;
    await _flushTyped();
    if (!mounted) return;
    setState(() => _index = index.clamp(0, session.questions.length - 1));
    unawaited(_attempts.saveProgress(session.attemptId, _index));
  }

  Future<void> _openPalette() async {
    final session = _session;
    if (session == null) return;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      builder: (sheet) => _Palette(session: session, answers: _answers, current: _index),
    );
    if (chosen != null) await _goTo(chosen);
  }

  Future<void> _confirmSubmit() async {
    final session = _session;
    if (session == null || _submitting) return;
    await _flushTyped();
    if (!mounted) return;
    final unanswered = session.questions.where((q) => !_isAnswered(q.id)).length;
    final strings = context.strings;
    final confirmed = await AppDialogs.confirm(
      context,
      title: strings.submitConfirmTitle,
      message: strings.submitConfirmBody(unanswered),
      confirmLabel: strings.submitExam,
    );
    if (confirmed && mounted) await _submit(auto: false);
  }

  bool _isAnswered(String questionId) => switch (_answers[questionId]) {
    ChoiceAnswer(:final optionIds) => optionIds.isNotEmpty,
    TextAnswer(:final text) => text.trim().isNotEmpty,
    null => false,
  };

  /// Submits once. A second call while the first is under way does nothing, so the deadline firing at the same moment as a
  /// tap on Submit still submits only once.
  Future<void> _submit({required bool auto}) async {
    final session = _session;
    if (session == null || _submitting || _leaving) return;
    setState(() => _submitting = true);
    _ticker?.cancel();
    await _flushTyped();
    final result = await _attempts.submit(session.attemptId, auto: auto);
    if (!mounted) return;
    switch (result) {
      case Ok<StudentResult>():
        _leaving = true;
        _proctoring?.close();
        ref
          ..invalidate(studentExamListProvider)
          ..invalidate(studentResultsProvider);
        if (!mounted) return;
        context.go(RoutePaths.studentAttemptResult(session.attemptId));
      case Err<StudentResult>(:final failure):
        setState(() {
          _submitting = false;
          _saveFailure = failure;
        });
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_onTick()));
    }
  }

  // ---- build ----

  String _clock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    return hours > 0
        ? '$hours:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final session = _session;
    final failure = _loadFailure;
    if (failure != null) {
      // The exam never started, so nothing is locked: the way out is offered.
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const BackOrHomeButton(),
          title: Text(strings.appName),
        ),
        body: AppErrorView(
          failure: failure,
          onRetry: () {
            setState(() => _loadFailure = null);
            unawaited(_load());
          },
        ),
      );
    }
    if (session == null) {
      return Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: Text(strings.appName)),
        body: const AppLoadingView(),
      );
    }
    final question = session.questions[_index];
    final isLast = _index == session.questions.length - 1;
    final low = _remaining < const Duration(minutes: 5);
    final saveFailure = _saveFailure;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(strings.isolate(session.title), maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            if (session.calculatorEnabled)
              IconButton(
                tooltip: strings.openCalculator,
                icon: const Icon(Icons.calculate_outlined),
                onPressed: () => unawaited(showCalculator(context)),
              ),
            IconButton(
              tooltip: strings.questionPalette,
              icon: const Icon(Icons.grid_view_outlined),
              onPressed: () => unawaited(_openPalette()),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Material(
                color: low ? AppColors.dangerSurface : AppColors.infoSurface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, color: low ? AppColors.danger : AppColors.info),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Semantics(
                          liveRegion: low,
                          child: Text(
                            strings.timeRemaining(_clock(_remaining)),
                            key: const Key('time-remaining'),
                            style: AppTypography.heading.copyWith(color: low ? AppColors.danger : AppColors.info),
                          ),
                        ),
                      ),
                      Text(strings.questionOf(_index + 1, session.questions.length), style: AppTypography.caption),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: ResponsiveContent(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (low) ...[
                          AppBanner(message: strings.timeLowWarning, tone: StatusTone.danger),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (!_online) ...[
                          AppBanner(message: strings.offlineBanner, tone: StatusTone.info),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (_warning != null) ...[
                          AppBanner(message: _warning!, tone: StatusTone.warning),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (_limitReached) ...[
                          AppBanner(message: strings.warningLimitReached, tone: StatusTone.warning),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        if (saveFailure != null) ...[
                          AppBanner(
                            message: '${strings.savingFailed} ${strings.failureMessage(saveFailure)}',
                            tone: StatusTone.danger,
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _QuestionView(
                          key: ValueKey(question.id),
                          question: question,
                          number: _index + 1,
                          answer: _answerFor(question),
                          controller: _controllerFor(question),
                          onChoice: (id) => _setChoice(question, id),
                          onTyped: (text) => _typed(question, text),
                          onBlocked: _blocked,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Material(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: strings.previousQuestion,
                          variant: AppButtonVariant.secondary,
                          onPressed: _index > 0 && session.allowBackwardNavigation && !_submitting
                              ? () => unawaited(_goTo(_index - 1))
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: isLast
                            ? AppButton(
                                label: strings.submitExam,
                                busy: _submitting,
                                onPressed: () => unawaited(_confirmSubmit()),
                              )
                            : AppButton(
                                label: strings.nextQuestion,
                                onPressed: _submitting ? null : () => unawaited(_goTo(_index + 1)),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: TextButton(
                    onPressed: _submitting ? null : () => unawaited(_confirmSubmit()),
                    child: Text(strings.submitExam),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextEditingController _controllerFor(StudentQuestion question) => _texts.putIfAbsent(question.id, () {
    final existing = _answers[question.id];
    return TextEditingController(text: existing is TextAnswer ? existing.text : '');
  });
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.question,
    required this.number,
    required this.answer,
    required this.controller,
    required this.onChoice,
    required this.onTyped,
    required this.onBlocked,
    super.key,
  });

  final StudentQuestion question;
  final int number;
  final AnswerValue? answer;
  final TextEditingController controller;
  final ValueChanged<String> onChoice;
  final ValueChanged<String> onTyped;
  final ValueChanged<String> onBlocked;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final selected = answer is ChoiceAnswer ? (answer! as ChoiceAnswer).optionIds : const <String>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            StatusBadge(label: strings.questionTypeName(question.type), tone: StatusTone.info),
            StatusBadge(label: strings.marksValue(formatNumber(question.marks)), tone: StatusTone.info),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(header: true, child: Text(strings.isolate(question.text), style: AppTypography.heading)),
        const SizedBox(height: AppSpacing.sm),
        Text(switch (question.type) {
          QuestionType.singleChoice => strings.chooseOneHint,
          QuestionType.multipleChoice => strings.chooseAllHint,
          QuestionType.shortText => strings.typedAnswerHint,
        }, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.md),
        if (question.type == QuestionType.shortText)
          GuardedAnswerField(controller: controller, onChanged: onTyped, onBlocked: onBlocked)
        else
          for (final option in question.options) ...[
            _OptionTile(
              text: option.text,
              selected: selected.contains(option.id),
              multiple: question.type == QuestionType.multipleChoice,
              onTap: () => onChoice(option.id),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.text, required this.selected, required this.multiple, required this.onTap});

  final String text;
  final bool selected;
  final bool multiple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = multiple
        ? (selected ? Icons.check_box : Icons.check_box_outline_blank)
        : (selected ? Icons.radio_button_checked : Icons.radio_button_unchecked);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: !multiple,
      label: text,
      excludeSemantics: true,
      child: Card(
        color: selected ? AppColors.infoSurface : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppDimensions.minTouchTarget),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text(context.strings.isolate(text), style: AppTypography.body)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Palette extends StatelessWidget {
  const _Palette({required this.session, required this.answers, required this.current});

  final StudentAttemptSession session;
  final Map<String, AnswerValue> answers;
  final int current;

  bool _answered(String id) => switch (answers[id]) {
    ChoiceAnswer(:final optionIds) => optionIds.isNotEmpty,
    TextAnswer(:final text) => text.trim().isNotEmpty,
    null => false,
  };

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(strings.questionPalette, style: AppTypography.heading)),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (var index = 0; index < session.questions.length; index++)
                  Semantics(
                    label: strings.paletteEntry(index + 1, _answered(session.questions[index].id)),
                    button: true,
                    excludeSemantics: true,
                    child: SizedBox(
                      width: AppDimensions.minTouchTarget,
                      height: AppDimensions.minTouchTarget,
                      child: _answered(session.questions[index].id)
                          ? FilledButton(
                              onPressed: _enabled(index) ? () => Navigator.of(context).pop(index) : null,
                              style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                              child: Text('${index + 1}'),
                            )
                          : OutlinedButton(
                              onPressed: _enabled(index) ? () => Navigator.of(context).pop(index) : null,
                              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                              child: Text('${index + 1}'),
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Without backward navigation only questions after the current one can be opened.
  bool _enabled(int index) => session.allowBackwardNavigation || index >= current;
}
