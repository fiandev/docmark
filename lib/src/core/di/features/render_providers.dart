/// OWNER: T7 (render + export).
///
/// Frozen DI contract for rasterizing and exporting. The renderer itself
/// lives in the data layer; the page painter is injected from the shared
/// presentation widget so preview and export use one drawing routine.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/base/result.dart';
import '../../../data/services/render/pdf_page_rasterizer.dart';
import '../../../data/services/render/watermark_renderer_impl.dart';
import '../../../domain/services/render_contract.dart';
import '../../../presentation/core/widgets/watermark/watermark_canvas.dart';
import 'import_providers.dart';
import 'security_providers.dart';
import 'storage_providers.dart';

part 'render_providers.g.dart';

/// Mutable choices the export screen owns and the renderer reads.
///
/// The renderer interface is frozen and carries no JPEG quality, so the
/// value lives here and reaches the encoder through a getter.
final class ExportSettings {
  ExportSettings({this.jpegQuality = 0.92});

  double jpegQuality;
}

@Riverpod(keepAlive: true)
ExportSettings exportSettings(Ref ref) => ExportSettings();

/// Native PDF page rasterization.
@Riverpod(keepAlive: true)
PdfPageRasterizer pdfPageRasterizer(Ref ref) => const PdfrxPageRasterizer();

/// Renders previews and export bytes. Never writes plaintext to disk.
///
/// Image watermarks are stored under a generated blob name, so an id is
/// resolved to its blob path through the asset store before the vault is
/// read.
@Riverpod(keepAlive: true)
WatermarkRenderer watermarkRenderer(Ref ref) {
  return WatermarkRendererImpl(
    painter: paintWatermarkElements,
    rasterizer: ref.watch(pdfPageRasterizerProvider),
    pageLoader: (documentId, pageIndex) async {
      final result = await ref
          .read(documentRepositoryProvider)
          .readPage(documentId, pageIndex);

      return switch (result) {
        Success(:final data) => data,
        Error(:final error) => throw StateError(
          'Could not read document page: ${error.runtimeType}',
        ),
      };
    },
    assetLoader: (assetId) async {
      final store = ref.read(watermarkAssetStoreProvider);
      final reference = await store.refFor(assetId);
      if (reference == null) return null;
      final vault = ref.read(secureFileVaultProvider);
      if (!await vault.exists(reference)) return null;

      return vault.read(reference);
    },
    jpegQuality: () => ref.read(exportSettingsProvider).jpegQuality,
  );
}
