import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../../core/security/secure_file_vault.dart';
import '../../../../core/storage/vault/watermark_asset_store.dart';

/// Decoded watermark images for the editor preview.
///
/// The shared painter resolves images synchronously, so the canvas needs
/// its assets decoded ahead of the paint. This cache is the editor's only
/// image-decoding path; the exporter uses its own copy of the same bytes.
final class EditorImageCache extends ChangeNotifier {
  EditorImageCache({
    required WatermarkAssetStore store,
    required SecureFileVault vault,
  }) : _store = store,
       _vault = vault;

  final WatermarkAssetStore _store;
  final SecureFileVault _vault;

  final Map<String, ui.Image> _images = {};
  final Map<String, Uint8List> _bytes = {};
  final Set<String> _pending = {};

  bool _disposed = false;

  /// The decoded image for [assetId], or null while it loads or if the
  /// asset is gone.
  ui.Image? resolve(String assetId) => _images[assetId];

  /// The encrypted blob's plaintext bytes, for the crop sheet.
  Uint8List? bytesFor(String assetId) => _bytes[assetId];

  bool isPending(String assetId) => _pending.contains(assetId);

  /// Decodes every asset in [assetIds] that is not loaded yet and notifies
  /// once when at least one arrived.
  Future<void> preload(Iterable<String> assetIds) async {
    final missing = <String>[
      for (final id in assetIds)
        if (id.isNotEmpty && !_images.containsKey(id) && !_pending.contains(id))
          id,
    ];
    if (missing.isEmpty) return;

    _pending.addAll(missing);
    var loaded = false;

    for (final id in missing) {
      final bytes = await _loadBytesSafely(id);
      if (bytes != null) {
        final image = await _decodeSafely(bytes);
        if (image != null) {
          _images[id] = image;
          loaded = true;
        }
      }
      _pending.remove(id);
    }

    if (loaded && !_disposed) notifyListeners();
  }

  /// Reads the asset's bytes, loading them into the cache first if needed.
  Future<Uint8List?> loadBytes(String assetId) async {
    final cached = _bytes[assetId];
    if (cached != null) return cached;

    return _loadBytes(assetId);
  }

  /// The source image's pixel size, used to keep an image element's aspect
  /// ratio when it is placed.
  Future<ui.Size?> naturalSize(String assetId) async {
    final loaded = _images[assetId];
    if (loaded != null) return _sizeOf(loaded);

    await preload(<String>[assetId]);
    final image = _images[assetId];

    return image == null ? null : _sizeOf(image);
  }

  Future<Uint8List?> _loadBytes(String assetId) async {
    final cached = _bytes[assetId];
    if (cached != null) return cached;

    final reference = await _store.refFor(assetId);
    if (reference == null) return null;
    if (!await _vault.exists(reference)) return null;

    final bytes = await _vault.read(reference);
    _bytes[assetId] = bytes;

    return bytes;
  }

  /// [_loadBytes] that treats a missing or unreadable asset as "no image":
  /// the element stays invisible, the preview keeps working, and the
  /// export path reports the gap on its own.
  Future<Uint8List?> _loadBytesSafely(String assetId) async {
    try {
      return await _loadBytes(assetId);
    } catch (_) {
      return null;
    }
  }

  /// [_decode] that returns null for bytes the codec cannot read.
  static Future<ui.Image?> _decodeSafely(Uint8List bytes) async {
    try {
      return await _decode(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();

      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  static ui.Size _sizeOf(ui.Image image) {
    return ui.Size(image.width.toDouble(), image.height.toDouble());
  }

  @override
  void dispose() {
    _disposed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _bytes.clear();
    super.dispose();
  }
}
