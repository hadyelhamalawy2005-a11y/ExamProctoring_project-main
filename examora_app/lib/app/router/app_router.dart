import 'package:examora_app/app/router/route_paths.dart';
import 'package:examora_app/app/router/router_guard.dart';
import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:examora_app/core/widgets/back_or_home_button.dart';
import 'package:examora_app/core/widgets/role_shell.dart';
import 'package:examora_app/features/administration/presentation/account_detail_screen.dart';
import 'package:examora_app/features/administration/presentation/account_list_screen.dart';
import 'package:examora_app/features/administration/presentation/create_account_screen.dart';
import 'package:examora_app/features/authentication/presentation/auth_controller.dart';
import 'package:examora_app/features/authentication/presentation/change_password_screen.dart';
import 'package:examora_app/features/authentication/presentation/forgot_password_screen.dart';
import 'package:examora_app/features/authentication/presentation/login_screen.dart';
import 'package:examora_app/features/authentication/presentation/splash_screen.dart';
import 'package:examora_app/features/exam_session/presentation/attempt_result_screen.dart';
import 'package:examora_app/features/exam_session/presentation/briefing_screen.dart';
import 'package:examora_app/features/exam_session/presentation/consent_screen.dart';
import 'package:examora_app/features/exam_session/presentation/exam_player_screen.dart';
import 'package:examora_app/features/exam_session/presentation/instructor_attempts_screen.dart';
import 'package:examora_app/features/exam_session/presentation/student_dashboard.dart';
import 'package:examora_app/features/exam_session/presentation/student_exam_list_screen.dart';
import 'package:examora_app/features/exam_session/presentation/system_check_screen.dart';
import 'package:examora_app/features/exams/presentation/exam_method_screen.dart';
import 'package:examora_app/features/exams/presentation/exam_wizard_screen.dart';
import 'package:examora_app/features/exams/presentation/instructor_dashboard.dart';
import 'package:examora_app/features/exams/presentation/instructor_exam_list_screen.dart';
import 'package:examora_app/features/incident_review/presentation/incident_detail_screen.dart';
import 'package:examora_app/features/incident_review/presentation/incident_queue_screen.dart';
import 'package:examora_app/features/profile/presentation/profile_screen.dart';
import 'package:examora_app/features/word_import/presentation/word_import_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Where the router starts. Always the splash screen in the app; tests override it to open a deep link through the real
/// router and the real guard.
final initialLocationProvider = Provider<String>((ref) => RoutePaths.splash);

/// The app's router: every route in the specification and one guard ([resolveRedirect]).
///
/// The guard runs again whenever [AuthState] changes, so signing out, a forced password change or an expired session move
/// the user immediately, and a deep link can never bypass sign-in or cross roles.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..onDispose(refresh.dispose)
    ..listen<AuthState>(authControllerProvider, (previous, next) {
      // The guard only needs to run again when something it looks at changed. Re-running it for every new account object
      // would race with the user's own navigation (for example a pop right after a voluntary password change).
      if (_routingKey(previous) != _routingKey(next)) refresh.value++;
    });

  final router = GoRouter(
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(auth: ref.read(authControllerProvider), location: state.uri),
    errorBuilder: (context, state) => _NotFoundScreen(location: state.uri.toString()),
    routes: _routes,
  );
  ref.onDispose(router.dispose);
  return router;
});

/// What the guard looks at: signed in or out, the role, and the forced-password flag.
String _routingKey(AuthState? state) => switch (state) {
  null => 'none',
  AuthResolving() => 'resolving',
  AuthSignedOut() => 'signed-out',
  AuthSignedIn(:final account) => 'signed-in:${account.role.name}:${account.mustChangePassword}',
};

