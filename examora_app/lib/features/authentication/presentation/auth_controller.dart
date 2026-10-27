import 'dart:async';

import 'package:examora_app/core/errors/app_failure.dart';
import 'package:examora_app/core/result/result.dart';
import 'package:examora_app/features/authentication/data/auth_providers.dart';
import 'package:examora_app/features/authentication/domain/account.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Who is using the app right now.
@immutable
sealed class AuthState {
  /// Creates a state.
  const AuthState();
}

/// The stored session is still being read. The router holds on the splash screen, so a signed-in user is never flashed
/// the login screen on launch.
final class AuthResolving extends AuthState {
  /// Creates the state.
  const AuthResolving();
}

/// Nobody is signed in.
final class AuthSignedOut extends AuthState {
  /// Creates the state. [notice] explains why the user is back at sign-in when it was not their choice.
  const AuthSignedOut({this.notice});

  /// Why the session ended without the user asking, if it did.
  final AppFailure? notice;
}

/// A signed-in account.
final class AuthSignedIn extends AuthState {
  /// Creates the state.
  const AuthSignedIn(this.account);

  /// Who is signed in.
  final Account account;
}

/// The provider of [AuthState].
final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Signs in and out and keeps [AuthState] current. Screens and the router read only this.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    unawaited(Future<void>.microtask(_restore));
    return const AuthResolving();
  }

  Future<void> _restore() async {
    final result = await ref.read(authRepositoryProvider).restoreSession();
    if (!ref.mounted) return;
    state = switch (result) {
      Ok<Account?>(:final value) => value == null ? const AuthSignedOut() : AuthSignedIn(value),
      Err<Account?>(:final failure) => AuthSignedOut(notice: failure),
    };
  }

  /// Signs in. On success the state becomes [AuthSignedIn] and the router moves on by itself.
  Future<Result<Account>> signIn({required String email, required String password}) async {
    final result = await ref.read(authRepositoryProvider).signIn(email: email, password: password);
    if (ref.mounted && result is Ok<Account>) {
      state = AuthSignedIn(result.value);
    }
    return result;
  }

  /// Signs out. Always succeeds.
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (ref.mounted) state = const AuthSignedOut();
  }

  /// Changes the password. On success a pending forced change is cleared, which releases the router.
  Future<Result<Account>> changePassword({required String currentPassword, required String newPassword}) async {
    final result = await ref
        .read(authRepositoryProvider)
        .changePassword(currentPassword: currentPassword, newPassword: newPassword);
    if (ref.mounted && result is Ok<Account>) {
      state = AuthSignedIn(result.value);
    } else if (ref.mounted && result is Err<Account> && result.failure is SessionExpiredFailure) {
      state = AuthSignedOut(notice: result.failure);
    }
    return result;
  }
}
