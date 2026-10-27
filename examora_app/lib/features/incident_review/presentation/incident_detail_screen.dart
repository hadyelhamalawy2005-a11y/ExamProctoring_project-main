import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_section_header.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/async_result_view.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/data/exam_session_providers.dart';
import 'package:examora_app/features/incident_review/presentation/incident_queue_screen.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One incident: what happened, the whole timeline of that attempt, the status of the evidence, and the decision.
class IncidentDetailScreen extends ConsumerWidget {
  /// Creates the screen.
  const IncidentDetailScreen({required this.incidentId, super.key});

  /// The incident.
  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.incidentDetailTitle),
      ),
      body: SafeArea(
        child: AsyncResultView<IncidentDetail>(
          value: ref.watch(incidentDetailProvider(incidentId)),
          onRetry: () => ref.invalidate(incidentDetailProvider(incidentId)),
          builder: (detail) => SingleChildScrollView(
            child: ResponsiveContent(
              child: _Body(key: ValueKey(detail.incident.id), detail: detail),
            ),
          ),
        ),
      ),
    );
  }
}

String _describe(BuildContext context, Incident incident) {
  final seconds = incident.durationMs == null ? null : (incident.durationMs! / 1000).round();
  return context.strings.incidentDescription(incident.category, incident.detail, seconds);
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.detail, super.key});

  final IncidentDetail detail;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late final TextEditingController _notes = TextEditingController(text: widget.detail.incident.decision?.notes);
  late ReviewDecision? _decision = widget.detail.incident.decision?.decision;
  bool _busy = false;
  AppFailure? _failure;
  String? _notice;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final decision = _decision;
    if (decision == null || _busy) return;
    setState(() {
      _busy = true;
      _failure = null;
      _notice = null;
    });
    final result = await ref
        .read(incidentReviewRepositoryProvider)
        .decide(widget.detail.incident.id, decision, _notes.text);
    if (!mounted) return;
    switch (result) {
      case Ok<Incident>():
        setState(() {
          _busy = false;
          _notice = context.strings.incidentDecisionSaved;
        });
        ref
          ..invalidate(incidentDetailProvider(widget.detail.incident.id))
          ..invalidate(incidentQueueProvider);
      case Err<Incident>(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final detail = widget.detail;
    final incident = detail.incident;
    final failure = _failure;
    final decided = incident.decision;
    final evidence = incident.evidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.incidentCategoryName(incident.category), style: AppTypography.title),
        Text(
          strings.incidentWhoWhat(strings.isolate(incident.studentName), strings.isolate(incident.examTitle)),
          style: AppTypography.body,
        ),
        Text(DateFormatting.dateTime(context, incident.occurredAt), style: AppTypography.caption),
        Text(strings.timeZoneNote(DateFormatting.zone(incident.occurredAt)), style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            StatusBadge(label: strings.incidentSeverityName(incident.severity), tone: severityTone(incident.severity)),
            StatusBadge(
              label: decided == null ? strings.incidentUndecided : strings.incidentDecisionName(decided.decision),
              tone: decided == null ? StatusTone.warning : StatusTone.success,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_describe(context, incident), key: const Key('incident-description'), style: AppTypography.body),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${strings.incidentSourceLabel}: ${strings.incidentSourceName(incident.source)}',
                style: AppTypography.caption,
              ),
              Text(strings.incidentWarningsLine(detail.warnings, incident.warningLimit), style: AppTypography.caption),
            ],
          ),
        ),
        if (detail.limitReached) ...[
          const SizedBox(height: AppSpacing.sm),
          AppBanner(message: strings.incidentLimitReached, tone: StatusTone.warning),
        ],
        AppSectionHeader(strings.incidentEvidenceHeading),
        AppCard(
          child: Text(
            evidence.status == EvidenceStatus.captured
                ? strings.evidenceCapturedBody(evidence.reference ?? '')
                : strings.evidenceUnavailableBody,
            key: const Key('incident-evidence'),
            style: AppTypography.body,
          ),
        ),
        AppSectionHeader(strings.incidentTimelineHeading),
        for (final entry in detail.timeline)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${DateFormatting.dateTime(context, entry.occurredAt)}${entry.id == incident.id ? ' ${strings.incidentThisOne}' : ''}',
                    style: AppTypography.caption,
                  ),
                  Text(strings.incidentCategoryName(entry.category), style: AppTypography.heading),
                  Text(_describe(context, entry), style: AppTypography.body),
                ],
              ),
            ),
          ),
        AppSectionHeader(strings.incidentDecisionHeading),
        Text(strings.incidentNotAVerdict, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        if (failure != null) ...[
          AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (_notice != null) ...[
          AppBanner(message: _notice!, tone: StatusTone.success),
          const SizedBox(height: AppSpacing.sm),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final value in ReviewDecision.values)
              ChoiceChip(
                label: Text(strings.incidentDecisionName(value)),
                selected: _decision == value,
                onSelected: _busy ? null : (_) => setState(() => _decision = value),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _notes,
          label: strings.incidentNotesLabel,
          maxLines: 4,
          maxLength: Validators.statusReasonMaxLength,
          enabled: !_busy,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: strings.incidentSaveDecision,
          busy: _busy,
          onPressed: _decision == null ? null : () => unawaited(_save()),
        ),
      ],
    );
  }
}
