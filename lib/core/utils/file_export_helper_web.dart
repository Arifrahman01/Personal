import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Shares or downloads [bytes] directly from memory on web targets.
Future<void> shareBackupBytes(Uint8List bytes, String fileName) async {
  await shareExportedFile(
    bytes: bytes,
    fileName: fileName,
    mimeType: 'application/octet-stream',
    subject: 'Backup Personal Hub ($fileName)',
    text: 'Berkas backup terenkripsi Personal Hub (.phub).',
  );
}

/// Shares or downloads [bytes] directly from memory on web targets with customizable metadata.
Future<void> shareExportedFile({
  required Uint8List bytes,
  required String fileName,
  String? mimeType,
  String? subject,
  String? text,
}) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          bytes,
          name: fileName,
          mimeType: mimeType ?? 'application/octet-stream',
        ),
      ],
      subject: subject ?? fileName,
      text: text,
    ),
  );
}
