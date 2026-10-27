import 'dart:async';

import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/core/validation/validators.dart';
import 'package:examora_app/core/widgets/app_banner.dart';
import 'package:examora_app/core/widgets/app_button.dart';
import 'package:examora_app/core/widgets/app_text_field.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/core/widgets/status_badge.dart';
import 'package:examora_app/features/administration/data/admin_providers.dart';
import 'package:examora_app/features/administration/domain/managed_account.dart';
import 'package:examora_app/features/administration/presentation/temporary_password_sheet.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creates an instructor or a student. One screen with a segmented control, so the administrator never hunts for a second
/// form. On success the temporary password is shown once, and only after the administrator confirms is the screen left.
class CreateAccountScreen extends ConsumerStatefulWidget {
  /// Creates the screen.
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  UserRole _role = UserRole.instructor;
  bool _busy = false;
  AppFailure? _failure;
  final Map<String, FieldProblem> _fields = {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final local = <String, FieldProblem>{
      'fullName': ?Validators.fullName(_name.text),
      'email': ?Validators.email(_email.text),
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
    final result = await ref
        .read(adminRepositoryProvider)
        .createAccount(role: _role, fullName: _name.text, email: _email.text);
    if (!mounted) return;
    switch (result) {
      case Ok<IssuedPassword>(:final value):
        setState(() => _busy = false);
        await showTemporaryPasswordSheet(context, value);
        if (mounted) context.pop();
      case Err<IssuedPassword>(:final failure):
        setState(() {
          _busy = false;
          if (failure is ValidationFailure && failure.fields.isNotEmpty) {
            _fields.addAll(failure.fields);
          } else {
            _failure = failure;
          }
        });
    }
  }

  String? _error(String field) {
    final problem = _fields[field];
    return problem == null ? null : context.strings.fieldProblemMessage(problem);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final failure = _failure;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const BackOrHomeButton(),
        title: Text(strings.createAccountTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (failure != null) ...[
                  AppBanner(message: strings.failureMessage(failure), tone: StatusTone.danger),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(strings.accountTypeLabel, style: AppTypography.caption),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<UserRole>(
                  segments: [
                    ButtonSegment(value: UserRole.instructor, label: Text(strings.roleName(UserRole.instructor))),
                    ButtonSegment(value: UserRole.student, label: Text(strings.roleName(UserRole.student))),
                  ],
                  selected: {_role},
                  onSelectionChanged: _busy
                      ? null
                      : (selection) => setState(() {
                          _role = selection.first;
                          _failure = null;
                        }),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _name,
                  label: strings.fullNameLabel,
                  errorText: _error('fullName'),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  enabled: !_busy,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _email,
                  label: strings.emailLabel,
                  errorText: _error('email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_submit()),
                  enabled: !_busy,
                  ltr: true,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(strings.createAccountHint, style: AppTypography.caption),
                const SizedBox(height: AppSpacing.xl),
                AppButton(label: strings.createAccountButton, busy: _busy, onPressed: () => unawaited(_submit())),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
