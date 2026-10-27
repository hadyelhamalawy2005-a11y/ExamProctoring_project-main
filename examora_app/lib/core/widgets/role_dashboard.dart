import 'package:examora_app/app/theme/design_tokens.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/l10n/planned_feature.dart';
import 'package:examora_app/core/widgets/app_card.dart';
import 'package:examora_app/core/widgets/feature_not_built_view.dart';
import 'package:examora_app/core/widgets/responsive_content.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A role's home: a real welcome for the signed-in person, and an honest notice for the parts not built yet.
class RoleDashboard extends ConsumerWidget {
  /// Creates the dashboard. [feature] names what the rest of the home screen will show once it is built.
  const RoleDashboard({required this.feature, super.key});

  /// What the home screen will contain.
  final PlannedFeature feature;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text(strings.appName)),
      body: SafeArea(
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (auth is AuthSignedIn)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(strings.welcomeUser(auth.account.fullName), style: AppTypography.title),
                      const SizedBox(height: AppSpacing.xs),
                      Text(strings.roleName(auth.account.role), style: AppTypography.body),
                    ],
                  ),
                ),
              Expanded(child: FeatureNotBuiltBody(feature: feature)),
            ],
          ),
        ),
      ),
    );
  }
}
