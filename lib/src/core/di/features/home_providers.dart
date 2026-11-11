/// OWNER: T6 (home surface).
///
/// Frozen DI contract for the home dashboard. Home is a read-only summary
/// of documents, presets, and history; T6 wires these to the stores.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/entities/document.dart';
import '../../../domain/entities/preset.dart';

part 'home_providers.g.dart';

/// The most recently edited documents, newest first.
@riverpod
Future<List<DocumentEntity>> recentDocumentList(Ref ref) async => const [];

/// The presets shown on the home screen, most recently updated first.
@riverpod
Future<List<PresetEntity>> homePresetList(Ref ref) async => const [];
