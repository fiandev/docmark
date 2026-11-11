import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_template/src/core/base/result.dart';
import 'package:flutter_template/src/core/security/encryption_service.dart';
import 'package:flutter_template/src/core/security/key_manager.dart';
import 'package:flutter_template/src/core/security/src/aes_gcm_encryption_service.dart';
import 'package:flutter_template/src/core/storage/db/app_database.dart';
import 'package:flutter_template/src/core/storage/db/dao/asset_dao.dart';
import 'package:flutter_template/src/core/storage/vault/secure_file_vault_impl.dart';
import 'package:flutter_template/src/core/storage/vault/watermark_asset_store.dart';
import 'package:flutter_template/src/data/repositories/document_repository_impl.dart';
import 'package:flutter_template/src/data/repositories/history_repository_impl.dart';
import 'package:flutter_template/src/data/repositories/preset_repository_impl.dart';
import 'package:flutter_template/src/domain/entities/image_format.dart';
import 'package:flutter_template/src/domain/failures/business_failure.dart';
import 'package:flutter_template/src/domain/services/media_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/base/fake_crash_reporter.dart';

/// One isolated storage stack: in-memory SQLCipher-shaped database plus a
/// real encrypted vault under a temp directory.
final class DocmarkHarness {
  DocmarkHarness._({
    required this.root,
    required this.database,
    required this.vault,
    required this.images,
    required this.normalizer,
    required this.crashReporter,
  });

  static Future<DocmarkHarness> create() async {
    final root = await Directory.systemTemp.createTemp('docmark_repo_test');
    final database = AppDatabase(NativeDatabase.memory());
    final vault = SecureFileVaultImpl(
      encryption: AesGcmEncryptionService(),
      keyManager: _StaticKeyManager(),
      rootDirectory: () async => root,
    );
    final images = WatermarkAssetStore(
      vault: vault,
      assets: AssetDao(database),
    );

    return DocmarkHarness._(
      root: root,
      database: database,
      vault: vault,
      images: images,
      normalizer: ProbeOnlyNormalizer(),
      crashReporter: FakeCrashReporter(),
    );
  }

  final Directory root;
  final AppDatabase database;
  final SecureFileVaultImpl vault;
  final WatermarkAssetStore images;
  final MediaNormalizerService normalizer;
  final FakeCrashReporter crashReporter;

  DocumentRepositoryImpl documents() {
    return DocumentRepositoryImpl(
      crashReporter: crashReporter,
      database: database,
      vault: vault,
      normalizer: normalizer,
      images: images,
    );
  }

  PresetRepositoryImpl presets() {
    return PresetRepositoryImpl(
      crashReporter: crashReporter,
      database: database,
      images: images,
    );
  }

  HistoryRepositoryImpl history() {
    return HistoryRepositoryImpl(
      crashReporter: crashReporter,
      database: database,
      images: images,
    );
  }

  /// Every file under the vault root, staging files included.
  Future<List<File>> files() async {
    if (!await root.exists()) return const [];
    final files = <File>[];
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) files.add(entity);
    }

    return files;
  }

  Future<void> dispose() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

final class _StaticKeyManager implements KeyManager {
  final AesKey _key = AesKey(
    Uint8List.fromList(List<int>.generate(32, (index) => index + 1)),
  );

  @override
  Future<AesKey> createOrGetKek() async => _key;
}

/// Detects real file signatures and reports fixed dimensions. The point
/// is the repository's page/asset bookkeeping, not image decoding.
final class ProbeOnlyNormalizer implements MediaNormalizerService {
  @override
  Future<MediaProbe> probe(Uint8List bytes) async {
    final format = detectFormat(bytes);

    return MediaProbe(
      format: format,
      width: format == ImageFormat.pdf ? 612 : 800,
      height: format == ImageFormat.pdf ? 792 : 600,
      hasAlpha: format == ImageFormat.png,
      pageCount: format == ImageFormat.pdf ? 3 : null,
    );
  }

  @override
  Future<NormalizedMedia> normalizeAsPng(Uint8List bytes) async {
    return NormalizedMedia(
      pngBytes: bytes,
      width: 1,
      height: 1,
      hasAlpha: true,
      sourceFormat: detectFormat(bytes),
    );
  }
}

ImageFormat detectFormat(Uint8List bytes) {
  bool startsWith(List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }

    return true;
  }

  if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return ImageFormat.png;
  if (startsWith(const [0x25, 0x50, 0x44, 0x46])) return ImageFormat.pdf;
  if (startsWith(const [0xFF, 0xD8])) return ImageFormat.jpeg;
  if (startsWith(const [0x52, 0x49, 0x46, 0x46])) return ImageFormat.webp;

  return ImageFormat.unknown;
}

Uint8List pngBytes([String marker = 'docmark-test-document']) {
  return Uint8List.fromList([
    0x89,
    0x50,
    0x4E,
    0x47,
    ...marker.codeUnits,
  ]);
}

Uint8List pdfBytes([String marker = 'docmark-test-pdf']) {
  return Uint8List.fromList([
    0x25,
    0x50,
    0x44,
    0x46,
    ...marker.codeUnits,
  ]);
}

/// Unwraps a successful result; a failure fails the test with its value.
T dataOf<T>(Result<T, BusinessFailure> result) {
  return switch (result) {
    Success(:final data) => data,
    Error(:final error) => fail('unexpected failure: $error'),
  };
}
