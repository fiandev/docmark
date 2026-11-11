import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:docmark/src/core/di/features/history_providers.dart';
import 'package:docmark/src/core/di/features/security_providers.dart';
import 'package:docmark/src/core/gen/l10n/app_localizations.dart';
import 'package:docmark/src/core/security/secure_file_vault.dart';
import 'package:docmark/src/domain/entities/history.dart';
import 'package:docmark/src/presentation/core/theme/theme.dart';
import 'package:docmark/src/presentation/features/history/widgets/history_preview_dialog.dart';

import '../../../support/fake_secure_file_vault.dart';
import 'support/fake_history_repository.dart';

void main() {
  testWidgets('a PDF preview shows a document tile, not an image', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46, 0x2D]);

    await tester.pumpWidget(_app(bytes));
    await tester.pumpAndSettle();

    expect(looksLikePdf(bytes), isTrue);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('undecodable image bytes fall back to the unavailable copy', (
    tester,
  ) async {
    await tester.pumpWidget(_app(Uint8List.fromList(const [0x01, 0x02])));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('The preview could not be loaded.'), findsOneWidget);
  });
}

Widget _app(Uint8List bytes) {
  final reference = AssetRef(id: 'asset-1', relativePath: 'asset-1.bin');
  final entry = HistoryEntryEntity(
    id: 'h1',
    documentName: 'alpha.pdf',
    createdAt: DateTime.utc(2026, 6, 1),
    status: HistoryStatus.completed,
    processedRef: reference,
  );
  final vault = FakeSecureFileVault()..assets[reference.id] = bytes;

  return ProviderScope(
    overrides: [
      historyRepositoryProvider.overrideWith(
        (ref) => FakeHistoryRepository(entries: [entry]),
      ),
      secureFileVaultProvider.overrideWith((ref) => vault),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Theme(
          data: context.lightTheme,
          child: Scaffold(
            body: HistoryPreviewDialog(entry: entry),
          ),
        ),
      ),
    ),
  );
}
