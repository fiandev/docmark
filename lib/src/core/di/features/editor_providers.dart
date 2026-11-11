/// OWNER: T3 (editor state).
///
/// Frozen DI contract for the editor session. T3 replaces the throwing
/// body with the notifier-backed session; `editorSessionProvider(id)` is
/// the key the editor page reads.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/entities/document.dart';

part 'editor_providers.g.dart';

/// Everything the editor needs to open one document.
///
/// T3 may extend this type, but must keep `documentId` and `config`.
final class EditorSession {
  const EditorSession({
    required this.documentId,
    required this.document,
    required this.config,
    required this.pageIndex,
  });

  final String documentId;
  final DocumentEntity document;
  final WatermarkConfig config;
  final int pageIndex;
}

@riverpod
Future<EditorSession> editorSession(Ref ref, String documentId) =>
    throw UnimplementedError('EditorSession is implemented by T3');
