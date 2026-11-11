/// OWNER: T3 (editor state).
///
/// Frozen DI contract for the editor session. The page reads
/// `editorSessionProvider(id)`; everything else in the editor is reached
/// through the [EditorSession] it returns.
library;

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/base/result.dart';
import '../../../core/logger/log.dart';
import '../../../domain/entities/document.dart';
import '../../../domain/entities/watermark_element.dart';
import '../../../domain/failures/business_failure.dart';
import '../../../presentation/features/watermark_editor/controller/editor_controller.dart';
import '../../../presentation/features/watermark_editor/controller/pending_preset.dart';
import 'import_providers.dart';
import 'presets_providers.dart';

part 'editor_providers.g.dart';

/// Everything the editor needs to open one document.
///
/// [config] and [pageIndex] are the values the session opened with; the
/// live draft is [controller.config]. The page renders from the controller
/// and never writes through these fields.
final class EditorSession {
  const EditorSession({
    required this.documentId,
    required this.document,
    required this.config,
    required this.pageIndex,
    required this.controller,
    this.appliedPresetId,
  });

  final String documentId;
  final DocumentEntity document;

  /// The configuration loaded from storage (or the applied preset).
  final WatermarkConfig config;

  /// The page the session opened on.
  final int pageIndex;

  /// The mutable draft. It is disposed with the provider and flushes any
  /// unsaved edit before it goes.
  final EditorController controller;

  /// The preset the presets screen handed over, if one was requested. The
  /// page clears the handoff after it has been consumed.
  final String? appliedPresetId;
}

/// Loads one document's stored watermark configuration into a controller.
///
/// The provider only reads: the preset handoff is consumed by the page in
/// a callback, never here. A corrupt stored config opens as an empty draft
/// rather than blocking the editor — the user can still watermark, and the
/// next save replaces the broken payload.
@riverpod
Future<EditorSession> editorSession(Ref ref, String documentId) async {
  final repository = ref.watch(documentRepositoryProvider);
  final pendingPresetId = readPendingPresetId(ref);

  final loaded = await repository.get(documentId);
  if (!ref.mounted) throw const BusinessFailure.cancelled();

  final document = switch (loaded) {
    Success(:final data) => data,
    Error() => throw const BusinessFailure.notFound(),
  };
  if (document == null) throw const BusinessFailure.notFound();

  var config = _storedConfig(document);

  if (pendingPresetId != null) {
    final applied = await _applyPreset(
      ref,
      presetId: pendingPresetId,
      documentId: documentId,
    );
    if (applied != null) config = applied;
    if (!ref.mounted) throw const BusinessFailure.cancelled();
  }

  final controller = EditorController(
    document: document,
    config: config,
    repository: repository,
  );
  ref.onDispose(controller.dispose);

  return EditorSession(
    documentId: documentId,
    document: document,
    config: config,
    pageIndex: controller.pageIndex,
    controller: controller,
    appliedPresetId: pendingPresetId,
  );
}

/// Picks the source image for a new image watermark.
///
/// The picker sits behind a provider so the editor widget tests never need
/// a platform plugin: they override this with a fake that returns bytes.
abstract interface class EditorImagePicker {
  /// The chosen image's bytes, or null when the user cancelled.
  Future<Uint8List?> pickImage();
}

/// The gallery picker used on device.
final class GalleryEditorImagePicker implements EditorImagePicker {
  const GalleryEditorImagePicker();

  @override
  Future<Uint8List?> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    return picked?.readAsBytes();
  }
}

@Riverpod(keepAlive: true)
EditorImagePicker editorImagePicker(Ref ref) =>
    const GalleryEditorImagePicker();

WatermarkConfig _storedConfig(DocumentEntity document) {
  final stored = document.watermarkConfigJson;
  if (stored == null || stored.isEmpty) return WatermarkConfig.empty;

  try {
    return WatermarkConfig.fromJsonString(stored);
  } catch (error) {
    // A malformed payload is not worth blocking the editor over. Log the
    // type only: the stored string can carry user content.
    Log.warning('Unreadable watermark config: ${error.runtimeType}');

    return WatermarkConfig.empty;
  }
}

/// Loads a pending preset through the preset repository seam.
///
/// Returns null when the preset cannot be resolved, so the caller keeps
/// the document's own configuration.
Future<WatermarkConfig?> _applyPreset(
  Ref ref, {
  required String presetId,
  required String documentId,
}) async {
  try {
    final presets = ref.read(presetRepositoryProvider);
    final result = await presets.apply(presetId, documentId);
    if (!ref.mounted) return null;

    return switch (result) {
      Success(:final data) => WatermarkConfig(
        elements: List<WatermarkElement>.of(data),
      ),
      Error() => null,
    };
  } catch (error) {
    Log.warning('Pending preset unavailable: ${error.runtimeType}');

    return null;
  }
}
