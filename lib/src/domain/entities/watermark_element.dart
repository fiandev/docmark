import 'image_format.dart';
import 'normalized_rect.dart';

/// One watermark drawn on a document page.
///
/// A document can carry any number of these, layered in list order. The
/// fields on this base class are geometry and visibility only — the same
/// for text and image watermarks. Subclasses add the appearance.
///
/// The class is `sealed`: the editor's exhaustive switches rely on there
/// being exactly [TextWatermark] and [ImageWatermark], and a new element
/// type should be a deliberate compile break.
sealed class WatermarkElement {
  const WatermarkElement({
    required this.id,
    required this.rect,
    this.rotationDeg = 0,
    this.opacity = 1,
    this.locked = false,
    this.visible = true,
  });

  /// Stable identity, also used as the key for per-page assignment.
  final String id;

  /// Position and size in page-normalized space.
  final NormalizedRect rect;

  /// Clockwise rotation around the element centre, in degrees.
  final double rotationDeg;

  /// 0 (invisible) to 1 (opaque).
  final double opacity;

  /// Whether gesture handlers must ignore the element.
  final bool locked;

  /// Whether the element is drawn and exported.
  final bool visible;

  /// The base fields changed, keeping the subtype's appearance intact.
  WatermarkElement copyWith({
    NormalizedRect? rect,
    double? rotationDeg,
    double? opacity,
    bool? locked,
    bool? visible,
  });

  Map<String, dynamic> toJson();

  /// Restores a persisted element, dispatching on the `type` tag written
  /// by [toJson]. Unknown fields are ignored; malformed required values
  /// throw, because a corrupt preset should surface rather than render
  /// something the user never set.
  static WatermarkElement fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final rect = NormalizedRect.fromJson(
      (json['rect'] as Map).cast<String, dynamic>(),
    );

    return switch (type) {
      'text' => TextWatermark(
        id: json['id'] as String,
        rect: rect,
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
        locked: json['locked'] as bool? ?? false,
        visible: json['visible'] as bool? ?? true,
        content: json['content'] as String? ?? '',
        font: _fontFromName(json['font'] as String?),
        sizeLogical: (json['sizeLogical'] as num?)?.toDouble() ?? 24,
        colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFF000000,
        bold: json['bold'] as bool? ?? false,
        italic: json['italic'] as bool? ?? false,
        align: _alignFromName(json['align'] as String?),
        outline: json['outline'] == null
            ? null
            : OutlineSpec.fromJson(
                (json['outline'] as Map).cast<String, dynamic>(),
              ),
        background: json['background'] == null
            ? null
            : BackgroundSpec.fromJson(
                (json['background'] as Map).cast<String, dynamic>(),
              ),
      ),
      'image' => ImageWatermark(
        id: json['id'] as String,
        rect: rect,
        rotationDeg: (json['rotationDeg'] as num?)?.toDouble() ?? 0,
        opacity: (json['opacity'] as num?)?.toDouble() ?? 1,
        locked: json['locked'] as bool? ?? false,
        visible: json['visible'] as bool? ?? true,
        assetId: json['assetId'] as String? ?? '',
        lockAspect: json['lockAspect'] as bool? ?? true,
        crop: json['crop'] == null
            ? null
            : CropRect.fromJson((json['crop'] as Map).cast<String, dynamic>()),
      ),
      _ => throw const FormatException('Unknown watermark element type'),
    };
  }

  /// Serializes the shared fields and merges a subtype's appearance.
  Map<String, dynamic> baseJson(String type) => {
    'type': type,
    'id': id,
    'rect': rect.toJson(),
    'rotationDeg': rotationDeg,
    'opacity': opacity,
    'locked': locked,
    'visible': visible,
  };

  bool sameBase(WatermarkElement other) =>
      id == other.id &&
      rect == other.rect &&
      rotationDeg == other.rotationDeg &&
      opacity == other.opacity &&
      locked == other.locked &&
      visible == other.visible;

  static FontToken _fontFromName(String? name) {
    return FontToken.values.firstWhere(
      (value) => value.name == name,
      orElse: () => FontToken.system,
    );
  }

  static TextAlignType _alignFromName(String? name) {
    return TextAlignType.values.firstWhere(
      (value) => value.name == name,
      orElse: () => TextAlignType.center,
    );
  }
}

/// A text watermark. [sizeLogical] is the font size in logical pixels at a
/// page rendered to the preview's scale; the renderer scales it to the
/// export resolution.
final class TextWatermark extends WatermarkElement {
  const TextWatermark({
    required super.id,
    required super.rect,
    super.rotationDeg,
    super.opacity,
    super.locked,
    super.visible,
    required this.content,
    this.font = FontToken.system,
    this.sizeLogical = 24,
    this.colorArgb = 0xFF000000,
    this.bold = false,
    this.italic = false,
    this.align = TextAlignType.center,
    this.outline,
    this.background,
  });

  final String content;
  final FontToken font;
  final double sizeLogical;
  final int colorArgb;
  final bool bold;
  final bool italic;
  final TextAlignType align;
  final OutlineSpec? outline;
  final BackgroundSpec? background;

