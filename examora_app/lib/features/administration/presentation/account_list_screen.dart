import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/app_empty_view.dart';
import 'package:examora_app/core/widgets/app_error_view.dart';
import 'package:examora_app/core/widgets/app_loading_view.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/administration/presentation/admin_providers_ui.dart';
import 'package:examora_app/features/authentication/domain/account_status.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The administrator's home: every student and instructor account, newest first, filtered by role and status and shown a
/// page at a time. Administrators are never listed. Everything it opens is pushed, because the administrator has no bottom
/// navigation.
class AccountListScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const AccountListScreen({super.key});

  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  UserRole? _role;
  AccountStatus? _status;
  int _page = 1;

  AccountQuery get _query => (role: _role, status: _status, page: _page);

  Future<void> _open(String path) async {
    await context.push<void>(path);
    if (mounted) ref.invalidate(accountListProvider);
  }

  void _setFilters({UserRole? role, AccountStatus? status, bool clearRole = false, bool clearStatus = false}) {
    setState(() {
      if (role != null || clearRole) _role = role;
      if (status != null || clearStatus) _status = status;
      _page = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final result = ref.watch(accountListProvider(_query));

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(strings.adminAccountsTitle),
        actions: [
          IconButton(
            tooltip: strings.profileTitle,
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push(RoutePaths.adminProfile),
          ),
        ],
      ),
      body: SafeArea(
        // One scrolling column: with large text or a small window the filters and the pager scroll away with the list
        // instead of squeezing it to nothing.
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppButton(
                  label: strings.adminAddAccount,
                  icon: Icons.person_add_alt_1_outlined,
                  onPressed: () => unawaited(_open(RoutePaths.adminNewInstructor)),
                ),
                const SizedBox(height: AppSpacing.md),
                _FilterBar(
                  role: _role,
                  status: _status,
                  onRole: (role) => _setFilters(role: role, clearRole: role == null),
                  onStatus: (status) => _setFilters(status: status, clearStatus: status == null),
                ),
                const SizedBox(height: AppSpacing.md),
                result.when(
                  loading: () => const SizedBox(height: 240, child: AppLoadingView()),
                  error: (error, stack) => SizedBox(
                    height: 280,
                    child: AppErrorView(
                      // Repositories return failures instead of throwing, so this is an unexpected error.
                      failure: const ServerFailure(),
                      onRetry: () => ref.invalidate(accountListProvider),
                    ),
                  ),
                  data: (outcome) => switch (outcome) {
                    Err<AccountPage>(:final failure) => SizedBox(
                      height: 280,
                      child: AppErrorView(failure: failure, onRetry: () => ref.invalidate(accountListProvider)),
                    ),
                    Ok<AccountPage>(:final value) => _List(
                      page: value,
                      filtered: _role != null || _status != null,
                      onOpen: (account) => unawaited(_open(RoutePaths.adminAccount(account.id))),
                      onPage: (page) => setState(() => _page = page),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.role, required this.status, required this.onRole, required this.onStatus});

  final UserRole? role;
  final AccountStatus? status;
  final ValueChanged<UserRole?> onRole;
  final ValueChanged<AccountStatus?> onStatus;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    // A Wrap, not a Row: with large text or a long Arabic label the chips move to a second line instead of overflowing.
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(strings.filterRole, style: AppTypography.caption),
        ChoiceChip(label: Text(strings.filterAll), selected: role == null, onSelected: (_) => onRole(null)),
        for (final option in const [UserRole.student, UserRole.instructor])
          ChoiceChip(
            label: Text(strings.roleName(option)),
            selected: role == option,
            onSelected: (_) => onRole(option),
          ),
        const SizedBox(width: AppSpacing.md),
        Text(strings.filterStatus, style: AppTypography.caption),
        ChoiceChip(label: Text(strings.filterAll), selected: status == null, onSelected: (_) => onStatus(null)),
        for (final option in AccountStatus.values)
          ChoiceChip(
            label: Text(strings.accountStatusName(option)),
            selected: status == option,
            onSelected: (_) => onStatus(option),
          ),
      ],
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.page, required this.filtered, required this.onOpen, required this.onPage});

  final AccountPage page;
  final bool filtered;
  final ValueChanged<ManagedAccount> onOpen;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    if (page.items.isEmpty) {
      return SizedBox(
        height: 280,
        child: AppEmptyView(
          icon: Icons.people_outline,
          title: filtered ? strings.accountsEmptyFiltered : strings.accountsEmptyTitle,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final account in page.items) ...[
          AccountCard(account: account, onTap: () => onOpen(account)),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(strings.accountsShowing(page.items.length, page.totalCount), style: AppTypography.caption),
        // A Wrap, so with large text the three parts move to separate lines instead of overflowing.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: page.hasPrevious ? () => onPage(page.page - 1) : null,
              child: Text(strings.previousPage),
            ),
            Text(strings.pageNumber(page.page), style: AppTypography.caption),
            TextButton(onPressed: page.hasNext ? () => onPage(page.page + 1) : null, child: Text(strings.nextPage)),
          ],
        ),
      ],
    );
  }
}

/// One account in the list: name, email and its state in words.
class AccountCard extends StatelessWidget {
  /// Creates the card.
  const AccountCard({required this.account, required this.onTap, super.key});

  /// The account.
  final ManagedAccount account;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.isolate(account.fullName), style: AppTypography.heading),
          const SizedBox(height: AppSpacing.xs),
          Text(account.email, textDirection: TextDirection.ltr, style: AppTypography.body),
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
        ],
      ),
    );
  }
}
