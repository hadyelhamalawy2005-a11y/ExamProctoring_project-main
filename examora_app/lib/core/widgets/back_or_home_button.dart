import 'package:examora_app/app/router/router_guard.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The leading button of an app bar: back when there is somewhere to go back to, otherwise the signed-in role's home.
///
/// A screen opened by a deep link has no history, so without this it would be a dead end. The choice is made again every
/// time the route changes AND at the moment of the tap, so a screen that stayed built underneath another one never offers
/// a "back" that is no longer there.
class BackOrHomeButton extends ConsumerWidget {
  /// Creates the button.
  const BackOrHomeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = context.strings;
    final router = GoRouter.of(context);
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final canPop = context.canPop();
        return IconButton(
          tooltip: strings.back,
          icon: Icon(canPop ? Icons.arrow_back : Icons.home_outlined),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            final auth = ref.read(authControllerProvider);
            if (auth is AuthSignedIn) context.go(homeFor(auth.account.role));
          },
        );
      },
    );
  }
}
