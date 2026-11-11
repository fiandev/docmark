/// OWNER: T7 (render + export).
///
/// Frozen DI contract for rasterizing and exporting. T7 replaces the
/// throwing body with the `pdf`/`image`/`pdfrx` implementation.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/services/render_contract.dart';

part 'render_providers.g.dart';

/// Renders previews and export bytes. Never writes plaintext to disk.
@Riverpod(keepAlive: true)
WatermarkRenderer watermarkRenderer(Ref ref) =>
    throw UnimplementedError('WatermarkRenderer is implemented by T7');
