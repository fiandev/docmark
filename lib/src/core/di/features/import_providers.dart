/// OWNER: T2 (document import).
///
/// DI for importing documents and normalizing media. The document store
/// is the Drift + vault implementation from T1; the picker, the normalizer
/// and the pre-import PDF page renderer are injected here so the picker UI
/// can be tested with fakes and no plugins.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/repositories/document_repository_impl.dart';
import '../../../data/services/media/device_document_pick_service.dart';
import '../../../data/services/media/document_pick_service.dart';
import '../../../data/services/media/image_media_normalizer.dart';
import '../../../data/services/media/pdf_page_preview_service.dart';
import '../../../data/services/media/pdfrx_pdf_page_preview_service.dart';
import '../../../domain/repositories/document_repository.dart';
import '../../../domain/services/media_normalizer.dart';
import '../dependency_injection.dart';
import 'security_providers.dart';
import 'storage_providers.dart';

export '../../../data/services/media/document_format_validator.dart';
export '../../../data/services/media/document_pick_service.dart';
export '../../../data/services/media/pdf_page_preview_service.dart';

part 'import_providers.g.dart';

/// The document store used by the picker and the editor.
@Riverpod(keepAlive: true)
DocumentRepository documentRepository(Ref ref) => DocumentRepositoryImpl(
  crashReporter: ref.watch(crashReporterProvider),
  database: ref.watch(appDatabaseProvider),
  vault: ref.watch(secureFileVaultProvider),
  normalizer: ref.watch(mediaNormalizerServiceProvider),
  images: ref.watch(watermarkAssetStoreProvider),
);

/// Re-encodes image watermarks as PNG and probes imported bytes.
@Riverpod(keepAlive: true)
MediaNormalizerService mediaNormalizerService(Ref ref) =>
    const ImageMediaNormalizer();

/// Gallery and file-manager pickers. Widget tests override this with a
/// fake that returns bytes, so no platform channel is ever touched.
@Riverpod(keepAlive: true)
DocumentPickService documentPickService(Ref ref) =>
    const DeviceDocumentPickService();

/// Renders PDF page thumbnails before the document has an id.
@Riverpod(keepAlive: true)
PdfPagePreviewService pdfPagePreview(Ref ref) =>
    const PdfrxPdfPagePreviewService();
