import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'document_format_validator.dart';
import 'document_pick_service.dart';

/// The platform pickers.
///
/// Each pick reads the selected file into memory once; the original file
/// stays where the operating system keeps it and is never written back.
final class DeviceDocumentPickService implements DocumentPickService {
  const DeviceDocumentPickService();

  static const List<String> _documentExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
    'pdf',
  ];

  @override
  Future<PickedDocument?> pickFromGallery() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (picked == null) return null;

    return _read(picked.name, await picked.readAsBytes());
  }

  @override
  Future<PickedDocument?> pickFromFiles() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _documentExtensions,
    );
    if (picked == null) return null;

    return _read(picked.name, await picked.readAsBytes());
  }

  PickedDocument _read(String fileName, Uint8List bytes) {
    return PickedDocument(
      fileName: fileName,
      bytes: bytes,
      declaredFormat: DocumentFormatValidator.validate(bytes),
    );
  }
}
