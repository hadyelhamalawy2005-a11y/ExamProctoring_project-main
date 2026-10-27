import 'dart:async';

import 'package:examora_app/app/router/router_guard.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/language_switcher.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Changes the password. Forced after a temporary password (then it is the only reachable screen and explains why), or
/// opened voluntarily from the profile.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  AppFailure? _failure;
  final Map<String, FieldProblem> _fields = {};

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final local = <String, FieldProblem>{
      'currentPassword': ?Validators.requiredPassword(_current.text),
      'newPassword': ?Validators.newPassword(_new.text),
      if (_new.text != _confirm.text) 'confirmPassword': const KnownFieldProblem(FieldReason.passwordsDiffer),
    };
    if (local.isNotEmpty) {
      setState(() {
        _failure = null;
        _fields
          ..clear()
          ..addAll(local);
      });
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
      _fields.clear();
    });
    final controller = ref.read(authControllerProvider.notifier);
    final forced = _isForced;
    final result = await controller.changePassword(currentPassword: _current.text, newPassword: _new.text);
    if (!mounted) return;
    switch (result) {
      case Ok<Account>(:final value):
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.strings.passwordChanged)));
        if (forced || !context.canPop()) {
          // The forced screen was the only reachable one: now that the change is done, go to the role's home.
          context.go(homeFor(value.role));
        } else {
          context.pop();
        }
      case Err<Account>(:final failure):
        setState(() {
          _busy = false;
          if (failure is ValidationFailure) {
            _fields
              ..clear()
              ..addAll(failure.fields);
            _failure = failure.fields.isEmpty ? failure : null;
          } else {
            _failure = failure;
          }
        });
    }
  }

  bool get _isForced {
    final auth = ref.read(authControllerProvider);
    return auth is AuthSignedIn && auth.account.mustChangePassword;
  }

  String? _error(String field) {
    final problem = _fields[field];
    return problem == null ? null : context.strings.fieldProblemMessage(problem);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final auth = ref.watch(authControllerProvider);
    final forced = auth is AuthSignedIn && auth.account.mustChangePassword;
    final failure = _failure;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: forced ? null : const BackOrHomeButton(),
        title: Text(forced ? strings.changePasswordForcedTitle : strings.changePasswordTitle),
        actions: [
          if (forced)
            TextButton(
              onPressed: () => unawaited(ref.read(authControllerProvider.notifier).signOut()),
              child: Text(strings.signOut, style: const TextStyle(color: AppColors.onNavy)),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(alignment: AlignmentDirectional.centerEnd, child: LanguageSwitcher()),
                const SizedBox(height: AppSpacing.lg),
                if (forced) ...[
                  AppBanner(message: strings.changePasswordForcedBody, tone: StatusTone.warning),
                  const SizedBox(height: AppSpacing.lg),
                ],
                if (failure != null) ...[
                  AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
                  const SizedBox(height: AppSpacing.lg),
                ],
                AppTextField(
                  controller: _current,
                  label: strings.currentPasswordLabel,
                  errorText: _error('currentPassword'),
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  enabled: !_busy,
                  ltr: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _new,
                  label: strings.newPasswordLabel,
                  errorText: _error('newPassword'),
                  helperText: strings.passwordPolicyHint,
                  obscure: true,
                  textInputAction: TextInputAction.next,
                  enabled: !_busy,
                  ltr: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _confirm,
                  label: strings.confirmNewPasswordLabel,
                  errorText: _error('confirmPassword'),
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_submit()),
                  enabled: !_busy,
                  ltr: true,
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: strings.changePasswordButton, busy: _busy, onPressed: () => unawaited(_submit())),
                if (forced) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _busy ? null : () => unawaited(ref.read(authControllerProvider.notifier).signOut()),
                    child: Text(strings.signOutInstead),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
