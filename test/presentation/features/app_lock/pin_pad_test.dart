import 'package:flutter/material.dart';
import 'package:flutter_template/src/presentation/core/theme/theme.dart';
import 'package:flutter_template/src/presentation/features/app_lock/widgets/pin_dots.dart';
import 'package:flutter_template/src/presentation/features/app_lock/widgets/pin_pad.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: context.lightTheme,
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      ),
    );
  }

  group('PinPad', () {
    testWidgets('reports every digit and backspace', (tester) async {
      final digits = <String>[];
      var backspaces = 0;

      await pump(
        tester,
        PinPad(onDigit: digits.add, onBackspace: () => backspaces += 1),
      );

      for (final digit in ['1', '5', '9', '0']) {
        await tester.tap(find.text(digit));
      }
      await tester.tap(find.byIcon(Icons.backspace_outlined));

      expect(digits, ['1', '5', '9', '0']);
      expect(backspaces, 1);
    });

    testWidgets('a disabled pad ignores taps', (tester) async {
      final digits = <String>[];

      await pump(
        tester,
        PinPad(
          enabled: false,
          onDigit: digits.add,
          onBackspace: () {},
        ),
      );

      await tester.tap(find.text('5'), warnIfMissed: false);

      expect(digits, isEmpty);
    });
  });

  group('PinDots', () {
    testWidgets('renders one dot per digit', (tester) async {
      await pump(tester, const PinDots(length: 6, filled: 2));

      expect(
        find.descendant(
          of: find.byType(PinDots),
          matching: find.byType(Container),
        ),
        findsNWidgets(6),
      );
    });
  });
}
