import 'package:flutter_template/src/core/security/secure_file_vault.dart';
import 'package:flutter_template/src/data/mappers/docmark_mappers.dart';
import 'package:flutter_template/src/domain/entities/image_format.dart';
import 'package:flutter_template/src/domain/entities/normalized_rect.dart';
import 'package:flutter_template/src/domain/entities/watermark_element.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../data/repositories/docmark/harness.dart';

void main() {
  late DocmarkHarness harness;

  setUp(() async {
    harness = await DocmarkHarness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  group('preset CRUD', () {
    test('create, list, rename and delete use the encrypted store', () async {
      final repository = harness.presets();
      final source = await _seedImage(harness, 'brand-logo');

      final created = dataOf(
        await repository.create(
          name: '  Brand cover  ',
          elements: [_textElement()],
          imageAssetIds: const [],
        ),
      );

      expect(created.name, 'Brand cover');
      expect(created.imageAssetIds, isEmpty);

      final renamed = dataOf(
        await repository.update(created.copyWith(name: 'Invoice mark')),
      );
      expect(renamed.name, 'Invoice mark');
      expect(renamed.id, created.id);
      expect(renamed.createdAt, created.createdAt);

      final listed = dataOf(await repository.list());
      expect(listed.map((preset) => preset.name), ['Invoice mark']);

      dataOf(await repository.delete(created.id));

      expect(dataOf(await repository.list()), isEmpty);
      expect(
        dataOf(await repository.get(created.id)),
        isNull,
      );
      // The preset never referenced its own copy, so the source is intact.
      expect(await harness.images.refFor(source.id), isNotNull);
    });

    test('duplicate assigns new ids and copies the assets', () async {
      final repository = harness.presets();
      final source = await _seedImage(harness, 'brand-logo');
      final original = dataOf(
        await repository.create(
          name: 'Brand',
          elements: [_imageElement(source.id)],
          imageAssetIds: [source.id],
        ),
      );

      final duplicated = dataOf(await repository.duplicate(original.id));

      expect(duplicated.id, isNot(original.id));
      expect(duplicated.name, original.name);
      expect(
        duplicated.imageAssetIds.single,
        isNot(original.imageAssetIds.single),
      );
      expect(
        (duplicated.elements.single as ImageWatermark).assetId,
        duplicated.imageAssetIds.single,
      );
      expect(
        await harness.images.refFor(duplicated.imageAssetIds.single),
        isNotNull,
      );

      // Deleting the source preset cannot strand the duplicate.
      dataOf(await repository.delete(original.id));

      expect(
        await harness.images.refFor(duplicated.imageAssetIds.single),
        isNotNull,
      );
      expect(
        await harness.images.refFor(original.imageAssetIds.single),
        isNull,
      );
    });

    test('delete removes only the assets nobody else references', () async {
      final repository = harness.presets();
      final source = await _seedImage(harness, 'brand-logo');
      final original = dataOf(
        await repository.create(
          name: 'Brand',
          elements: [_imageElement(source.id)],
          imageAssetIds: [source.id],
        ),
      );
      final duplicated = dataOf(await repository.duplicate(original.id));

      final originalAsset = original.imageAssetIds.single;
      final duplicatedAsset = duplicated.imageAssetIds.single;

      dataOf(await repository.delete(original.id));

      expect(await harness.images.refFor(originalAsset), isNull);
      expect(await harness.images.refFor(duplicatedAsset), isNotNull);
      expect(await harness.images.refFor(source.id), isNotNull);

      dataOf(await repository.delete(duplicated.id));

      expect(await harness.images.refFor(duplicatedAsset), isNull);
      expect(await harness.images.refFor(source.id), isNotNull);
    });
  });

  group('preset round-trip', () {
    test('crop, outline, background and font survive the mapper', () async {
      final repository = harness.presets();
      final source = await _seedImage(harness, 'brand-logo');
      final text = _textElement(
        font: FontToken.lora,
        outline: const OutlineSpec(widthLogical: 2.5, colorArgb: 0xFF00AA44),
        background: const BackgroundSpec(
          colorArgb: 0x80FFFFFF,
          paddingLogical: 6,
          radiusLogical: 3,
        ),
      );
      final image = ImageWatermark(
        id: 'image-1',
        rect: const NormalizedRect.fromLTWH(0.1, 0.6, 0.3, 0.3),
        rotationDeg: -18,
        opacity: 0.65,
        lockAspect: false,
        assetId: source.id,
        crop: const CropRect.fromLTWH(0.1, 0.2, 0.6, 0.5),
      );

      final created = dataOf(
        await repository.create(
          name: 'Expressive',
          elements: [text, image],
          imageAssetIds: [source.id],
        ),
      );
      final fetched = dataOf(await repository.get(created.id))!;

      final fetchedText = fetched.elements.whereType<TextWatermark>().single;
      expect(fetchedText.font, FontToken.lora);
      expect(fetchedText.outline, text.outline);
      expect(fetchedText.background, text.background);
      expect(fetchedText.sizeLogical, text.sizeLogical);
      expect(fetchedText.colorArgb, text.colorArgb);
      expect(fetchedText.align, text.align);

      final fetchedImage = fetched.elements.whereType<ImageWatermark>().single;
      expect(fetchedImage.crop, image.crop);
      expect(fetchedImage.lockAspect, isFalse);
      expect(fetchedImage.rotationDeg, image.rotationDeg);
      expect(fetchedImage.opacity, image.opacity);

      // The T1 mapper is the storage boundary: what it decodes is exactly
      // what the repository hands back.
      expect(
        decodeElements(encodeElements(fetched.elements)),
        fetched.elements,
      );
    });

    test(
      'outline and background stay absent when never set',
      () async {
        final repository = harness.presets();
        final created = dataOf(
          await repository.create(
            name: 'Plain',
            elements: [_textElement()],
            imageAssetIds: const [],
          ),
        );

        final fetched = dataOf(await repository.get(created.id))!;
        final fetchedText = fetched.elements.whereType<TextWatermark>().single;

        expect(fetchedText.outline, isNull);
        expect(fetchedText.background, isNull);
      },
    );
  });
}

Future<AssetRef> _seedImage(DocmarkHarness harness, String marker) {
  return harness.images.putImage(
    bytes: pngBytes(marker),
    extension: 'png',
    mime: 'image/png',
  );
}

TextWatermark _textElement({
  FontToken font = FontToken.system,
  OutlineSpec? outline,
  BackgroundSpec? background,
}) {
  return TextWatermark(
    id: 'text-1',
    rect: const NormalizedRect.fromLTWH(0.2, 0.3, 0.5, 0.1),
    content: 'Confidential',
    font: font,
    sizeLogical: 36,
    colorArgb: 0xFF112233,
    bold: true,
    italic: true,
    rotationDeg: 12.5,
    opacity: 0.8,
    align: TextAlignType.end,
    outline: outline,
    background: background,
  );
}

ImageWatermark _imageElement(String assetId) {
  return ImageWatermark(
    id: 'image-1',
    rect: const NormalizedRect.fromLTWH(0.1, 0.1, 0.2, 0.2),
    assetId: assetId,
  );
}
