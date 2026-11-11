part of '../router.dart';

/// The app routes outside the tab shell: the picker, the editor, export
/// preview, settings, and the App Lock screen.
List<GoRoute> _docmarkRoutes(Ref ref) {
  return [
    GoRoute(
      path: Routes.documentPicker.path,
      name: Routes.documentPicker.name,
      pageBuilder: (context, state) {
        return const MaterialPage(child: DocumentPickerPage());
      },
    ),
    GoRoute(
      path: Routes.editor.path,
      name: Routes.editor.name,
      pageBuilder: (context, state) {
        final documentId = state.pathParameters['documentId'] ?? '';

        return MaterialPage(child: EditorPage(documentId: documentId));
      },
    ),
    GoRoute(
      path: Routes.exportPreview.path,
      name: Routes.exportPreview.name,
      pageBuilder: (context, state) {
        final extra = state.extra;
        final request = extra is ExportRequest
            ? extra
            : ExportRequest.placeholder;

        return MaterialPage(child: ExportPreviewPage(request: request));
      },
    ),
    GoRoute(
      path: Routes.settings.path,
      name: Routes.settings.name,
      pageBuilder: (context, state) {
        return const MaterialPage(child: SettingsPage());
      },
    ),
    GoRoute(
      path: Routes.lock.path,
      name: Routes.lock.name,
      pageBuilder: (context, state) {
        return const MaterialPage(child: LockPage());
      },
    ),
  ];
}
