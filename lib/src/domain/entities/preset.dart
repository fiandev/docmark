import 'watermark_element.dart';

/// A saved watermark configuration, reusable on any document.
///
/// A preset owns its element geometry and appearance, and the ids of the
/// encrypted image assets its image elements reference. Those ids are the
/// preset's own — applying a preset to a document re-points the assets
/// rather than trusting a stale path.
final class PresetEntity {
  const PresetEntity({
    required this.id,
    required this.name,
    required this.elements,
    required this.imageAssetIds,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<WatermarkElement> elements;

  /// Secure-vault asset ids referenced by [elements].
  final List<String> imageAssetIds;

  final DateTime createdAt;
  final DateTime updatedAt;

  PresetEntity copyWith({
    String? name,
    List<WatermarkElement>? elements,
    List<String>? imageAssetIds,
    DateTime? updatedAt,
  }) {
    return PresetEntity(
      id: id,
      name: name ?? this.name,
      elements: elements ?? this.elements,
      imageAssetIds: imageAssetIds ?? this.imageAssetIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'elements': elements.map((element) => element.toJson()).toList(),
    'imageAssetIds': imageAssetIds,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static PresetEntity fromJson(Map<String, dynamic> json) {
    return PresetEntity(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      elements: (json['elements'] as List<dynamic>? ?? const [])
          .map(
            (element) => WatermarkElement.fromJson(
              (element as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
      imageAssetIds: (json['imageAssetIds'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList(),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! PresetEntity) return false;
    if (other.id != id ||
        other.name != name ||
        other.createdAt != createdAt ||
        other.updatedAt != updatedAt ||
        other.elements.length != elements.length ||
        other.imageAssetIds.length != imageAssetIds.length) {
      return false;
    }
    for (var i = 0; i < elements.length; i++) {
      if (other.elements[i] != elements[i]) return false;
    }
    for (var i = 0; i < imageAssetIds.length; i++) {
      if (other.imageAssetIds[i] != imageAssetIds[i]) return false;
    }

    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    Object.hashAll(elements),
    Object.hashAll(imageAssetIds),
    createdAt,
    updatedAt,
  );
}
