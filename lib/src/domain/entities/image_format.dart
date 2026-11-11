/// The document and watermark-image formats DocMark understands.
///
/// Detection is by magic bytes (`FormatProbe`), never by extension: a file
/// picked from the gallery can arrive without a name, and a `.jpg` is not
/// proof of JPEG bytes.
enum ImageFormat {
  jpeg('image/jpeg'),
  png('image/png'),
  webp('image/webp'),
  pdf('application/pdf'),
  unknown('application/octet-stream');

  const ImageFormat(this.mimeType);

  /// The MIME type used when saving, sharing, or handing the bytes to a
  /// renderer.
  final String mimeType;

  /// Whether the format is part of the MVP import set.
  bool get isSupported =>
      this == ImageFormat.jpeg ||
      this == ImageFormat.png ||
      this == ImageFormat.pdf;

  /// The file extension an exported file should carry.
  String get fileExtension => switch (this) {
    .jpeg => 'jpg',
    .png => 'png',
    .webp => 'webp',
    .pdf => 'pdf',
    .unknown => 'bin',
  };
}

/// Every font family the watermark editor can render.
///
/// The enum is the persisted value; `FontRegistry` maps it to the Flutter
/// family name and bundled asset paths. `system` means "use the platform
/// default" and resolves to a null family.
enum FontToken {
  system,
  inter,
  roboto,
  robotoMono,
  montserrat,
  lora,
  merriweather,
  caveat,
}

/// How a text watermark aligns within its own bounding box.
enum TextAlignType { start, center, end, justify }
