import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:docmark/src/domain/entities/document.dart';
import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/entities/watermark_element.dart';
import 'package:docmark/src/domain/failures/business_failure.dart';
import 'package:docmark/src/presentation/features/watermark_editor/controller/editor_controller.dart';

import 'support/editor_fakes.dart';

void main() {
  late FakeDocumentRepository repository;
  late IdGenerator ids;

  EditorController build({
    DocumentEntity? document,
    WatermarkConfig config = WatermarkConfig.empty,
    Duration saveDebounce = const Duration(milliseconds: 20),
  }) {
    final controller = EditorController(
      document: document ?? testDocument(),
      config: config,
      repository: repository,
      saveDebounce: saveDebounce,
      newId: ids.call,
    );
    addTearDown(controller.dispose);

    return controller;
  }

  setUp(() {
    repository = FakeDocumentRepository(document: testDocument());
    ids = IdGenerator();
  });

  group('element lifecycle', () {
    test('addText appends, selects, and marks the draft dirty', () {
      final controller = build();

      final element = controller.addText(content: 'Draft');

      expect(element, isNotNull);
      expect(controller.config.elements, hasLength(1));
      expect(controller.selectedId, element!.id);
      expect(controller.selectedElement, isA<TextWatermark>());
      expect(controller.hasUnsavedDraft, isTrue);
      expect((controller.selectedElement! as TextWatermark).content, 'Draft');
    });

    test('addImage keeps the source aspect ratio on the page', () {
      final controller = build();

      final element = controller.addImage(
        'asset-1',
        naturalSize: const Size(400, 200),
      );

      expect(element, isNotNull);
      expect(element!.assetId, 'asset-1');
      // 600x800 page, 2:1 image: the height follows the page ratio.
      expect(element.rect.w, closeTo(0.3, 0.0001));
      expect(element.rect.h, closeTo(0.1125, 0.0001));
      expect(controller.imageAssetIds, <String>['asset-1']);
    });

    test('duplicate clones the subtype with a fresh id and an offset', () {
      final controller = build();
      final original = controller.addText(content: 'Stamp')!;

      controller.duplicate(original.id);

      expect(controller.config.elements, hasLength(2));
      final copy = controller.config.elements.last as TextWatermark;
      expect(copy.id, isNot(original.id));
      expect(copy.content, 'Stamp');
      expect(copy.rect.x, closeTo(original.rect.x + 0.02, 0.0001));
      expect(copy.rect.y, closeTo(original.rect.y + 0.02, 0.0001));
      expect(controller.selectedId, copy.id);
    });

    test('remove deletes the element and clears the selection', () {
      final controller = build();
      final element = controller.addText()!;

      controller.remove(element.id);

      expect(controller.config.elements, isEmpty);
      expect(controller.selectedId, isNull);
    });
  });

  group('lock and visibility', () {
    test('a locked element refuses only geometry changes', () {
      final controller = build();
      final element = controller.addText(content: 'Draft')!;
      final rect = element.rect;
      final rotation = element.rotationDeg;

      controller.setLocked(element.id, true);
      controller.select(element.id);
      controller.moveBy(element.id, const NormalizedOffset(0.1, 0.1));
      controller.setRotation(element.id, 90);
      controller.setOpacity(element.id, 0.2);
      controller.updateText(
        element.id,
        content: 'Approved',
        colorArgb: 0xFF00FF00,
        rotationDeg: 45,
      );

      final locked = controller.config.elements.single as TextWatermark;
      expect(locked.locked, isTrue);
      expect(locked.rect, rect);
      expect(locked.rotationDeg, rotation);
      // Content, colour and opacity are appearance, not geometry.
      expect(locked.content, 'Approved');
      expect(locked.colorArgb, 0xFF00FF00);
      expect(locked.opacity, 0.2);
      expect(controller.selectedId, element.id);

      controller.setLocked(element.id, false);
      controller.moveBy(element.id, const NormalizedOffset(0.1, 0.1));
      expect(controller.config.elements.single.rect, isNot(rect));
    });

    test('a locked image keeps crop and rotation but allows appearance', () {
      final controller = build();
      final element = controller.addImage('asset-1')!;

      controller.setLocked(element.id, true);
      controller.applyCrop(
        element.id,
        const CropRect.fromLTWH(0.1, 0.2, 0.5, 0.4),
      );
      controller.updateImage(
        element.id,
        rotationDeg: 30,
        opacity: 0.4,
        lockAspect: false,
      );

      final image = controller.config.elements.single as ImageWatermark;
      expect(image.crop, isNull);
      expect(image.rotationDeg, element.rotationDeg);
      expect(image.opacity, 0.4);
      expect(image.lockAspect, isFalse);
    });

    test('visibility only flips the flag', () {
      final controller = build();
      final element = controller.addText()!;

      controller.toggleVisibility(element.id);

      expect(controller.config.elements.single.visible, isFalse);
      expect(controller.config.elements.single.rect, element.rect);
    });
  });

  group('layer order', () {
    test('front, back, forward and backward reorder the paint list', () {
      final controller = build();
      final a = controller.addText(content: 'A')!;
      final b = controller.addText(content: 'B')!;
      final c = controller.addText(content: 'C')!;

      List<String> order() =>
          controller.config.elements.map((element) => element.id).toList();

      expect(order(), <String>[a.id, b.id, c.id]);

      controller.bringToFront(a.id);
      expect(order(), <String>[b.id, c.id, a.id]);

      controller.sendToBack(a.id);
      expect(order(), <String>[a.id, b.id, c.id]);

      controller.moveForward(a.id);
      expect(order(), <String>[b.id, a.id, c.id]);

      controller.moveBackward(c.id);
      expect(order(), <String>[b.id, c.id, a.id]);
    });
  });

  group('per-page assignment', () {
    test('setPage clamps to the document pages', () {
      final controller = build(document: testDocument(pageCount: 2));

      controller.setPage(5);
      expect(controller.pageIndex, 1);

      controller.setPage(-3);
      expect(controller.pageIndex, 0);
    });

    test('setElementPages scopes an element to the pages it names', () {
      final controller = build(document: testDocument(pageCount: 2));
      final a = controller.addText(content: 'A')!;
      controller.addText(content: 'B');

      expect(controller.config.elementsForPage(0), hasLength(2));
      expect(controller.config.elementsForPage(1), hasLength(2));

      controller.setElementPages(a.id, <int>{0});

      expect(
        controller.config.elementsForPage(0).map((element) => element.id),
        contains(a.id),
      );
      expect(
        controller.config.elementsForPage(1).map((element) => element.id),
        isNot(contains(a.id)),
      );
      expect(controller.paintsEveryPage(a.id), isFalse);

      controller.setElementPages(a.id, <int>{0, 1});
      expect(controller.paintsEveryPage(a.id), isTrue);
    });

    test('a new element joins every page once assignments are explicit', () {
      final controller = build(document: testDocument(pageCount: 2));
      final a = controller.addText(content: 'A')!;
      final b = controller.addText(content: 'B')!;
      controller.setElementPages(a.id, <int>{0});

      final c = controller.addText(content: 'C')!;

      expect(
        controller.config.elementsForPage(1).map((element) => element.id),
        <String>[b.id, c.id],
      );
    });

    test('a PDF subset enumerates and assigns only source pages', () {
      final controller = build(
        document: testDocument(
          pageCount: 3,
          pageIndexes: const <int>[1, 2],
        ),
      );

      // pageCount is the imported subset, not the source total.
      expect(controller.pageCount, 2);
      expect(controller.pageSourceIndices, <int>[1, 2]);
      expect(controller.pageIndex, 1);

      controller.setPage(2);
      expect(controller.pageIndex, 2);

      final a = controller.addText(content: 'A')!;
      controller.setElementPages(a.id, <int>{1});

      expect(controller.config.pageAssignments.keys.toSet(), <int>{1, 2});
      expect(
        controller.config.elementsForPage(1).map((element) => element.id),
        contains(a.id),
      );
      expect(
        controller.config.elementsForPage(2).map((element) => element.id),
        isNot(contains(a.id)),
      );

      controller.setElementPages(a.id, <int>{1, 2});
      expect(controller.paintsEveryPage(a.id), isTrue);
    });

    test('an out-of-subset page request lands on the nearest source page', () {
      final controller = build(
        document: testDocument(
          pageCount: 5,
          pageIndexes: const <int>[2, 4],
        ),
      );

      expect(controller.pageIndex, 2);

      controller.setPage(3);
      expect(controller.pageIndex, 4);

      controller.setPage(0);
      expect(controller.pageIndex, 2);
    });
  });

  group('appearance', () {
    test('text outline and background round-trip and clear', () {
      final controller = build();
      final element = controller.addText(content: 'A')!;

      controller.updateText(
        element.id,
        outline: const OutlineSpec(widthLogical: 3, colorArgb: 0xFF00FF00),
        background: const BackgroundSpec(colorArgb: 0xFFFF0000),
      );

      var text = controller.config.elements.single as TextWatermark;
      expect(text.outline?.widthLogical, 3);
      expect(text.outline?.colorArgb, 0xFF00FF00);
      expect(text.background?.colorArgb, 0xFFFF0000);

      controller.updateText(element.id, clearOutline: true);
      controller.updateText(element.id, clearBackground: true);

      text = controller.config.elements.single as TextWatermark;
      expect(text.outline, isNull);
      expect(text.background, isNull);
    });

    test('crop writes a clamped window and reset clears it', () {
      final controller = build();
      final element = controller.addImage('asset-1')!;

      expect(element.crop, isNull);

      controller.applyCrop(
        element.id,
        const CropRect.fromLTWH(0.1, 0.2, 0.5, 0.4),
      );

      var image = controller.config.elements.single as ImageWatermark;
      expect(image.crop, const CropRect.fromLTWH(0.1, 0.2, 0.5, 0.4));
      expect(image.assetId, 'asset-1');

      controller.resetCrop(element.id);
      image = controller.config.elements.single as ImageWatermark;
      expect(image.crop, isNull);
    });
  });

  group('draft persistence', () {
    test('a burst of edits is saved once after the debounce', () async {
      final controller = build();

      controller.addText(content: 'One');
      controller.addText(content: 'Two');
      controller.addText(content: 'Three');

      expect(repository.savedConfigs, isEmpty);
      expect(controller.hasUnsavedDraft, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(repository.savedConfigs, hasLength(1));
      expect(repository.savedDocumentIds.single, 'doc-1');
      expect(repository.savedConfigs.single.elements, hasLength(3));
      expect(controller.hasUnsavedDraft, isFalse);
    });

    test('flush writes immediately and is a no-op when clean', () async {
      final controller = build(saveDebounce: const Duration(minutes: 5));

      controller.addText(content: 'Draft');
      await controller.flush();

      expect(repository.savedConfigs, hasLength(1));

      await controller.flush();
      expect(repository.savedConfigs, hasLength(1));
    });

    test('a failed save keeps the draft dirty and surfaces the failure',
        () async {
      final controller = build();
      repository.nextSaveFailure = const BusinessFailure.unexpected();

      controller.addText(content: 'Draft');
      await controller.flush();

      expect(repository.savedConfigs, isEmpty);
      expect(controller.hasUnsavedDraft, isTrue);
      expect(controller.saveFailure, isA<BusinessFailure>());
    });
  });
}
