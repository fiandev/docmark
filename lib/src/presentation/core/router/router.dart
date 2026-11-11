import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/extensions/riverpod_extensions.dart';
import '../../../domain/services/render_contract.dart';
import '../../features/app_lock/view/lock_page.dart';
import '../../features/document_import/view/document_picker_page.dart';
import '../../features/export/view/export_preview_page.dart';
import '../../features/history/view/history_page.dart';
import '../../features/home/view/home_page.dart';
import '../../features/onboarding/view/onboarding_page.dart';
import '../../features/presets/view/presets_page.dart';
import '../../features/settings/view/settings_page.dart';
import '../../features/splash/view/splash_page.dart';
import '../../features/watermark_editor/view/editor_page.dart';
import '../widgets/navigation_shell.dart';
import '../widgets/not_found_screen.dart';
import '../widgets/startup/startup_widget.dart';
import 'redirect_gate.dart';
import 'router_state/router_state_provider.dart';
import 'routes.dart';

part 'parts/docmark_routes.dart';
part 'parts/on_boarding_routes.dart';
part 'parts/shell_routes.dart';
part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'Root');

@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  final refresh = ref.asListenable(routerStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    refreshListenable: refresh,
    initialLocation: Routes.splash.path,
    redirect: (context, state) =>
        RedirectGate.redirect(state.uri.path, ref.read(routerStateProvider)),
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
    routes: [
      ..._onboardingRoutes(ref),
      ..._docmarkRoutes(ref),
      _shellRoutes(ref),
    ],
  );
}
