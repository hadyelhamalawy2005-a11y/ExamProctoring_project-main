import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/exams/domain/exam.dart';
import 'package:flutter/material.dart';

/// An exam's status as a word with a colour behind it.
class ExamStatusBadge extends StatelessWidget {
  /// Creates the badge.
  const ExamStatusBadge({required this.status, super.key});

  /// The status to show.
  final ExamStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      ExamStatus.draft => StatusTone.info,
      ExamStatus.scheduled => StatusTone.info,
      ExamStatus.ongoing => StatusTone.success,
      ExamStatus.completed => StatusTone.info,
      ExamStatus.archived => StatusTone.warning,
    };
    return StatusBadge(label: context.strings.examStatusName(status), tone: tone);
  }
}
