/// OWNER: T2 (document import).
///
/// Frozen DI contract for importing documents and normalizing media. T2
/// replaces the throwing repository provider with the Drift + vault
/// implementation; the provider names and types stay as written.
library;

import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/repositories/document_repository.dart';
import '../../../domain/services/media_normalizer.dart';

part 'import_providers.g.dart';

/// The document store used by the picker and the editor.
@Riverpod(keepAlive: true)
DocumentRepository documentRepository(Ref ref) =>
    throw UnimplementedError('DocumentRepository is implemented by T2');

/// Re-encodes image watermarks as PNG and probes imported bytes.
@Riverpod(keepAlive: true)
MediaNormalizerService mediaNormalizerService(Ref ref) =>
    const _UnavailableMediaNormalizer();

class _UnavailableMediaNormalizer implements MediaNormalizerService {
  const _UnavailableMediaNormalizer();

  @override
  Future<NormalizedMedia> normalizeAsPng(Uint8List bytes) =>
      throw UnimplementedError('MediaNormalizerService is implemented by T2');

  @override
  Future<MediaProbe> probe(Uint8List bytes) =>
      throw UnimplementedError('MediaNormalizerService is implemented by T2');
}
