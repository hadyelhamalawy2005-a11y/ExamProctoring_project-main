import 'dart:async';

import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/language_switcher.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sign in. There is deliberately no "create account" path: an administrator creates every account.
class LoginScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final result = await ref.read(authControllerProvider.notifier).signIn(email: _email.text, password: _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = result is Err<Account> ? result.failure : null;
      if (result is Err<Account>) _password.clear();
    });
  }

  String? _fieldError(String field) {
    final failure = _failure;
    if (failure is! ValidationFailure) return null;
    final problem = failure.fields[field];
    return problem == null ? null : context.strings.fieldProblemMessage(problem);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final auth = ref.watch(authControllerProvider);
    final notice = auth is AuthSignedOut ? auth.notice : null;
    final failure = _failure;
    final bannerFailure = failure is ValidationFailure ? null : (failure ?? notice);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: AlignmentDirectional.centerEnd, child: LanguageSwitcher()),
                  const SizedBox(height: AppSpacing.xl),
                  const Icon(Icons.school_outlined, size: AppIconSizes.lg, color: AppColors.navy),
                  const SizedBox(height: AppSpacing.md),
                  Text(strings.appName, textAlign: TextAlign.center, style: AppTypography.title),
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    header: true,
                    child: Text(strings.loginTitle, textAlign: TextAlign.center, style: AppTypography.heading),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(strings.loginSubtitle, textAlign: TextAlign.center, style: AppTypography.body),
                  const SizedBox(height: AppSpacing.xl),
                  if (bannerFailure != null) ...[
                    AppBanner(message: strings.failureMessage(bannerFailure), tone: StatusTone.danger),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  AppTextField(
                    controller: _email,
                    label: strings.emailLabel,
                    errorText: _fieldError('email'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    enabled: !_busy,
                    ltr: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    controller: _password,
                    label: strings.passwordLabel,
                    errorText: _fieldError('password'),
                    obscure: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => unawaited(_submit()),
                    enabled: !_busy,
                    ltr: true,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: _busy ? strings.signingIn : strings.signInButton,
                    busy: _busy,
                    onPressed: () => unawaited(_submit()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: _busy ? null : () => context.push(RoutePaths.forgotPassword),
                    child: Text(strings.forgotPasswordLink),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    strings.accountsCreatedByAdmin,
                    textAlign: TextAlign.center,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
