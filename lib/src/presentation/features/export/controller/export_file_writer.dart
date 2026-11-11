import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/storage/scratch_paths.dart';

/// Writes exported bytes to the places outside the encrypted vault: a
/// private temp file for the share sheet, and a user-visible file for
/// "Save".
///
/// Both operations always create a new file. The original document is
/// never referenced, so it cannot be overwritten even if the user exports
/// twice with the same name. A shared copy is plaintext-by-necessity: it is
/// deleted as soon as the share sheet returns, and the startup sweep covers
/// the directory in case the process died first.
abstract interface class ExportFileWriter {
  Future<String> writeTempFile({
    required Uint8List bytes,
    required String fileName,
  });

  /// Deletes a file created by [writeTempFile]. Best-effort: a missing file
  /// or a platform lock must not fail the share flow.
  Future<void> deleteTempFile(String path);

  Future<String> saveToDevice({
    required Uint8List bytes,
    required String fileName,
  });

  Future<void> shareFiles({
    required List<String> paths,
    required String subject,
  });
}

/// The device implementation: `path_provider` for locations and
/// `share_plus` for the platform share sheet.
final class DeviceExportFileWriter implements ExportFileWriter {
  const DeviceExportFileWriter();

  @override
  Future<String> writeTempFile({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final root = await getTemporaryDirectory();
    final directory = Directory('${root.path}/$shareDirectoryName');
    final file = await _uniqueFile(directory, fileName);
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }

  @override
  Future<void> deleteTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // The share sheet may still hold the handle. The startup sweep retries.
    }
  }

  @override
  Future<String> saveToDevice({
    required Uint8List bytes,
    required String fileName,
  }) async {
    Directory? downloads;
    try {
      downloads = await getDownloadsDirectory();
    } catch (_) {
      downloads = null;
    }
    final root = downloads ?? await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/DocMark');
    final file = await _uniqueFile(directory, fileName);
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }

  @override
  Future<void> shareFiles({
    required List<String> paths,
    required String subject,
  }) async {
    if (paths.isEmpty) return;

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[for (final path in paths) XFile(path)],
        subject: subject,
      ),
    );
  }

  static Future<File> _uniqueFile(
    Directory directory,
    String fileName,
  ) async {
    await directory.create(recursive: true);

    final dot = fileName.lastIndexOf('.');
    final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
    final extension = dot > 0 ? fileName.substring(dot) : '';

    var candidate = File('${directory.path}/$fileName');
    var suffix = 1;
    while (await candidate.exists()) {
      candidate = File('${directory.path}/${stem}_$suffix$extension');
      suffix += 1;
    }

    return candidate;
  }
}
