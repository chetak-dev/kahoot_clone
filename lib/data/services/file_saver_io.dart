// lib/data/services/file_saver_io.dart
// Mobile/desktop: native "Save As" dialog via file_picker.

import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> saveCsvFile(String fileName, Uint8List bytes) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'Save sample CSV',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: ['csv'],
    bytes: bytes,
  );
}
