import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import 'routes.dart';

/// 5-tab bottom-navigation shell used by the StatefulShellRoute.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({required this.shell, super.key});

  final StatefulNavigationShell shell;

  static const _tabs = [
    (label: 'Today', icon: Icons.today_outlined, activeIcon: Icons.today),
    (
      label: 'Calendar',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
    ),
    (label: 'Lists', icon: Icons.list_outlined, activeIcon: Icons.list),
    (
      label: 'Track',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart,
    ),
    (label: 'More', icon: Icons.more_horiz, activeIcon: Icons.more_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark ? DesignTokens.lineDark : DesignTokens.lineLight;

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: lineColor, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: shell.currentIndex,
          elevation: 0,
          onTap: (index) =>
              shell.goBranch(index, initialLocation: index == shell.currentIndex),
          items: _tabs
              .map(
                (t) => BottomNavigationBarItem(
                  icon: Icon(t.icon),
                  activeIcon: Icon(t.activeIcon),
                  label: t.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Extension point: tab index → root route mapping used by deep links.
extension ShellRouteHelper on GoRouter {
  static const tabRoutes = [
    Routes.today,
    Routes.calendar,
    Routes.lists,
    Routes.track,
    Routes.more,
  ];
}

