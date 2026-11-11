import 'package:flutter/services.dart';
import 'package:docmark/src/domain/services/font_registry.dart';

/// Loads every bundled font family into the test binding.
///
/// Call once in `setUpAll` for tests that render real typography (golden
/// tests, text-layout assertions). Until T9 replaces the placeholder font
/// bytes, loading a family may fail — keep this helper out of tests that
/// do not need real glyphs.
Future<void> loadAppFonts() async {
  for (final spec in FontRegistry.catalog.values) {
    final family = spec.family;
    if (family == null) continue;

    final loader = FontLoader(family);
    for (final path in spec.styleFiles.values) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
}
