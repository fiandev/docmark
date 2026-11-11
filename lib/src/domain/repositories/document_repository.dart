import 'dart:typed_data';

import '../../core/base/result.dart';
import '../../core/base/unit.dart';
import '../entities/document.dart';
import '../entities/image_format.dart';
import '../entities/watermark_element.dart';
import '../failures/business_failure.dart';

/// Where an import came from. The picker path changes, not the pipeline.
enum ImportSource { gallery, filePicker }

/// One import request, already read into memory.
///
/// Passing bytes rather than a path keeps the repository in charge of
/// encryption and keeps the original file untouched: the picker's copy is
/// read once and immediately handed to the vault.
final class ImportRequest {
  const ImportRequest({
    required this.source,
    required this.fileName,
    required this.bytes,
    this.declaredFormat = ImageFormat.unknown,
    this.selectedPages = const [],
  });

  final ImportSource source;
  final String fileName;
  final Uint8List bytes;

  /// The format the picker claimed. [FormatProbe] is the authority; this
  /// is a hint for error messages only.
  final ImageFormat declaredFormat;

  /// For a PDF, the pages the user chose to import. Empty means all.
  final List<int> selectedPages;
}

/// Documents: import, page bytes, saved watermark configuration, deletion.
///
/// Every method returns a [Result] — a storage or decryption failure is a
/// business failure, not an exception escaping the data layer.
abstract interface class DocumentRepository {
  /// Encrypts [request] into the vault, probes its format, and persists
  /// the metadata row. Never modifies the source file.
  Future<Result<DocumentEntity, BusinessFailure>> importDocument(
    ImportRequest request,
  );

  /// Decrypted bytes for one page. An image document has exactly one page.
  Future<Result<Uint8List, BusinessFailure>> readPage(
    String documentId,
    int pageIndex,
  );

  /// Persists the watermark configuration against the document metadata.
  Future<Result<Unit, BusinessFailure>> saveWatermarkConfig(
    String documentId,
    WatermarkConfig config,
  );

  /// Deletes the metadata and every encrypted asset it owns.
  Future<Result<Unit, BusinessFailure>> delete(String documentId);

  Future<Result<List<DocumentEntity>, BusinessFailure>> list();

  Future<Result<DocumentEntity?, BusinessFailure>> get(String documentId);
}
