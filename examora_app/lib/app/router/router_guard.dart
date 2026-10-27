import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/features/authentication/domain/user_role.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';

/// Where each role lands after signing in.
String homeFor(UserRole role) => switch (role) {
  UserRole.student => RoutePaths.studentDashboard,
  UserRole.instructor => RoutePaths.instructorDashboard,
  UserRole.administrator => RoutePaths.adminAccounts,
};

/// True when [path] is inside the area that belongs to [role].
bool pathBelongsTo(UserRole role, String path) {
  final prefix = switch (role) {
    UserRole.student => '/student',
    UserRole.instructor => '/instructor',
    UserRole.administrator => '/admin',
  };
  return path == prefix || path.startsWith('$prefix/');
}

/// The one redirect rule of the whole app, in the order the specification gives:
///
/// 1. While the stored session is being resolved, hold on the splash screen (remembering where the link was going).
/// 2. Signed out: only the sign-in routes are reachable.
/// 3. A pending password change outranks everything: the only reachable screen is "change password".
/// 4. Role separation: each role reaches only its own area; anything else goes to that role's home, not a dead end.
///
/// Returns the location to go to, or null to stay. The router uses exactly this function; tests exercise it through the
/// real router.
String? resolveRedirect({required AuthState auth, required Uri location}) {
  final path = location.path;
  final isSplash = path == RoutePaths.splash;

  switch (auth) {
    case AuthResolving():
      if (isSplash) return null;
      return _splashWith(location);

    case AuthSignedOut():
      if (path == RoutePaths.login || path == RoutePaths.forgotPassword) return null;
      if (isSplash) {
        final from = location.queryParameters[RoutePaths.fromParameter];
        final target = from == null ? null : _safeInternalPath(from);
        // A link to an auth screen is followed as it is; anything else is remembered and sent through sign-in first.
        if (target != null && Uri.parse(target).path == RoutePaths.forgotPassword) return RoutePaths.forgotPassword;
        return _loginWith(from);
      }
      return _loginWith(location.toString());

    case AuthSignedIn(:final account):
      if (account.mustChangePassword) {
        return path == RoutePaths.changePassword ? null : RoutePaths.changePassword;
      }
      final home = homeFor(account.role);
      // The splash (a cold start with a link) and the sign-in screen (the user just signed in after being sent there by a
      // link) both resume the remembered link, but only when it belongs to the signed-in role.
      if (isSplash || path == RoutePaths.login) {
        final from = location.queryParameters[RoutePaths.fromParameter];
        final target = from == null ? null : _safeInternalPath(from);
        if (target != null && pathBelongsTo(account.role, Uri.parse(target).path)) return target;
        return home;
      }
      if (path == RoutePaths.forgotPassword) return home;
      if (path == RoutePaths.changePassword) return null;
      if (!pathBelongsTo(account.role, path)) return home;
      return null;
  }
}

String _splashWith(Uri location) =>
    Uri(path: RoutePaths.splash, queryParameters: {RoutePaths.fromParameter: location.toString()}).toString();

String _loginWith(String? from) {
  final target = from == null ? null : _safeInternalPath(from);
  if (target == null || target == RoutePaths.splash || target.startsWith(RoutePaths.login)) {
    return RoutePaths.login;
  }
  return Uri(path: RoutePaths.login, queryParameters: {RoutePaths.fromParameter: target}).toString();
}

/// Only app-internal paths are followed after sign-in; anything else (another site, a protocol-relative address) is
/// ignored.
String? _safeInternalPath(String value) {
  if (!value.startsWith('/') || value.startsWith('//')) return null;
  return value;
}
