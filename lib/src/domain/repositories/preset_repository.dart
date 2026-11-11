import '../../core/base/result.dart';
import '../../core/base/unit.dart';
import '../entities/preset.dart';
import '../entities/watermark_element.dart';
import '../failures/business_failure.dart';

/// Saved watermark configurations.
///
/// Creating a preset also copies any referenced image assets into the
/// vault (T5 owns the implementation), which is why [create] takes the
/// asset ids rather than trusting the caller's elements alone.
abstract interface class PresetRepository {
  Future<Result<List<PresetEntity>, BusinessFailure>> list();

  Future<Result<PresetEntity?, BusinessFailure>> get(String presetId);

  Future<Result<PresetEntity, BusinessFailure>> create({
    required String name,
    required List<WatermarkElement> elements,
    required List<String> imageAssetIds,
  });

  Future<Result<PresetEntity, BusinessFailure>> update(PresetEntity preset);

  /// Copies a preset, including its asset references, under a new id.
  Future<Result<PresetEntity, BusinessFailure>> duplicate(String presetId);

  Future<Result<Unit, BusinessFailure>> delete(String presetId);

  /// Returns the preset's configuration re-pointed at [documentId]'s page
  /// set, ready to hand to the editor.
  Future<Result<List<WatermarkElement>, BusinessFailure>> apply(
    String presetId,
    String documentId,
  );
}
