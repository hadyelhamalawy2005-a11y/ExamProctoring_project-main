import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/utilities/date_formatting.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_dialogs.dart';
import 'package:examora_app/core/widgets/app_error_view.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/administration/data/admin_providers.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/administration/presentation/admin_providers_ui.dart';
import 'package:examora_app/features/administration/presentation/reason_dialog.dart';
import 'package:examora_app/features/administration/presentation/temporary_password_sheet.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One account with every field the administrator manages, and the three things they can do to it: issue a temporary
/// password, deactivate, reactivate.
class AccountDetailScreen extends ConsumerStatefulWidget {
  /// Creates the screen for [accountId].
  const AccountDetailScreen({required this.accountId, super.key});

  /// The account to show.
  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _busy = false;
  AppFailure? _failure;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) {
    // Replaces any message still showing: snackbars otherwise queue, and the newest would appear seconds late.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _issuePassword(ManagedAccount account) async {
    final strings = context.strings;
    final confirmed = await AppDialogs.confirm(
      context,
      title: strings.issuePasswordTitle,
      message: strings.issuePasswordBody(account.fullName),
      confirmLabel: strings.issueTemporaryPassword,
    );
    if (!confirmed || !mounted) return;
    IssuedPassword? issued;
    await _run(() async {
      final result = await ref.read(adminRepositoryProvider).issueTemporaryPassword(account.id);
      if (!mounted) return;
      switch (result) {
        case Ok<IssuedPassword>(:final value):
          issued = value;
          ref.invalidate(accountDetailProvider(account.id));
        case Err<IssuedPassword>(:final failure):
          setState(() => _failure = failure);
      }
    });
    // Shown after the busy state ends, so no button keeps spinning behind the sheet.
    final password = issued;
    if (password != null && mounted) await showTemporaryPasswordSheet(context, password);
  }

  Future<void> _deactivate(ManagedAccount account) async {
    final strings = context.strings;
    final reason = await showReasonDialog(
      context,
      title: strings.deactivateTitle,
      message: strings.deactivateBody(account.fullName),
      confirmLabel: strings.deactivateAccount,
      reasonRequired: true,
      destructive: true,
    );
    if (reason == null || !mounted) return;
    await _run(() async {
      final result = await ref.read(adminRepositoryProvider).deactivate(account.id, reason: reason);
      if (!mounted) return;
      _afterStatusChange(result, account.id, context.strings.accountDeactivatedNotice);
    });
  }

  Future<void> _reactivate(ManagedAccount account) async {
    final strings = context.strings;
    final reason = await showReasonDialog(
      context,
      title: strings.reactivateTitle,
      message: strings.reactivateBody(account.fullName),
      confirmLabel: strings.reactivateAccount,
      reasonRequired: false,
    );
    if (reason == null || !mounted) return;
    await _run(() async {
      final result = await ref.read(adminRepositoryProvider).reactivate(account.id, reason: reason);
      if (!mounted) return;
      _afterStatusChange(result, account.id, context.strings.accountReactivatedNotice);
    });
  }

  void _afterStatusChange(Result<ManagedAccount> result, String id, String successNotice) {
    switch (result) {
      case Ok<ManagedAccount>():
        ref.invalidate(accountDetailProvider(id));
        _notice(successNotice);
      case Err<ManagedAccount>(:final failure):
        // The account may have changed elsewhere (for example it is already in the wanted state): show the truth.
        ref.invalidate(accountDetailProvider(id));
        setState(() => _failure = failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final result = ref.watch(accountDetailProvider(widget.accountId));
    final failure = _failure;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.accountDetailTitle),
      ),
      body: SafeArea(
        child: result.when(
          loading: () => const AppLoadingView(),
          error: (error, stack) => AppErrorView(
            // Repositories return failures instead of throwing, so this is an unexpected error.
            failure: const ServerFailure(),
            onRetry: () => ref.invalidate(accountDetailProvider(widget.accountId)),
          ),
          data: (outcome) => switch (outcome) {
            Err<ManagedAccount>(failure: final problem) => AppErrorView(
              failure: problem,
              onRetry: () => ref.invalidate(accountDetailProvider(widget.accountId)),
            ),
            Ok<ManagedAccount>(:final value) => SingleChildScrollView(
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (failure != null) ...[
                      AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _Details(account: value),
                    const SizedBox(height: AppSpacing.lg),
                    _Actions(
                      account: value,
                      busy: _busy,
                      onIssue: () => unawaited(_issuePassword(value)),
                      onDeactivate: () => unawaited(_deactivate(value)),
                      onReactivate: () => unawaited(_reactivate(value)),
                    ),
                  ],
                ),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.account});

  final ManagedAccount account;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    String when(DateTime moment) => DateFormatting.dateTime(context, moment);
    final expires = account.temporaryPasswordExpiresAt;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.isolate(account.fullName), style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              StatusBadge(label: strings.roleName(account.role), tone: StatusTone.info),
              StatusBadge(
                label: strings.accountStatusName(account.status),
                tone: account.status == AccountStatus.active ? StatusTone.success : StatusTone.danger,
              ),
              if (account.isLockedOut) StatusBadge(label: strings.lockedBadge, tone: StatusTone.warning),
              if (account.mustChangePassword)
                StatusBadge(label: strings.mustChangePasswordBadge, tone: StatusTone.warning),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Line(label: strings.emailLabel, value: account.email, ltr: true),
          _Line(label: strings.roleLabel, value: strings.roleName(account.role)),
          _Line(label: strings.accountStatusLabel, value: strings.accountStatusName(account.status)),
          _Line(label: strings.passwordLockedLabel, value: account.isLockedOut ? strings.yes : strings.no),
          _Line(label: strings.mustChangePasswordBadge, value: account.mustChangePassword ? strings.yes : strings.no),
          if (expires != null) _Line(label: strings.temporaryPasswordExpiresLabel, value: when(expires)),
          _Line(label: strings.createdAtLabel, value: when(account.createdAt)),
          _Line(
            label: strings.lastLoginLabel,
            value: account.lastLoginAt == null ? strings.neverSignedIn : when(account.lastLoginAt!),
          ),
          if (account.statusChangedAt != null)
            _Line(label: strings.statusChangedLabel, value: when(account.statusChangedAt!)),
          if (account.statusReason != null)
            _Line(label: strings.statusReasonLabel, value: strings.isolate(account.statusReason!)),
          const SizedBox(height: AppSpacing.sm),
          Text(strings.timeZoneNote(DateFormatting.zone(account.createdAt)), style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.ltr = false});

  final String label;
  final String value;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
          Text(value, textDirection: ltr ? TextDirection.ltr : null, style: AppTypography.body),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.account,
    required this.busy,
    required this.onIssue,
    required this.onDeactivate,
    required this.onReactivate,
  });

  final ManagedAccount account;
  final bool busy;
  final VoidCallback onIssue;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton(
          label: strings.issueTemporaryPassword,
          icon: Icons.key_outlined,
          variant: AppButtonVariant.secondary,
          busy: busy,
          onPressed: onIssue,
        ),
        const SizedBox(height: AppSpacing.md),
        if (account.status == AccountStatus.active)
          AppButton(
            label: strings.deactivateAccount,
            icon: Icons.block_outlined,
            variant: AppButtonVariant.danger,
            busy: busy,
            onPressed: onDeactivate,
          )
        else
          AppButton(
            label: strings.reactivateAccount,
            icon: Icons.check_circle_outline,
            busy: busy,
            onPressed: onReactivate,
          ),
      ],
    );
  }
}
