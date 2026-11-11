import 'dart:convert';

import '../../core/security/secure_file_vault.dart';
import '../../core/storage/db/app_database.dart';
import '../../domain/entities/document.dart';
import '../../domain/entities/history.dart';
import '../../domain/entities/preset.dart';
import '../../domain/entities/watermark_element.dart';

/// Row-to-entity mapping for the DocMark tables.
///
/// The drift row classes are generated with explicit names (`DocumentRow`,
/// `PresetRow`, ...), so they never collide with the domain entities and
/// no import prefix is needed here.

extension DocumentRowMapping on DocumentRow {
  DocumentEntity toEntity(List<DocumentPage> pages) {
    return DocumentEntity(
      id: id,
      name: name,
      kind: documentKindFromName(kind),
      pageCount: pageCount,
      pageSizes: pages,
      watermarkConfigJson: configJson,
      createdAt: createdAt,
    );
  }
}

extension DocumentEntityMapping on DocumentEntity {
  DocumentRow toRow() {
    return DocumentRow(
      id: id,
      name: name,
      kind: kind.name,
      pageCount: pageCount,
      configJson: watermarkConfigJson,
      createdAt: createdAt,
    );
  }
}

extension DocumentPageRowMapping on DocumentPageRow {
  DocumentPage toEntity() {
    return DocumentPage(
      index: pageIndex,
      widthPt: widthPt,
      heightPt: heightPt,
    );
  }
}

extension DocumentPageEntityMapping on DocumentPage {
  DocumentPageRow toRow(String docId) {
    return DocumentPageRow(
      docId: docId,
      pageIndex: index,
      widthPt: widthPt,
      heightPt: heightPt,
    );
  }
}

extension PresetRowMapping on PresetRow {
  PresetEntity toEntity(List<String> assetIds) {
    return PresetEntity(
      id: id,
      name: name,
      elements: decodeElements(elementsJson),
      imageAssetIds: List<String>.unmodifiable(assetIds),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension PresetEntityMapping on PresetEntity {
  PresetRow toRow() {
    return PresetRow(
      id: id,
      name: name,
      elementsJson: encodeElements(elements),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension HistoryEntryRowMapping on HistoryEntryRow {
  HistoryEntryEntity toEntity() {
    return HistoryEntryEntity(
      id: id,
      documentName: documentName,
      createdAt: createdAt,
      status: historyStatusFromName(status),
      documentId: documentId,
      originalRef: decodeAssetRef(originalRef),
      processedRef: decodeAssetRef(processedRef),
      watermarkConfigJson: configRef,
    );
  }
}

extension HistoryEntryEntityMapping on HistoryEntryEntity {
  HistoryEntryRow toRow() {
    return HistoryEntryRow(
      id: id,
      documentName: documentName,
      documentId: documentId,
      originalRef: encodeAssetRef(originalRef),
      processedRef: encodeAssetRef(processedRef),
      configRef: watermarkConfigJson,
      status: status.name,
      createdAt: createdAt,
    );
  }
}

/// Unknown stored values degrade to [DocumentKind.image] rather than
/// crashing a list that only wants to draw a thumbnail.
DocumentKind documentKindFromName(String? name) {
  return DocumentKind.values.firstWhere(
    (value) => value.name == name,
    orElse: () => DocumentKind.image,
  );
}

/// Unknown stored values degrade to [HistoryStatus.failed], matching the
/// entity's own JSON rule.
HistoryStatus historyStatusFromName(String? name) {
  return HistoryStatus.values.firstWhere(
    (value) => value.name == name,
    orElse: () => HistoryStatus.failed,
  );
}

/// Serializes a layer list as one compact JSON array.
String encodeElements(List<WatermarkElement> elements) {
  return jsonEncode(elements.map((element) => element.toJson()).toList());
}

/// Restores the layer list. Accepts either the bare array this layer
/// writes or a `WatermarkConfig`-shaped object, so a preset can also be
/// seeded from a saved configuration.
List<WatermarkElement> decodeElements(String source) {
  try {
    final decoded = jsonDecode(source);
    final raw = decoded is Map ? decoded['elements'] : decoded;
    if (raw is! List) {
      throw const FormatException('Stored elements are not a list');
    }

    return raw
        .map(
          (element) => WatermarkElement.fromJson(
            (element as Map).cast<String, dynamic>(),
          ),
        )
        .toList();
  } on FormatException {
    rethrow;
  } catch (error) {
    throw FormatException('Stored elements are malformed: $error');
  }
}

String? encodeAssetRef(AssetRef? ref) {
  return ref == null ? null : jsonEncode(ref.toJson());
}

AssetRef? decodeAssetRef(String? source) {
  if (source == null || source.isEmpty) return null;
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw const FormatException('Stored asset reference is malformed');
  }

  return AssetRef.fromJson(decoded.cast<String, dynamic>());
}
