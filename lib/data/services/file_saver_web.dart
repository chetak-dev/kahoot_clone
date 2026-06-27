// lib/data/services/file_saver_web.dart
// Web: trigger a browser download via a Blob + temporary anchor.

import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveCsvFile(String fileName, Uint8List bytes) async {
  final blob = html.Blob(<Object>[bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
