// lib/data/services/file_saver_io.dart
// Mobile/desktop: native "Save As" dialog via file_picker.

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> saveBytesFile(
    String fileName,
    Uint8List bytes, {
      String mimeType = 'application/octet-stream',
      List<String> extensions = const ['xlsx'],
    }) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'Save file',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: extensions,
    bytes: bytes,
  );
}
