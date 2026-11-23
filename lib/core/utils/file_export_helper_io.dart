import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes [bytes] to a temporary file and opens the platform share sheet.
Future<void> shareBackupBytes(Uint8List bytes, String fileName) async {
  await shareExportedFile(
    bytes: bytes,
    fileName: fileName,
    mimeType: 'application/octet-stream',
    subject: 'Backup Personal Hub ($fileName)',
    text: 'Berkas backup terenkripsi Personal Hub (.phub).',
  );
}

/// Writes [bytes] to a temporary file and opens the platform share sheet with customizable metadata.
Future<void> shareExportedFile({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
  String? subject,
  String? text,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File(p.join(tempDir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path, mimeType: mimeType)],
      subject: subject ?? fileName,
      text: text,
    ),
  );
}
