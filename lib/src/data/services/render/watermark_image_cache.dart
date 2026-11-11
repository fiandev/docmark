import 'dart:typed_data';
import 'dart:ui' as ui;

/// Reads an encrypted watermark asset by id. Returns null when the asset
/// is gone, so a missing logo never aborts an export.
typedef WatermarkAssetBytesLoader = Future<Uint8List?> Function(
  String assetId,
);

/// Decoded watermark images, keyed by vault asset id.
///
/// Decoding is the expensive part of painting an image watermark, and a
/// PDF page rasterizes once per page while the same logo appears on every
/// one of them. The cache holds a bounded LRU set; evicting disposes the
/// GPU image it owned.
final class WatermarkImageCache {
  WatermarkImageCache({
    required WatermarkAssetBytesLoader loader,
    this.maxEntries = 24,
  }) : _loader = loader;

  final WatermarkAssetBytesLoader _loader;
  final int maxEntries;

  final Map<String, ui.Image> _images = <String, ui.Image>{};
  final Map<String, Future<ui.Image?>> _pending =
      <String, Future<ui.Image?>>{};
  final Set<String> _missing = <String>{};

  /// The image for [assetId], or null when the asset does not exist.
  Future<ui.Image?> resolve(String assetId) async {
    final cached = _images.remove(assetId);
    if (cached != null) {
      // Re-insert to mark it as the most recently used entry.
      _images[assetId] = cached;
      return cached;
    }
    if (_missing.contains(assetId)) return null;

    final pending = _pending[assetId];
    if (pending != null) return pending;

    final future = _load(assetId);
    _pending[assetId] = future;
    try {
      return await future;
    } finally {
      _pending.remove(assetId);
    }
  }

  /// Drops every cached image. Call when the owning session closes.
  void clear() {
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    _missing.clear();
    _pending.clear();
  }

  Future<ui.Image?> _load(String assetId) async {
    final bytes = await _loader(assetId);
    if (bytes == null || bytes.isEmpty) {
      _missing.add(assetId);
      return null;
    }

    final decoded = await _decode(bytes);
    if (decoded == null) {
      _missing.add(assetId);
      return null;
    }

    _images[assetId] = decoded;
    _evictOverflow();
    return decoded;
  }

  void _evictOverflow() {
    while (_images.length > maxEntries) {
      final oldest = _images.keys.first;
      _images.remove(oldest)?.dispose();
    }
  }

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
    }
  }
}
