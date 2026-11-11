import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

const double _epsilon = 1e-6;

/// A rectangle in a document page's normalized coordinate space.
///
/// Every field is a fraction of the page from 0 to 1: `x`/`y` are the
/// top-left corner and `w`/`h` the size. Normalized coordinates are what
/// make a watermark position identical on a phone preview and on a
/// 300-dpi export, and what lets a PDF page be addressed with its own
/// coordinate system.
///
/// Converting to pixels happens only at the rendering boundary, through
/// [toRect].
final class NormalizedRect {
  const NormalizedRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  const NormalizedRect.fromLTWH(this.x, this.y, this.w, this.h);

  /// The full page: a watermark covering the whole document.
  const NormalizedRect.full() : x = 0, y = 0, w = 1, h = 1;

  /// Projects a pixel rectangle back into normalized space. [size] must be
  /// the page's pixel size, not the screen's.
  factory NormalizedRect.fromRect(Rect rect, Size size) {
    return NormalizedRect(
      x: rect.left / size.width,
      y: rect.top / size.height,
      w: rect.width / size.width,
      h: rect.height / size.height,
    );
  }

  final double x;
  final double y;
  final double w;
  final double h;

  double get right => x + w;
  double get bottom => y + h;
  bool get isEmpty => w <= _epsilon || h <= _epsilon;

  NormalizedOffset get center => NormalizedOffset(x + w / 2, y + h / 2);

  /// The four corners in clockwise order, starting top-left.
  List<NormalizedOffset> get corners => [
    NormalizedOffset(x, y),
    NormalizedOffset(right, y),
    NormalizedOffset(right, bottom),
    NormalizedOffset(x, bottom),
  ];

  bool contains(NormalizedOffset point) =>
      point.dx >= x &&
      point.dx <= right &&
      point.dy >= y &&
      point.dy <= bottom;

  /// Whether every edge sits inside the page.
  bool get isWithinPage =>
      x >= -_epsilon &&
      y >= -_epsilon &&
      right <= 1 + _epsilon &&
      bottom <= 1 + _epsilon;

  /// The same rectangle translated by [delta], edge-clamped to the page.
  NormalizedRect translated(NormalizedOffset delta) {
    return NormalizedRect.fromLTWH(x + delta.dx, y + delta.dy, w, h);
  }

  /// Clamps the rectangle inside the page without changing its size. A
  /// rectangle larger than the page is pinned to the top-left corner.
  NormalizedRect clampToPage() {
    final maxX = (1 - w).clamp(0.0, 1.0);
    final maxY = (1 - h).clamp(0.0, 1.0);
    final clampedX = x.clamp(0.0, maxX).toDouble();
    final clampedY = y.clamp(0.0, maxY).toDouble();

    return NormalizedRect.fromLTWH(clampedX, clampedY, w, h);
  }

  /// Whether two rectangles share the same geometry within [epsilon].
  bool nearlyEquals(NormalizedRect other, {double epsilon = _epsilon}) {
    return (x - other.x).abs() <= epsilon &&
        (y - other.y).abs() <= epsilon &&
        (w - other.w).abs() <= epsilon &&
        (h - other.h).abs() <= epsilon;
  }

  /// Pixel-space rectangle. [size] is the rendered page's pixel size.
  Rect toRect(Size size) {
    return Rect.fromLTWH(x * size.width, y * size.height, w * size.width,
        h * size.height);
  }

