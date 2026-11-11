import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/localization.dart';
import '../theme/theme.dart';
import 'text/typography.dart';

/// The persistent tab shell: Home, Presets, History.
///
/// Branches are registered in `parts/shell_routes.dart`; the index order
/// here must match. The shell owns no gate logic — the router redirect
/// decides whether the user reaches it at all.
class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key, required this.statefulNavigationShell});

  final StatefulNavigationShell statefulNavigationShell;

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(context.locale.appTitle),
        titleSpacing: context.dimensions.space.s16,
      ),
      body: widget.statefulNavigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.statefulNavigationShell.currentIndex,
        onTap: (index) {
          widget.statefulNavigationShell.goBranch(index);
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: context.locale.common_home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bookmark_outline),
            label: context.locale.common_presets,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history),
            label: context.locale.common_history,
          ),
        ],
      ),
    );
  }
}
