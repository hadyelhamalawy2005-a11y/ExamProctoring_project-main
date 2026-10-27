import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_empty_view.dart';
import 'package:examora_app/core/widgets/async_result_view.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exam_session/data/exam_session_providers.dart';
import 'package:examora_app/features/proctoring/domain/incident.dart';
import 'package:examora_app/features/proctoring/domain/incident_category.dart';
import 'package:examora_app/features/proctoring/domain/incident_repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The incidents at the instructor's exams. `null` lists all, `true` those with a decision, `false` those without.
final incidentQueueProvider = FutureProvider.autoDispose.family<Result<List<IncidentSummary>>, bool?>(
  (ref, decided) => ref.watch(incidentReviewRepositoryProvider).listQueue(decided: decided),
);

/// One incident with its timeline.
final incidentDetailProvider = FutureProvider.autoDispose.family<Result<IncidentDetail>, String>(
  (ref, id) => ref.watch(incidentReviewRepositoryProvider).getIncident(id),
);

/// How serious, as a colour family (the word is always shown too).
StatusTone severityTone(IncidentSeverity severity) => switch (severity) {
  IncidentSeverity.low => StatusTone.info,
  IncidentSeverity.medium => StatusTone.warning,
  IncidentSeverity.high || IncidentSeverity.critical => StatusTone.danger,
};

/// The queue of incidents to review: undecided first by default, newest first.
class IncidentQueueScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const IncidentQueueScreen({super.key});

  @override
  ConsumerState<IncidentQueueScreen> createState() => _IncidentQueueScreenState();
}

class _IncidentQueueScreenState extends ConsumerState<IncidentQueueScreen> {
  bool? _decided = false;

  Future<void> _open(String id) async {
    await context.push<void>(RoutePaths.instructorIncident(id));
    if (mounted) ref.invalidate(incidentQueueProvider);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(strings.incidentsTitle)),
      body: SafeArea(
        child: Column(
          children: [
            ResponsiveContent(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: Text(strings.incidentFilterOpen),
                    selected: _decided == false,
                    onSelected: (_) => setState(() => _decided = false),
                  ),
                  ChoiceChip(
                    label: Text(strings.incidentFilterDecided),
                    selected: _decided == true,
                    onSelected: (_) => setState(() => _decided = true),
                  ),
                  ChoiceChip(
                    label: Text(strings.filterAll),
                    selected: _decided == null,
                    onSelected: (_) => setState(() => _decided = null),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AsyncResultView<List<IncidentSummary>>(
                value: ref.watch(incidentQueueProvider(_decided)),
                onRetry: () => ref.invalidate(incidentQueueProvider),
                builder: (incidents) {
                  if (incidents.isEmpty) {
                    return AppEmptyView(
                      icon: Icons.flag_outlined,
                      title: strings.incidentsEmptyTitle,
                      message: strings.incidentsEmptyBody,
                    );
                  }
                  return ListView(
                    children: [
                      ResponsiveContent(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final incident in incidents) ...[
                              IncidentCard(incident: incident, onTap: () => unawaited(_open(incident.id))),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One incident in a list.
class IncidentCard extends StatelessWidget {
  /// Creates the card.
  const IncidentCard({required this.incident, required this.onTap, super.key});

  /// The incident.
  final Incident incident;

  /// Called when tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final decision = incident.decision;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.incidentCategoryName(incident.category), style: AppTypography.heading),
          Text(
            strings.incidentWhoWhat(strings.isolate(incident.studentName), strings.isolate(incident.examTitle)),
            style: AppTypography.body,
          ),
          Text(DateFormatting.dateTime(context, incident.occurredAt), style: AppTypography.caption),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusBadge(
                label: strings.incidentSeverityName(incident.severity),
                tone: severityTone(incident.severity),
              ),
              StatusBadge(
                label: decision == null ? strings.incidentUndecided : strings.incidentDecisionName(decision.decision),
                tone: decision == null ? StatusTone.warning : StatusTone.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
