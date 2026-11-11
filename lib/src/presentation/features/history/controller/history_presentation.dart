import '../../../../core/gen/l10n/app_localizations.dart';
import '../../../../domain/entities/history.dart';

/// What "reuse configuration" should do for one entry.
enum HistoryReuseTarget {
  /// The original document still exists; the editor loads its saved config.
  editor,

  /// The original is gone; offer to apply the config to a new import.
  import,
}

/// The route decision made before touching storage.
final class HistoryReusePlan {
  const HistoryReusePlan._(this.target, this.documentId);

  const HistoryReusePlan.editor(String documentId)
    : this._(HistoryReuseTarget.editor, documentId);

  const HistoryReusePlan.import() : this._(HistoryReuseTarget.import, null);

  final HistoryReuseTarget target;

  /// The original document id, present only for [HistoryReuseTarget.editor].
  final String? documentId;
}

/// Reuse without the original document can only start a fresh import.
HistoryReusePlan historyReusePlan(HistoryEntryEntity entry) {
  final documentId = entry.documentId;
  if (documentId == null || documentId.isEmpty) {
    return const HistoryReusePlan.import();
  }

  return HistoryReusePlan.editor(documentId);
}

/// Localized label for the status chip.
String historyStatusLabel(
  HistoryStatus status,
  AppLocalizations locale,
) {
  return switch (status) {
    HistoryStatus.pending => locale.history_statusPending,
    HistoryStatus.processing => locale.history_statusProcessing,
    HistoryStatus.completed => locale.history_statusCompleted,
    HistoryStatus.failed => locale.history_statusFailed,
  };
}
