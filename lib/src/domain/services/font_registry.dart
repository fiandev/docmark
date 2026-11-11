import '../entities/image_format.dart';

/// The four faces bundled for each family.
enum FontFaceVariant { regular, bold, italic, boldItalic }

/// One family's Flutter family name and bundled files.
///
/// [family] is null for [FontToken.system]: the platform default has no
/// family name and no asset. [assetDir] and [styleFiles] are the single
/// place asset paths exist, so the pubspec declaration and the editor
/// cannot drift.
final class FontAssetSpec {
  const FontAssetSpec({
    required this.token,
    required this.family,
    required this.assetDir,
    required this.styleFiles,
    this.fallback,
  });

  final FontToken token;
  final String? family;
  final String? assetDir;
  final Map<FontFaceVariant, String> styleFiles;
  final String? fallback;

  /// The asset path for the requested face, or null for the system font.
  String? assetFor({bool bold = false, bool italic = false}) {
    if (assetDir == null) return null;
    if (bold && italic && styleFiles.containsKey(FontFaceVariant.boldItalic)) {
      return styleFiles[FontFaceVariant.boldItalic];
    }
    if (bold && styleFiles.containsKey(FontFaceVariant.bold)) {
      return styleFiles[FontFaceVariant.bold];
    }
    if (italic && styleFiles.containsKey(FontFaceVariant.italic)) {
      return styleFiles[FontFaceVariant.italic];
    }

    return styleFiles[FontFaceVariant.regular];
  }
}

/// Maps a persisted [FontToken] to the Flutter family name and asset paths.
///
/// This is the only source of truth for font resolution: widgets pass the
/// token, the renderer asks this registry, and neither hardcodes a family.
abstract final class FontRegistry {
  static const Map<FontToken, FontAssetSpec> catalog = {
    FontToken.system: FontAssetSpec(
      token: FontToken.system,
      family: null,
      assetDir: null,
      styleFiles: {},
    ),
    FontToken.inter: FontAssetSpec(
      token: FontToken.inter,
      family: 'Inter',
      assetDir: 'assets/fonts/inter',
      styleFiles: {
        FontFaceVariant.regular: 'assets/fonts/inter/Inter-Regular.ttf',
        FontFaceVariant.bold: 'assets/fonts/inter/Inter-Bold.ttf',
        FontFaceVariant.italic: 'assets/fonts/inter/Inter-Italic.ttf',
        FontFaceVariant.boldItalic: 'assets/fonts/inter/Inter-BoldItalic.ttf',
      },
      fallback: 'Roboto',
    ),
    FontToken.roboto: FontAssetSpec(
      token: FontToken.roboto,
      family: 'Roboto',
      assetDir: 'assets/fonts/roboto',
      styleFiles: {
        FontFaceVariant.regular: 'assets/fonts/roboto/Roboto-Regular.ttf',
        FontFaceVariant.bold: 'assets/fonts/roboto/Roboto-Bold.ttf',
        FontFaceVariant.italic: 'assets/fonts/roboto/Roboto-Italic.ttf',
        FontFaceVariant.boldItalic:
            'assets/fonts/roboto/Roboto-BoldItalic.ttf',
      },
      fallback: 'Roboto',
    ),
    FontToken.robotoMono: FontAssetSpec(
      token: FontToken.robotoMono,
      family: 'Roboto Mono',
      assetDir: 'assets/fonts/roboto_mono',
      styleFiles: {
        FontFaceVariant.regular:
            'assets/fonts/roboto_mono/RobotoMono-Regular.ttf',
        FontFaceVariant.bold: 'assets/fonts/roboto_mono/RobotoMono-Bold.ttf',
        FontFaceVariant.italic:
            'assets/fonts/roboto_mono/RobotoMono-Italic.ttf',
        FontFaceVariant.boldItalic:
            'assets/fonts/roboto_mono/RobotoMono-BoldItalic.ttf',
      },
      fallback: 'Roboto Mono',
    ),
    FontToken.montserrat: FontAssetSpec(
      token: FontToken.montserrat,
      family: 'Montserrat',
      assetDir: 'assets/fonts/montserrat',
      styleFiles: {
        FontFaceVariant.regular:
            'assets/fonts/montserrat/Montserrat-Regular.ttf',
        FontFaceVariant.bold:
            'assets/fonts/montserrat/Montserrat-Bold.ttf',
        FontFaceVariant.italic:
            'assets/fonts/montserrat/Montserrat-Italic.ttf',
        FontFaceVariant.boldItalic:
            'assets/fonts/montserrat/Montserrat-BoldItalic.ttf',
      },
      fallback: 'Roboto',
    ),
    FontToken.lora: FontAssetSpec(
      token: FontToken.lora,
      family: 'Lora',
      assetDir: 'assets/fonts/lora',
      styleFiles: {
        FontFaceVariant.regular: 'assets/fonts/lora/Lora-Regular.ttf',
        FontFaceVariant.bold: 'assets/fonts/lora/Lora-Bold.ttf',
        FontFaceVariant.italic: 'assets/fonts/lora/Lora-Italic.ttf',
        FontFaceVariant.boldItalic: 'assets/fonts/lora/Lora-BoldItalic.ttf',
      },
      fallback: 'Roboto',
    ),
    FontToken.merriweather: FontAssetSpec(
      token: FontToken.merriweather,
      family: 'Merriweather',
      assetDir: 'assets/fonts/merriweather',
      styleFiles: {
        FontFaceVariant.regular:
            'assets/fonts/merriweather/Merriweather-Regular.ttf',
        FontFaceVariant.bold:
            'assets/fonts/merriweather/Merriweather-Bold.ttf',
        FontFaceVariant.italic:
            'assets/fonts/merriweather/Merriweather-Italic.ttf',
      },
      fallback: 'Roboto',
    ),
    FontToken.caveat: FontAssetSpec(
      token: FontToken.caveat,
      family: 'Caveat',
      assetDir: 'assets/fonts/caveat',
      styleFiles: {
        FontFaceVariant.regular: 'assets/fonts/caveat/Caveat-Regular.ttf',
      },
      fallback: 'Roboto',
    ),
  };

  /// The Flutter family name for [token]; null means "platform default".
  static String? familyOf(FontToken token) => catalog[token]?.family;

  /// The asset path for one face of [token]; null for the system font.
  static String? assetFor(
    FontToken token, {
    bool bold = false,
    bool italic = false,
  }) {
    return catalog[token]?.assetFor(bold: bold, italic: italic);
  }

  /// The token a stored family name belongs to, for migrating presets that
  /// persisted a family instead of a token.
  static FontToken? tokenForFamily(String? family) {
    if (family == null) return null;
    for (final spec in catalog.values) {
      if (spec.family == family) return spec.token;
    }

    return null;
  }

  /// Whether the family ships with the app (the system font does not).
  static bool isBundled(FontToken token) => catalog[token]?.family != null;

  /// The families rendered in the font picker, in display order.
  static const List<FontToken> pickerOrder = [
    FontToken.system,
    FontToken.inter,
    FontToken.roboto,
    FontToken.robotoMono,
    FontToken.montserrat,
    FontToken.lora,
    FontToken.merriweather,
    FontToken.caveat,
  ];
}
