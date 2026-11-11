/// OWNER: T6 (processing history).
///
/// Frozen DI contract for the history store and the home screen's recent
/// list. T6 replaces the throwing repository body; `recentDocuments`
/// keeps its shape so the home page can be built against it now.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/entities/history.dart';
import '../../../domain/repositories/history_repository.dart';

part 'history_providers.g.dart';

@Riverpod(keepAlive: true)
HistoryRepository historyRepository(Ref ref) =>
    throw UnimplementedError('HistoryRepository is implemented by T6');

/// The home screen's "recent" strip: newest entries first.
@riverpod
Future<List<HistoryEntryEntity>> recentDocuments(Ref ref) async => const [];
