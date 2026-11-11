import 'dart:convert';
import 'dart:ui' show Size;

import 'watermark_element.dart';

/// What a document is made of. The MVP imports images and PDFs; the enum
/// is a closed set so renderer switches stay exhaustive.
enum DocumentKind { image, pdf }

/// One page's identity and physical size in PDF points.
///
/// An image document has exactly one page whose point size is its pixel
/// size at 72 dpi. A PDF page carries its own MediaBox size, which is why
/// pages are modelled individually: a mixed-size PDF has no single page
/// size to normalize against.
final class DocumentPage {
  const DocumentPage({
    required this.index,
    required this.widthPt,
    required this.heightPt,
  });

  final int index;
  final double widthPt;
  final double heightPt;

  Size get sizePt => Size(widthPt, heightPt);

  Map<String, dynamic> toJson() => {
    'index': index,
    'widthPt': widthPt,
    'heightPt': heightPt,
  };

  static DocumentPage fromJson(Map<String, dynamic> json) {
    return DocumentPage(
      index: (json['index'] as num).toInt(),
      widthPt: (json['widthPt'] as num).toDouble(),
      heightPt: (json['heightPt'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DocumentPage &&
        other.index == index &&
        other.widthPt == widthPt &&
        other.heightPt == heightPt;
  }

  @override
  int get hashCode => Object.hash(index, widthPt, heightPt);
}

/// An imported document. The bytes live encrypted in the vault; this is
/// the metadata row that survives an app restart.
final class DocumentEntity {
  const DocumentEntity({
    required this.id,
    required this.name,
    required this.kind,
    required this.pageCount,
    required this.pageSizes,
    required this.createdAt,
    this.watermarkConfigJson,
  });

  final String id;
  final String name;
  final DocumentKind kind;
  final int pageCount;

  /// Per-page dimensions. A PDF may have pages of different sizes.
  final List<DocumentPage> pageSizes;

  /// The saved watermark configuration, serialized by `WatermarkConfig`.
  /// Null until the user first edits the document.
  final String? watermarkConfigJson;

  final DateTime createdAt;

  /// Looks up a page by index, returning null for an out-of-range index
  /// instead of throwing at a call site that is merely rendering.
  DocumentPage? pageAt(int index) {
    for (final page in pageSizes) {
      if (page.index == index) return page;
    }

    return null;
  }

  DocumentEntity copyWith({
    String? name,
    DocumentKind? kind,
    int? pageCount,
    List<DocumentPage>? pageSizes,
    String? watermarkConfigJson,
    DateTime? createdAt,
  }) {
    return DocumentEntity(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      pageCount: pageCount ?? this.pageCount,
      pageSizes: pageSizes ?? this.pageSizes,
      watermarkConfigJson: watermarkConfigJson ?? this.watermarkConfigJson,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'pageCount': pageCount,
    'pageSizes': pageSizes.map((page) => page.toJson()).toList(),
    'watermarkConfigJson': watermarkConfigJson,
    'createdAt': createdAt.toIso8601String(),
  };

  static DocumentEntity fromJson(Map<String, dynamic> json) {
    final pages = (json['pageSizes'] as List<dynamic>? ?? const [])
        .map(
          (page) => DocumentPage.fromJson(
            (page as Map).cast<String, dynamic>(),
          ),
        )
        .toList();

    return DocumentEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      kind: _documentKindFromName(json['kind'] as String?),
      pageCount: (json['pageCount'] as num?)?.toInt() ?? pages.length,
      pageSizes: pages,
      watermarkConfigJson: json['watermarkConfigJson'] as String?,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! DocumentEntity) return false;
    if (other.id != id ||
        other.name != name ||
        other.kind != kind ||
        other.pageCount != pageCount ||
        other.watermarkConfigJson != watermarkConfigJson ||
        other.createdAt != createdAt ||
        other.pageSizes.length != pageSizes.length) {
      return false;
    }
    for (var i = 0; i < pageSizes.length; i++) {
      if (other.pageSizes[i] != pageSizes[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kind,
    pageCount,
    Object.hashAll(pageSizes),
    watermarkConfigJson,
    createdAt,
  );

  static DocumentKind _documentKindFromName(String? name) {
    return DocumentKind.values.firstWhere(
      (value) => value.name == name,
      orElse: () => DocumentKind.image,
    );
  }
}

/// The watermarks on a document, plus which elements belong to which page.
///
/// [elements] is the editor's layer list, in paint order. [pageAssignments]
/// maps a page index to the ids drawn on that page; a page with no entry
/// receives the whole layer list, which is the common "apply everywhere"
/// case and keeps a single-page document free of bookkeeping.
final class WatermarkConfig {
  const WatermarkConfig({
    this.elements = const [],
    this.pageAssignments = const {},
  });

  final List<WatermarkElement> elements;
  final Map<int, List<String>> pageAssignments;

  static const WatermarkConfig empty = WatermarkConfig();

  bool get isEmpty => elements.isEmpty;

  /// The elements to draw on [pageIndex], in paint order.
  List<WatermarkElement> elementsForPage(int pageIndex) {
    final ids = pageAssignments[pageIndex];
    if (ids == null) return List.unmodifiable(elements);

    return List.unmodifiable(
      elements.where((element) => ids.contains(element.id)),
    );
  }

  WatermarkConfig copyWith({
    List<WatermarkElement>? elements,
    Map<int, List<String>>? pageAssignments,
  }) {
    return WatermarkConfig(
      elements: elements ?? this.elements,
      pageAssignments: pageAssignments ?? this.pageAssignments,
    );
  }

  Map<String, dynamic> toJson() => {
    'elements': elements.map((element) => element.toJson()).toList(),
    'pageAssignments': pageAssignments.map(
      (page, ids) => MapEntry(page.toString(), ids),
    ),
  };

  /// Persists through `dart:convert` so the stored form is one JSON string
  /// — the shape `DocumentEntity.watermarkConfigJson` carries.
  String toJsonString() => jsonEncode(toJson());

  static WatermarkConfig fromJson(Map<String, dynamic> json) {
    final elements = (json['elements'] as List<dynamic>? ?? const [])
        .map(
          (element) => WatermarkElement.fromJson(
            (element as Map).cast<String, dynamic>(),
          ),
        )
        .toList();

    final assignments = <int, List<String>>{};
    final rawAssignments = json['pageAssignments'];
    if (rawAssignments is Map) {
      rawAssignments.forEach((key, value) {
        final page = int.tryParse(key.toString());
        if (page != null && value is List) {
          assignments[page] = value.map((id) => id.toString()).toList();
        }
      });
    }

    return WatermarkConfig(
      elements: elements,
      pageAssignments: assignments,
    );
  }

  static WatermarkConfig fromJsonString(String source) {
    return fromJson((jsonDecode(source) as Map).cast<String, dynamic>());
  }

  @override
  bool operator ==(Object other) {
    if (other is! WatermarkConfig) return false;
    if (other.elements.length != elements.length) return false;
    for (var i = 0; i < elements.length; i++) {
      if (other.elements[i] != elements[i]) return false;
    }
    if (other.pageAssignments.length != pageAssignments.length) return false;
    for (final entry in pageAssignments.entries) {
      final otherIds = other.pageAssignments[entry.key];
      if (otherIds == null || otherIds.length != entry.value.length) {
        return false;
      }
      for (var i = 0; i < entry.value.length; i++) {
        if (otherIds[i] != entry.value[i]) return false;
      }
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(elements),
    Object.hashAll(
      pageAssignments.entries.map(
        (entry) => Object.hash(entry.key, Object.hashAll(entry.value)),
      ),
    ),
  );
}