  NormalizedRect copyWith({double? x, double? y, double? w, double? h}) {
    return NormalizedRect(
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  static NormalizedRect fromJson(Map<String, dynamic> json) {
    return NormalizedRect(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NormalizedRect &&
        other.x == x &&
        other.y == y &&
        other.w == w &&
        other.h == h;
  }

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'NormalizedRect($x, $y, $w, $h)';
}

/// A point or delta in normalized page space.
final class NormalizedOffset {
  const NormalizedOffset(this.dx, this.dy);

  const NormalizedOffset.zero() : dx = 0, dy = 0;

  factory NormalizedOffset.fromOffset(Offset offset, Size size) {
    return NormalizedOffset(offset.dx / size.width, offset.dy / size.height);
  }

  final double dx;
  final double dy;

  bool get isZero => dx.abs() <= _epsilon && dy.abs() <= _epsilon;

  double get distance => math.sqrt(dx * dx + dy * dy);

  NormalizedOffset operator +(NormalizedOffset other) =>
      NormalizedOffset(dx + other.dx, dy + other.dy);

  NormalizedOffset operator -(NormalizedOffset other) =>
      NormalizedOffset(dx - other.dx, dy - other.dy);

  NormalizedOffset operator *(double factor) =>
      NormalizedOffset(dx * factor, dy * factor);

  Offset toOffset(Size size) => Offset(dx * size.width, dy * size.height);
  Map<String, dynamic> toJson() => {'dx': dx, 'dy': dy};

  static NormalizedOffset fromJson(Map<String, dynamic> json) {
    return NormalizedOffset(
      (json['dx'] as num).toDouble(),
      (json['dy'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NormalizedOffset && other.dx == dx && other.dy == dy;
  }

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'NormalizedOffset($dx, $dy)';
}

/// A crop window inside an image's natural bounds, in the same 0..1 space
/// as [NormalizedRect] but relative to the source image rather than a page.
///
/// A crop never leaves the source image: the editor clamps on every drag,
/// so `x + w <= 1` and `y + h <= 1` are invariants the presentation layer
/// can rely on.
final class CropRect {
  const CropRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  const CropRect.fromLTWH(this.x, this.y, this.w, this.h);

  /// The whole image — no crop applied.
  const CropRect.full() : x = 0, y = 0, w = 1, h = 1;

  factory CropRect.fromSrcRect(Rect rect, Size naturalSize) {
    return CropRect(
      x: rect.left / naturalSize.width,
      y: rect.top / naturalSize.height,
      w: rect.width / naturalSize.width,
      h: rect.height / naturalSize.height,
    );
  }

  final double x;
  final double y;
  final double w;
  final double h;

  double get right => x + w;
  double get bottom => y + h;

  bool get isFull =>
      x.abs() <= _epsilon &&
      y.abs() <= _epsilon &&
      (w - 1).abs() <= _epsilon &&
      (h - 1).abs() <= _epsilon;

  /// Whether the crop window sits inside the source image.
  bool get isValid =>
      w > _epsilon &&
      h > _epsilon &&
      x >= -_epsilon &&
      y >= -_epsilon &&
      right <= 1 + _epsilon &&
      bottom <= 1 + _epsilon;

  /// The pixel rectangle to hand to an image cropper.
  Rect toSrcRect(Size naturalSize) {
    return Rect.fromLTWH(
      x * naturalSize.width,
      y * naturalSize.height,
      w * naturalSize.width,
      h * naturalSize.height,
    );
  }

  /// Pins the window inside the source image, shrinking it if a malformed
  /// value arrived from storage.
  CropRect clamped() {
    final safeW = w.clamp(0.0, 1.0).toDouble();
    final safeH = h.clamp(0.0, 1.0).toDouble();

    return CropRect.fromLTWH(
      x.clamp(0.0, 1 - safeW).toDouble(),
      y.clamp(0.0, 1 - safeH).toDouble(),
      safeW,
      safeH,
    );
  }

  CropRect copyWith({double? x, double? y, double? w, double? h}) {
    return CropRect(
      x: x ?? this.x,
      y: y ?? this.y,
      w: w ?? this.w,
      h: h ?? this.h,
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  static CropRect fromJson(Map<String, dynamic> json) {
    return CropRect(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CropRect &&
        other.x == x &&
        other.y == y &&
        other.w == w &&
        other.h == h;
  }

  @override
  int get hashCode => Object.hash(x, y, w, h);

  @override
  String toString() => 'CropRect($x, $y, $w, $h)';
}
