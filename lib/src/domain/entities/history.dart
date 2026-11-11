import '../../core/security/secure_file_vault.dart';

/// Where a history entry is in the processing pipeline.
///
/// The value is persisted, so it is serialized by name and unknown stored
/// values degrade to [failed] rather than crashing the list.
enum HistoryStatus { pending, processing, completed, failed }

/// One processed document: what was imported, what was produced, and how
/// far the pipeline got.
///
/// The two refs point into the encrypted vault. Deleting a history entry
/// deletes both assets (cascade), which is what makes "permanently delete
/// user data" a single operation.
final class HistoryEntryEntity {
  const HistoryEntryEntity({
    required this.id,
    required this.documentName,
    required this.createdAt,
    required this.status,
    this.documentId,
    this.originalRef,
    this.processedRef,
    this.watermarkConfigJson,
  });

  final String id;
  final String documentName;
  final DateTime createdAt;
  final HistoryStatus status;

  /// The document this entry was produced from, when it still exists.
  final String? documentId;

  final AssetRef? originalRef;
  final AssetRef? processedRef;

  /// The configuration snapshot used for this run, so the user can reuse
  /// it without opening the document.
  final String? watermarkConfigJson;

  HistoryEntryEntity copyWith({
    String? documentName,
    DateTime? createdAt,
    HistoryStatus? status,
    String? documentId,
    AssetRef? originalRef,
    AssetRef? processedRef,
    String? watermarkConfigJson,
  }) {
    return HistoryEntryEntity(
      id: id,
      documentName: documentName ?? this.documentName,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      documentId: documentId ?? this.documentId,
      originalRef: originalRef ?? this.originalRef,
      processedRef: processedRef ?? this.processedRef,
      watermarkConfigJson:
          watermarkConfigJson ?? this.watermarkConfigJson,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'documentName': documentName,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'documentId': documentId,
    'originalRef': originalRef?.toJson(),
    'processedRef': processedRef?.toJson(),
    'watermarkConfigJson': watermarkConfigJson,
  };

  static HistoryEntryEntity fromJson(Map<String, dynamic> json) {
    return HistoryEntryEntity(
      id: json['id'] as String,
      documentName: json['documentName'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: _statusFromName(json['status'] as String?),
      documentId: json['documentId'] as String?,
      originalRef: json['originalRef'] == null
          ? null
          : AssetRef.fromJson(
              (json['originalRef'] as Map).cast<String, dynamic>(),
            ),
      processedRef: json['processedRef'] == null
          ? null
          : AssetRef.fromJson(
              (json['processedRef'] as Map).cast<String, dynamic>(),
            ),
      watermarkConfigJson: json['watermarkConfigJson'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HistoryEntryEntity &&
        other.id == id &&
        other.documentName == documentName &&
        other.createdAt == createdAt &&
        other.status == status &&
        other.documentId == documentId &&
        other.originalRef == originalRef &&
        other.processedRef == processedRef &&
        other.watermarkConfigJson == watermarkConfigJson;
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentName,
    createdAt,
    status,
    documentId,
    originalRef,
    processedRef,
    watermarkConfigJson,
  );

  static HistoryStatus _statusFromName(String? name) {
    return HistoryStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => HistoryStatus.failed,
    );
  }
}
