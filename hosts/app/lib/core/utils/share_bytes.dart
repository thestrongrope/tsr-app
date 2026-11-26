import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _mimeTypes = {
  'pdf': 'application/pdf',
  'csv': 'text/csv',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

/// The kind of file a name stands for, by its ending.
String mimeTypeOf(String fileName) =>
    _mimeTypes[fileName.split('.').last.toLowerCase()] ??
    'application/octet-stream';

/// Hands a fetched file to the person. On a device: written to the temporary
/// folder and passed to the share sheet. A browser has no such folder, so
/// there the browser saves it as a download named [fileName].
Future<void> shareBytes(
  List<int> bytes,
  String fileName, {
  String? subject,
  bool isWeb = kIsWeb,
}) async {
  if (isWeb) {
    final file = XFile.fromData(
      Uint8List.fromList(bytes),
      name: fileName,
      mimeType: mimeTypeOf(fileName),
    );
    // A browser ignores the path and downloads the file under its name.
    await file.saveTo(fileName);
    return;
  }

  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], subject: subject),
  );
}