  @override
  TextWatermark copyWith({
    NormalizedRect? rect,
    double? rotationDeg,
    double? opacity,
    bool? locked,
    bool? visible,
    String? content,
    FontToken? font,
    double? sizeLogical,
    int? colorArgb,
    bool? bold,
    bool? italic,
    TextAlignType? align,
    OutlineSpec? outline,
    BackgroundSpec? background,
    bool clearOutline = false,
    bool clearBackground = false,
  }) {
    return TextWatermark(
      id: id,
      rect: rect ?? this.rect,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      opacity: opacity ?? this.opacity,
      locked: locked ?? this.locked,
      visible: visible ?? this.visible,
      content: content ?? this.content,
      font: font ?? this.font,
      sizeLogical: sizeLogical ?? this.sizeLogical,
      colorArgb: colorArgb ?? this.colorArgb,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      align: align ?? this.align,
      outline: clearOutline ? null : outline ?? this.outline,
      background: clearBackground ? null : background ?? this.background,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('text'),
    'content': content,
    'font': font.name,
    'sizeLogical': sizeLogical,
    'colorArgb': colorArgb,
    'bold': bold,
    'italic': italic,
    'align': align.name,
    if (outline != null) 'outline': outline!.toJson(),
    if (background != null) 'background': background!.toJson(),
  };

  @override
  bool operator ==(Object other) {
    return other is TextWatermark &&
        sameBase(other) &&
        other.content == content &&
        other.font == font &&
        other.sizeLogical == sizeLogical &&
        other.colorArgb == colorArgb &&
        other.bold == bold &&
        other.italic == italic &&
        other.align == align &&
        other.outline == outline &&
        other.background == background;
  }

  @override
  int get hashCode => Object.hash(
    id,
    rect,
    rotationDeg,
    opacity,
    locked,
    visible,
    content,
    font,
    sizeLogical,
    colorArgb,
    bold,
    italic,
    align,
    outline,
    background,
  );
}

/// A text outline (stroke) behind the glyphs.
final class OutlineSpec {
  const OutlineSpec({required this.widthLogical, required this.colorArgb});

  final double widthLogical;
  final int colorArgb;

  OutlineSpec copyWith({double? widthLogical, int? colorArgb}) {
    return OutlineSpec(
      widthLogical: widthLogical ?? this.widthLogical,
      colorArgb: colorArgb ?? this.colorArgb,
    );
  }

  Map<String, dynamic> toJson() => {
    'widthLogical': widthLogical,
    'colorArgb': colorArgb,
  };

  static OutlineSpec fromJson(Map<String, dynamic> json) {
    return OutlineSpec(
      widthLogical: (json['widthLogical'] as num?)?.toDouble() ?? 1,
      colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFF000000,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OutlineSpec &&
        other.widthLogical == widthLogical &&
        other.colorArgb == colorArgb;
  }

  @override
  int get hashCode => Object.hash(widthLogical, colorArgb);
}

/// A filled plate drawn behind the text.
final class BackgroundSpec {
  const BackgroundSpec({
    required this.colorArgb,
    this.paddingLogical = 4,
    this.radiusLogical = 4,
  });

  final int colorArgb;
  final double paddingLogical;
  final double radiusLogical;

  BackgroundSpec copyWith({
    int? colorArgb,
    double? paddingLogical,
    double? radiusLogical,
  }) {
    return BackgroundSpec(
      colorArgb: colorArgb ?? this.colorArgb,
      paddingLogical: paddingLogical ?? this.paddingLogical,
      radiusLogical: radiusLogical ?? this.radiusLogical,
    );
  }

  Map<String, dynamic> toJson() => {
    'colorArgb': colorArgb,
    'paddingLogical': paddingLogical,
    'radiusLogical': radiusLogical,
  };

  static BackgroundSpec fromJson(Map<String, dynamic> json) {
    return BackgroundSpec(
      colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFFFFFFFF,
      paddingLogical: (json['paddingLogical'] as num?)?.toDouble() ?? 4,
      radiusLogical: (json['radiusLogical'] as num?)?.toDouble() ?? 4,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BackgroundSpec &&
        other.colorArgb == colorArgb &&
        other.paddingLogical == paddingLogical &&
        other.radiusLogical == radiusLogical;
  }

  @override
  int get hashCode => Object.hash(colorArgb, paddingLogical, radiusLogical);
}

/// An image or logo watermark. [assetId] points at an encrypted asset in
/// the secure vault; the bytes never live on an external path.
final class ImageWatermark extends WatermarkElement {
  const ImageWatermark({
    required super.id,
    required super.rect,
    super.rotationDeg,
    super.opacity,
    super.locked,
    super.visible,
    required this.assetId,
    this.lockAspect = true,
    this.crop,
  });

  final String assetId;

  /// Whether resizing keeps the source image's aspect ratio.
  final bool lockAspect;

  /// The visible window inside the source image, when the user cropped it.
  final CropRect? crop;

  @override
  ImageWatermark copyWith({
    NormalizedRect? rect,
    double? rotationDeg,
    double? opacity,
    bool? locked,
    bool? visible,
    String? assetId,
    bool? lockAspect,
    CropRect? crop,
    bool clearCrop = false,
  }) {
    return ImageWatermark(
      id: id,
      rect: rect ?? this.rect,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      opacity: opacity ?? this.opacity,
      locked: locked ?? this.locked,
      visible: visible ?? this.visible,
      assetId: assetId ?? this.assetId,
      lockAspect: lockAspect ?? this.lockAspect,
      crop: clearCrop ? null : crop ?? this.crop,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    ...baseJson('image'),
    'assetId': assetId,
    'lockAspect': lockAspect,
    if (crop != null) 'crop': crop!.toJson(),
  };

  @override
  bool operator ==(Object other) {
    return other is ImageWatermark &&
        sameBase(other) &&
        other.assetId == assetId &&
        other.lockAspect == lockAspect &&
        other.crop == crop;
  }

  @override
  int get hashCode =>
      Object.hash(id, rect, rotationDeg, opacity, locked, visible, assetId,
          lockAspect, crop);
}