final List<RouteBase> _routes = [
  GoRoute(path: RoutePaths.splash, builder: (context, state) => const SplashScreen()),
  GoRoute(path: RoutePaths.login, builder: (context, state) => const LoginScreen()),
  GoRoute(path: RoutePaths.forgotPassword, builder: (context, state) => const ForgotPasswordScreen()),
  GoRoute(path: RoutePaths.changePassword, builder: (context, state) => const ChangePasswordScreen()),

  // ---- Student: bottom navigation, then full-screen exam routes ----
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => RoleShell(shell: shell, destinations: studentDestinations),
    branches: [
      StatefulShellBranch(
        routes: [GoRoute(path: RoutePaths.studentDashboard, builder: (context, state) => const StudentDashboard())],
      ),
      StatefulShellBranch(
        routes: [GoRoute(path: RoutePaths.studentExams, builder: (context, state) => const StudentExamListScreen())],
      ),
      StatefulShellBranch(
        routes: [GoRoute(path: RoutePaths.studentResults, builder: (context, state) => const StudentResultsScreen())],
      ),
      StatefulShellBranch(
        routes: [GoRoute(path: RoutePaths.studentProfile, builder: (context, state) => const ProfileScreen())],
      ),
    ],
  ),
  GoRoute(
    path: '/student/exams/:examId',
    builder: (context, state) => BriefingScreen(examId: state.pathParameters['examId']!),
    routes: [
      GoRoute(
        path: 'consent',
        builder: (context, state) => ConsentScreen(examId: state.pathParameters['examId']!),
      ),
      GoRoute(
        path: 'system-check',
        builder: (context, state) => SystemCheckScreen(examId: state.pathParameters['examId']!),
      ),
    ],
  ),
  GoRoute(
    path: '/student/attempts/:attemptId',
    builder: (context, state) => ExamPlayerScreen(
      attemptId: state.pathParameters['attemptId']!,
      cameraMissing: state.uri.queryParameters[RoutePaths.cameraParameter] == cameraMissingValue,
    ),
    routes: [
      GoRoute(
        path: 'result',
        builder: (context, state) => AttemptResultScreen(attemptId: state.pathParameters['attemptId']!),
      ),
    ],
  ),

  // ---- Instructor: bottom navigation, then full-screen routes ----
  StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => RoleShell(shell: shell, destinations: instructorDestinations),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(path: RoutePaths.instructorDashboard, builder: (context, state) => const InstructorDashboard()),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(path: RoutePaths.instructorExams, builder: (context, state) => const InstructorExamListScreen()),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(path: RoutePaths.instructorIncidents, builder: (context, state) => const IncidentQueueScreen()),
        ],
      ),
      StatefulShellBranch(
        routes: [GoRoute(path: RoutePaths.instructorProfile, builder: (context, state) => const ProfileScreen())],
      ),
    ],
  ),
  // Literal paths are declared before their ":id" siblings, or "new" would be read as an exam id.
  GoRoute(path: RoutePaths.instructorNewExamMethod, builder: (context, state) => const ExamMethodScreen()),
  GoRoute(
    path: '/instructor/exams/:examId/edit',
    builder: (context, state) => ExamWizardScreen(
      examId: state.pathParameters['examId']!,
      method: state.uri.queryParameters[RoutePaths.methodParameter],
    ),
  ),
  GoRoute(
    path: '/instructor/exams/:examId/import',
    builder: (context, state) => WordImportScreen(examId: state.pathParameters['examId']!),
  ),
  GoRoute(
    path: '/instructor/exams/:examId/attempts',
    builder: (context, state) => InstructorAttemptsScreen(examId: state.pathParameters['examId']!),
  ),
  GoRoute(
    path: '/instructor/incidents/:incidentId',
    builder: (context, state) => IncidentDetailScreen(incidentId: state.pathParameters['incidentId']!),
  ),

  // ---- Administrator: no bottom navigation, so every screen below /admin/accounts is PUSHED, never `go` ----
  GoRoute(
    path: RoutePaths.adminAccounts,
    builder: (context, state) => const AccountListScreen(),
    routes: [
      GoRoute(
        path: ':accountId',
        builder: (context, state) => AccountDetailScreen(accountId: state.pathParameters['accountId']!),
      ),
    ],
  ),
  GoRoute(path: RoutePaths.adminNewInstructor, builder: (context, state) => const CreateAccountScreen()),
  GoRoute(path: RoutePaths.adminProfile, builder: (context, state) => const ProfileScreen(showBackButton: true)),
];

/// Shown for a path that matches no route. Always offers a way out.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(leading: const BackOrHomeButton(), title: Text(strings.failureNotFound)),
      body: Center(child: Text(strings.failureNotFound)),
    );
  }
}
