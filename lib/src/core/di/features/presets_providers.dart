/// OWNER: T5 (watermark presets).
///
/// Frozen DI contract for the preset store and the preset save dialog's
/// data source. T5 replaces the throwing body with the Drift + vault
/// implementation.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/repositories/preset_repository.dart';

part 'presets_providers.g.dart';

@Riverpod(keepAlive: true)
PresetRepository presetRepository(Ref ref) =>
    throw UnimplementedError('PresetRepository is implemented by T5');
