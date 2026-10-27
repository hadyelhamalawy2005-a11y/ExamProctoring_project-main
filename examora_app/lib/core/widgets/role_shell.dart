import 'package:examora_app/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// One tab of the bottom navigation.
class ShellDestination {
  /// Creates a destination.
  const ShellDestination({required this.icon, required this.selectedIcon, required this.label});

  /// Icon when not selected.
  final IconData icon;

  /// Icon when selected.
  final IconData selectedIcon;

  /// Returns the tab's label in the current language.
  final String Function(BuildContext context) label;
}

/// The bottom-navigation frame the student and instructor areas share. The administrator's area has none, so every
/// administrator screen is pushed and keeps its own back button.
class RoleShell extends StatelessWidget {
  /// Creates the shell around [shell], the branch navigator go_router builds.
  const RoleShell({required this.shell, required this.destinations, super.key});

  /// The branch container; its `currentIndex` is the selected tab.
  final StatefulNavigationShell shell;

  /// The tabs, in branch order.
  final List<ShellDestination> destinations;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (index) => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label(context),
            ),
        ],
      ),
    );
  }
}

/// The student's tabs.
final List<ShellDestination> studentDestinations = [
  ShellDestination(icon: Icons.home_outlined, selectedIcon: Icons.home, label: (context) => context.strings.homeTab),
  ShellDestination(
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    label: (context) => context.strings.examsTab,
  ),
  ShellDestination(
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
    label: (context) => context.strings.resultsTab,
  ),
  ShellDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: (context) => context.strings.profileTab,
  ),
];

/// The instructor's tabs.
final List<ShellDestination> instructorDestinations = [
  ShellDestination(icon: Icons.home_outlined, selectedIcon: Icons.home, label: (context) => context.strings.homeTab),
  ShellDestination(
    icon: Icons.assignment_outlined,
    selectedIcon: Icons.assignment,
    label: (context) => context.strings.examsTab,
  ),
  ShellDestination(
    icon: Icons.report_gmailerrorred_outlined,
    selectedIcon: Icons.report,
    label: (context) => context.strings.incidentsTab,
  ),
  ShellDestination(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: (context) => context.strings.profileTab,
  ),
];
