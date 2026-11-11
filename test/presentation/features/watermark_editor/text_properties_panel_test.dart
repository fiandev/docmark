import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_template/src/core/gen/l10n/app_localizations.dart';
import 'package:flutter_template/src/domain/entities/document.dart';
import 'package:flutter_template/src/domain/entities/image_format.dart';
import 'package:flutter_template/src/domain/entities/watermark_element.dart';
import 'package:flutter_template/src/presentation/core/theme/theme.dart';
import 'package:flutter_template/src/presentation/features/watermark_editor/controller/editor_controller.dart';
import 'package:flutter_template/src/presentation/features/watermark_editor/widgets/color_picker_sheet.dart';
import 'package:flutter_template/src/presentation/features/watermark_editor/widgets/text_properties_panel.dart';

import 'support/editor_fakes.dart';

void main() {
  late FakeDocumentRepository repository;
  late IdGenerator ids;
  late EditorController controller;

  setUp(() {
    repository = FakeDocumentRepository(document: testDocument());
    ids = IdGenerator();
  });

  EditorController build() {
    return EditorController(
      document: testDocument(),
      config: WatermarkConfig.empty,
      repository: repository,
      saveDebounce: const Duration(milliseconds: 5),
      newId: ids.call,
    );
  }

  Widget host(EditorController controller) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Theme(
          data: context.lightTheme,
          child: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, child) {
                final element = controller.selectedElement;
                if (element is! TextWatermark) {
                  return const SizedBox.shrink();
                }

                return SingleChildScrollView(
                  child: TextPropertiesPanel(
                    controller: controller,
                    element: element,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the outline switch adds a spec and turns it off again',
      (tester) async {
    controller = build();
    addTearDown(controller.dispose);
    controller.addText(content: 'Stamp');

    await tester.pumpWidget(host(controller));
    await tester.pump();

    expect(find.text('Outline width'), findsNothing);

    await tester.tap(find.text('Outline'));
    await tester.pump();

    var text = controller.selectedElement! as TextWatermark;
    expect(text.outline, isNotNull);
    expect(text.outline!.colorArgb, text.colorArgb);
    expect(find.text('Outline width'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.text('Outline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    text = controller.selectedElement! as TextWatermark;
    expect(text.outline, isNull);
  });

  testWidgets('the background switch adds a plate with token defaults',
      (tester) async {
    controller = build();
    addTearDown(controller.dispose);
    controller.addText(content: 'Stamp');

    await tester.pumpWidget(host(controller));
    await tester.pump();

    await tester.tap(find.text('Background'));
    await tester.pump();

    final text = controller.selectedElement! as TextWatermark;
    expect(text.background, isNotNull);
    expect(find.text('Background padding'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 20));
  });

  testWidgets('picking a family from the sheet updates the element',
      (tester) async {
    controller = build();
    addTearDown(controller.dispose);
    controller.addText(content: 'Stamp');

    await tester.pumpWidget(host(controller));
    await tester.pump();

    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    final caveat = find.text('Caveat');
    expect(caveat, findsOneWidget);

    await tester.ensureVisible(caveat);
    await tester.pumpAndSettle();
    await tester.tap(caveat);
    await tester.pumpAndSettle();

    final text = controller.selectedElement! as TextWatermark;
    expect(text.font, FontToken.caveat);

    await tester.pump(const Duration(milliseconds: 20));
  });

  group('parseHexColor', () {
    test('reads opaque RGB and ARGB values', () {
      expect(parseHexColor('#FF0000'), 0xFFFF0000);
      expect(parseHexColor('00FF00'), 0xFF00FF00);
      expect(parseHexColor('#80000000'), 0x80000000);
    });

    test('rejects malformed input', () {
      expect(parseHexColor('#12345'), isNull);
      expect(parseHexColor('nope'), isNull);
    });
  });
}
