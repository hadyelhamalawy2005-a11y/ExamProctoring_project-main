import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/administration/presentation/admin_providers_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows a temporary password exactly once, in a bottom sheet that cannot be dismissed by a swipe or a tap outside.
/// Completes when the administrator confirms with "I have saved it".
///
/// The password lives only in this sheet's widgets: it is never written to storage, never logged and cannot be reopened.
Future<void> showTemporaryPasswordSheet(BuildContext context, IssuedPassword issued) => showModalBottomSheet<void>(
  context: context,
  isDismissible: false,
  enableDrag: false,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _TemporaryPasswordSheet(issued: issued),
);

class _TemporaryPasswordSheet extends ConsumerStatefulWidget {
  const _TemporaryPasswordSheet({required this.issued});

  final IssuedPassword issued;

  @override
  ConsumerState<_TemporaryPasswordSheet> createState() => _TemporaryPasswordSheetState();
}

class _TemporaryPasswordSheetState extends ConsumerState<_TemporaryPasswordSheet> {
  String? _notice;
  StatusTone _noticeTone = StatusTone.success;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.issued.temporaryPassword));
    if (!mounted) return;
    setState(() {
      _notice = context.strings.passwordCopied;
      _noticeTone = StatusTone.success;
    });
  }

  Future<void> _sendByEmail() async {
    final strings = context.strings;
    final issued = widget.issued;
    final when = DateFormatting.dateTime(context, issued.expiresAt);
    final subject = strings.temporaryPasswordEmailSubject;
    final body = strings.temporaryPasswordEmailBody(issued.fullName, issued.email, issued.temporaryPassword, when);
    // Built by hand: Uri(queryParameters) writes a space as "+", which mail apps show literally.
    final uri = Uri.parse(
      'mailto:${Uri.encodeComponent(issued.email)}?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    final opened = await ref.read(uriLauncherProvider)(uri);
    if (!mounted || opened) return;
    setState(() {
      _notice = context.strings.emailNotAvailable;
      _noticeTone = StatusTone.warning;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final issued = widget.issued;
    final notice = _notice;
    return PopScope(
      canPop: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(strings.temporaryPasswordTitle, style: AppTypography.title)),
            const SizedBox(height: AppSpacing.md),
            AppBanner(message: strings.temporaryPasswordOnce, tone: StatusTone.warning),
            const SizedBox(height: AppSpacing.lg),
            Text(strings.temporaryPasswordFor(issued.fullName, issued.email), style: AppTypography.body),
            const SizedBox(height: AppSpacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SelectableText(
                  issued.temporaryPassword,
                  key: const Key('temporary-password'),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: AppTypography.title.copyWith(fontFamily: 'monospace', letterSpacing: 2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              strings.temporaryPasswordExpires(DateFormatting.dateTime(context, issued.expiresAt)),
              style: AppTypography.caption,
            ),
            Text(strings.timeZoneNote(DateFormatting.zone(issued.expiresAt)), style: AppTypography.caption),
            if (notice != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppBanner(message: notice, tone: _noticeTone),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: strings.copyPassword,
              icon: Icons.copy_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(_copy()),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: strings.sendByEmail,
              icon: Icons.email_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () => unawaited(_sendByEmail()),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: strings.iHaveSavedIt, onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
