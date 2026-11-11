import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docmark/src/core/di/features/editor_providers.dart';
import 'package:docmark/src/core/di/features/history_providers.dart';
import 'package:docmark/src/core/di/features/import_providers.dart';
import 'package:docmark/src/core/di/features/render_providers.dart';
import 'package:docmark/src/core/di/features/security_providers.dart';
import 'package:docmark/src/core/di/features/storage_providers.dart';
import 'package:docmark/src/core/gen/l10n/app_localizations.dart';
import 'package:docmark/src/domain/entities/document.dart';
import 'package:docmark/src/domain/entities/image_format.dart';
import 'package:docmark/src/domain/entities/normalized_rect.dart';
import 'package:docmark/src/domain/entities/watermark_element.dart';
import 'package:docmark/src/domain/repositories/document_repository.dart';
import 'package:docmark/src/domain/services/render_contract.dart';
import 'package:docmark/src/presentation/core/theme/theme.dart';
import 'package:docmark/src/presentation/features/watermark_editor/view/editor_page.dart';

import '../../../data/repositories/docmark/harness.dart';
import '../../../support/fake_watermark_renderer.dart';

void main() {
  testWidgets('the editor loads a document and adds a text watermark',
      (tester) async {
    final harness = await DocmarkHarness.create();
    addTearDown(harness.dispose);

    final imported = await harness.documents().importDocument(
      ImportRequest(
        source: ImportSource.gallery,
        fileName: 'scan.png',
        bytes: pngBytes(),
        declaredFormat: ImageFormat.png,
      ),
    );
    final document = dataOf(imported);

    final preview = await _solidPng();
    final renderer = _FixedThumbnailRenderer(preview);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWith((ref) => harness.documents()),
          watermarkAssetStoreProvider.overrideWith((ref) => harness.images),
          secureFileVaultProvider.overrideWith((ref) => harness.vault),
          watermarkRendererProvider.overrideWith((ref) => renderer),
          editorImagePickerProvider.overrideWith(
            (ref) => _CancellingPicker(),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Theme(
              data: context.lightTheme,
              child: EditorPage(documentId: document.id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('scan.png'), findsOneWidget);
    expect(find.text('Add text'), findsOneWidget);
    expect(find.text('Add image'), findsOneWidget);
    expect(renderer.thumbnailCalls, isNotEmpty);

    await tester.tap(find.text('Add text'));
    await tester.pump();

    expect(find.text('Opacity'), findsOneWidget);
    expect(find.text('Position'), findsOneWidget);

    await tester.tap(find.byTooltip('Lock'));
    await tester.pump();
    expect(
      find.text(
        'Position and size are locked. Unlock to move, resize, rotate or '
        'crop this element.',
      ),
      findsOneWidget,
    );

    // Let the debounced draft save fire before the test tears the tree down.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the editor applies and clears History\'s config hand-off',
      (tester) async {
    final harness = await DocmarkHarness.create();
    addTearDown(harness.dispose);

    final imported = await harness.documents().importDocument(
      ImportRequest(
        source: ImportSource.gallery,
        fileName: 'scan.png',
        bytes: pngBytes(),
        declaredFormat: ImageFormat.png,
      ),
    );
    final document = dataOf(imported);
    final preview = await _solidPng();
    final renderer = _FixedThumbnailRenderer(preview);

    final container = ProviderContainer(
      overrides: [
        documentRepositoryProvider.overrideWith((ref) => harness.documents()),
        watermarkAssetStoreProvider.overrideWith((ref) => harness.images),
        secureFileVaultProvider.overrideWith((ref) => harness.vault),
        watermarkRendererProvider.overrideWith((ref) => renderer),
        editorImagePickerProvider.overrideWith((ref) => _CancellingPicker()),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(pendingWatermarkConfigProvider.notifier)
        .set(
          const WatermarkConfig(
            elements: <WatermarkElement>[
              TextWatermark(
                id: 'history-text',
                rect: NormalizedRect.fromLTWH(0.1, 0.1, 0.4, 0.2),
                content: 'From history',
              ),
            ],
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Theme(
              data: context.lightTheme,
              child: EditorPage(documentId: document.id),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final session = await container.read(
      editorSessionProvider(document.id).future,
    );
    expect(
      (session.config.elements.single as TextWatermark).content,
      'From history',
    );
    expect(container.read(pendingWatermarkConfigProvider), isNull);

    await tester.pump(const Duration(seconds: 1));
  });
}

final class _CancellingPicker implements EditorImagePicker {
  @override
  Future<Uint8List?> pickImage() async => null;
}

final class _FixedThumbnailRenderer extends FakeWatermarkRenderer {
  _FixedThumbnailRenderer(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> thumbnail(
    RenderRequest request, {
    int maxWidth = 320,
  }) async {
    thumbnailCalls.add(request);

    return bytes;
  }
}

Future<Uint8List> _solidPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  if (data == null) throw StateError('Could not encode the test PNG.');

  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}
