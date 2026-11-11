import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/features/editor_providers.dart';
import '../../../../core/di/features/import_providers.dart';
import '../../../../core/di/features/security_providers.dart';
import '../../../../core/di/features/storage_providers.dart';
import '../../../../core/extensions/localization.dart';
import '../../../../domain/services/render_contract.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/failure_view.dart';
import '../../../core/widgets/preset_save_dialog.dart';
import '../../../core/widgets/text/typography.dart';
import '../controller/editor_image_cache.dart';
import '../controller/pending_preset.dart';
import '../widgets/editor_canvas.dart';
import '../widgets/editor_inspector.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/layers_sheet.dart';

/// The watermark editor.
///
/// OWNER: T3 (state) and T4 (canvas). The constructor signature is final:
/// the router passes the document id and the editor loads everything else.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({required this.documentId, super.key});

  final String documentId;

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  EditorImageCache? _images;
  ProviderSubscription<AsyncValue<EditorSession>>? _sessionSub;
  EditorSession? _session;
  final Set<String> _requestedAssets = <String>{};
  bool _pendingCleared = false;

  @override
  void initState() {
    super.initState();
    _images = EditorImageCache(
      store: ref.read(watermarkAssetStoreProvider),
      vault: ref.read(secureFileVaultProvider),
    );
    _sessionSub = ref.listenManual<AsyncValue<EditorSession>>(
      editorSessionProvider(widget.documentId),
      (previous, next) {
        if (next case AsyncData(:final value)) _onSession(value);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _sessionSub?.close();
    final session = _session;
    session?.controller.removeListener(_onDraftChanged);
    if (session != null) unawaited(session.controller.flush());
    _images?.dispose();
    super.dispose();
  }

  void _onSession(EditorSession session) {
    if (!identical(_session, session)) {
      _session?.controller.removeListener(_onDraftChanged);
      _session = session;
      session.controller.addListener(_onDraftChanged);
    }

    // The preset handoff is a one-shot: consume it once the draft is open.
    // The clear waits for a frame so no provider is written during build.
    if (!_pendingCleared && session.appliedPresetId != null) {
      _pendingCleared = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) clearPendingPresetId(ref);
      });
    }

    _syncAssets(session.controller.imageAssetIds);
  }

  void _onDraftChanged() {
    _syncAssets(_session?.controller.imageAssetIds ?? const <String>[]);
  }

  void _syncAssets(List<String> assetIds) {
    final images = _images;
    if (images == null) return;

    final missing = <String>[
      for (final id in assetIds)
        if (_requestedAssets.add(id)) id,
    ];
    if (missing.isEmpty) return;

    unawaited(images.preload(missing));
  }

  Future<void> _addImage(EditorSession session) async {
    final l10n = context.locale;

    try {
      final picked = await ref.read(editorImagePickerProvider).pickImage();
      if (picked == null || !mounted) return;

      final normalized = await ref
          .read(mediaNormalizerServiceProvider)
          .normalizeAsPng(picked);
      final stored = await ref
          .read(watermarkAssetStoreProvider)
          .putImage(
            bytes: normalized.pngBytes,
            extension: 'png',
            mime: 'image/png',
          );
      if (!mounted) return;

      final size = Size(
        normalized.width.toDouble(),
        normalized.height.toDouble(),
      );
      session.controller.addImage(stored.id, naturalSize: size);
      _syncAssets(<String>[stored.id]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.editor_imageImportFailed)),
      );
    }
  }

  void _savePreset(EditorSession session) {
    unawaited(
      PresetSaveDialog.show(
        context,
        elements: session.controller.config.elements,
      ),
    );
  }

  Future<void> _export(EditorSession session) async {
    await session.controller.flush();
    if (!mounted) return;

    unawaited(
      context.pushNamed(
        Routes.exportPreview.name,
        extra: ExportRequest(
          document: session.document,
          config: session.controller.config,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.locale;
    final sessionAsync = ref.watch(editorSessionProvider(widget.documentId));

    return sessionAsync.when(
      loading: () => _EditorScaffold(
        title: l10n.editor_title,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _EditorScaffold(
        title: l10n.editor_title,
        child: FailureView(
          error: error,
          onRetry: () =>
              ref.invalidate(editorSessionProvider(widget.documentId)),
        ),
      ),
      data: (session) {
        final controller = session.controller;
        final images = _images;
        if (images == null) {
          return _EditorScaffold(
            title: l10n.editor_title,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return _EditorScaffold(
          title: session.document.name.isEmpty
              ? l10n.editor_title
              : session.document.name,
          actions: [
            IconButton(
              tooltip: l10n.editor_savePreset,
              onPressed: () => _savePreset(session),
              icon: const Icon(Icons.bookmark_add_outlined),
            ),
            IconButton(
              tooltip: l10n.editor_export,
              onPressed: () => unawaited(_export(session)),
              icon: const Icon(Icons.ios_share),
            ),
          ],
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, child) {
              return Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: EditorCanvas(
                      controller: controller,
                      images: images,
                    ),
                  ),
                  Flexible(
                    flex: 2,
                    child: EditorInspector(
                      controller: controller,
                      images: images,
                    ),
                  ),
                  EditorToolbar(
                    onAddText: controller.addText,
                    onAddImage: () => unawaited(_addImage(session)),
                    onLayers: () => unawaited(
                      showLayersSheet(context, controller: controller),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _EditorScaffold extends StatelessWidget {
  const _EditorScaffold({
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: HeadingLevel3Text(title),
        actions: actions,
      ),
      body: SafeArea(child: child),
    );
  }
}
