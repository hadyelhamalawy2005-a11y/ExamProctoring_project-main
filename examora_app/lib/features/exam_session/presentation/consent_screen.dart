import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/data/exam_session_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The notice the student must accept before the camera is touched or an attempt begins. It states plainly what is
/// recorded, what is not, and that warnings never change marks.
class ConsentScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ConsentScreen({required this.examId, super.key});

  /// The exam.
  final String examId;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _agreed = false;
  bool _busy = false;
  AppFailure? _failure;

  Future<void> _continue() async {
    if (_busy || !_agreed) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref.read(attemptRepositoryProvider).recordConsent(widget.examId);
    if (!mounted) return;
    switch (result) {
      case Ok<void>():
        setState(() => _busy = false);
        unawaited(context.push(RoutePaths.studentSystemCheck(widget.examId)));
      case Err<void>(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final failure = _failure;
    final points = [
      strings.consentPoint1,
      strings.consentPoint2,
      strings.consentPoint3,
      strings.consentPoint4,
      strings.consentPoint5,
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.consentTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(strings.consentIntro, style: AppTypography.body),
                const SizedBox(height: AppSpacing.md),
                if (failure != null) ...[
                  AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
                  const SizedBox(height: AppSpacing.md),
                ],
                for (final point in points)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsetsDirectional.only(top: 4, end: AppSpacing.sm),
                          child: Icon(Icons.info_outline, size: AppIconSizes.sm, color: AppColors.info),
                        ),
                        Expanded(child: Text(point, style: AppTypography.body)),
                      ],
                    ),
                  ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(strings.consentAgree),
                  value: _agreed,
                  onChanged: _busy ? null : (value) => setState(() => _agreed = value ?? false),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: strings.consentContinue,
                  busy: _busy,
                  onPressed: _agreed ? () => unawaited(_continue()) : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: strings.consentDecline,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
