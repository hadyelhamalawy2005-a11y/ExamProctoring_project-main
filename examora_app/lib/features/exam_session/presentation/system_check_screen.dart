import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/data/exam_session_providers.dart';
import 'package:examora_app/features/exam_session/domain/student_attempt.dart';
import 'package:examora_app/features/exam_session/domain/student_exam.dart';
import 'package:examora_app/features/exam_session/presentation/student_queries.dart';
import 'package:examora_app/features/proctoring/data/platform_services.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The query value that tells the player the student started without a working camera.
const String cameraMissingValue = 'none';

/// Checks, once the student has agreed, that the camera works (a preview that is never recorded), says honestly when there
/// is none, shows the connection, and only then lets the attempt begin. The clock starts at "Start the exam", not before.
class SystemCheckScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const SystemCheckScreen({required this.examId, super.key});

  /// The exam.
  final String examId;

  @override
  ConsumerState<SystemCheckScreen> createState() => _SystemCheckScreenState();
}

class _SystemCheckScreenState extends ConsumerState<SystemCheckScreen> {
  // Kept in a field when the screen is built: `ref` cannot be used while the screen is being disposed.
  late final CameraService _camera;
  CameraCheck? _cameraResult;
  bool? _online;
  bool? _consented;
  bool _withoutCamera = false;
  bool _busy = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _camera = ref.read(cameraServiceProvider);
    unawaited(_run());
  }

  @override
  void dispose() {
    unawaited(_camera.stop());
    super.dispose();
  }

  Future<void> _run() async {
    final consent = await ref.read(attemptRepositoryProvider).hasConsent(widget.examId);
    if (!mounted) return;
    final given = consent.valueOrNull ?? false;
    setState(() => _consented = given);
    // Not a single camera call before the student has agreed.
    if (!given) return;
    final online = await ref.read(connectivitySourceProvider).isOnline();
    if (!mounted) return;
    setState(() => _online = online);
    await _checkCamera();
  }

  Future<void> _checkCamera() async {
    setState(() => _cameraResult = null);
    final result = await _camera.start();
    if (!mounted) return;
    setState(() => _cameraResult = result);
  }

  Future<void> _start(StudentExamInfo info) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    await _camera.stop();
    final result = await ref.read(attemptRepositoryProvider).startAttempt(info.id);
    if (!mounted) return;
    switch (result) {
      case Ok<StudentAttemptSession>(:final value):
        ref.invalidate(studentExamListProvider);
        final noCamera = _cameraResult is! CameraWorking;
        final query = noCamera ? '?${RoutePaths.cameraParameter}=$cameraMissingValue' : '';
        context.go('${RoutePaths.studentAttempt(value.attemptId)}$query');
      case Err<StudentAttemptSession>(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final info = ref.watch(studentExamInfoProvider(widget.examId)).value?.valueOrNull;
    final failure = _failure;
    final camera = _cameraResult;
    final cameraWorks = camera is CameraWorking;
    final cameraRuleOn = info?.activeRules.contains(IncidentCategory.cameraUnavailable) ?? false;
    final needsAck = camera != null && !cameraWorks && cameraRuleOn;
    final ready = info != null && camera != null && (!needsAck || _withoutCamera);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.systemCheckTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: _consented == false
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppBanner(message: strings.consentNeeded, tone: StatusTone.warning),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: strings.consentTitle,
                        onPressed: () => context.pushReplacement(RoutePaths.studentConsent(widget.examId)),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(strings.systemCheckIntro, style: AppTypography.body),
                      const SizedBox(height: AppSpacing.lg),
                      if (failure != null) ...[
                        AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _row(
                        title: strings.cameraCheckTitle,
                        icon: cameraWorks ? Icons.videocam_outlined : Icons.videocam_off_outlined,
                        tone: camera == null
                            ? StatusTone.info
                            : (cameraWorks ? StatusTone.success : StatusTone.warning),
                        message: switch (camera) {
                          null => strings.cameraChecking,
                          CameraWorking() => strings.cameraWorking,
                          CameraMissing() => strings.cameraNone,
                          CameraDenied() => strings.cameraDenied,
                          CameraFailed() => strings.cameraError,
                        },
                        extra: Column(
                          children: [
                            if (camera is CameraWorking)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.md),
                                child: SizedBox(
                                  height: 180,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadii.md),
                                    child: camera.preview,
                                  ),
                                ),
                              ),
                            if (camera != null && !cameraWorks)
                              TextButton(onPressed: () => unawaited(_checkCamera()), child: Text(strings.cameraRetry)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _row(
                        title: strings.connectionCheckTitle,
                        icon: (_online ?? true) ? Icons.wifi : Icons.wifi_off,
                        tone: (_online ?? true) ? StatusTone.success : StatusTone.warning,
                        message: _online == null
                            ? strings.loading
                            : (_online! ? strings.connectionOnline : strings.connectionOffline),
                      ),
                      if (info != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        _row(
                          title: strings.timeCheckTitle,
                          icon: Icons.timer_outlined,
                          tone: StatusTone.info,
                          message: strings.timeCheckBody(
                            info.durationMinutes,
                            DateFormatting.zone(DateTime.now().toUtc()),
                          ),
                        ),
                      ],
                      if (needsAck) ...[
                        const SizedBox(height: AppSpacing.md),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(strings.startWithoutCamera),
                          value: _withoutCamera,
                          onChanged: (value) => setState(() => _withoutCamera = value ?? false),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: strings.startExam,
                        busy: _busy,
                        onPressed: ready ? () => unawaited(_start(info)) : null,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _row({
    required String title,
    required IconData icon,
    required StatusTone tone,
    required String message,
    Widget? extra,
  }) {
    final color = switch (tone) {
      StatusTone.success => AppColors.success,
      StatusTone.warning => AppColors.warning,
      StatusTone.danger => AppColors.danger,
      StatusTone.info => AppColors.info,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(title, style: AppTypography.heading)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: AppTypography.body),
          ?extra,
        ],
      ),
    );
  }
}
