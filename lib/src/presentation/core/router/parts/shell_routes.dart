part of '../router.dart';

/// The persistent tab shell: Home, Presets, History.
StatefulShellRoute _shellRoutes(Ref ref) {
  return StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) {
      return NavigationShell(statefulNavigationShell: navigationShell);
    },
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.home.path,
            name: Routes.home.name,
            pageBuilder: (context, state) {
              return const MaterialPage(child: HomePage());
            },
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.presets.path,
            name: Routes.presets.name,
            pageBuilder: (context, state) {
              return const MaterialPage(child: PresetsPage());
            },
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: Routes.history.path,
            name: Routes.history.name,
            pageBuilder: (context, state) {
              return const MaterialPage(child: HistoryPage());
            },
          ),
        ],
      ),
    ],
  );
}
