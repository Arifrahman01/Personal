import 'dart:io';

/// True only when executing on a real Android dart:io runtime (never Windows tests or Web).
bool get isAndroidIoRuntime => Platform.isAndroid;

/// True when executing on any dart:io platform (mobile or desktop).
bool get isIoPlatformRuntime => true;

/// Safely deletes a file at [path] if it exists.
Future<void> deleteLocalFileIfExists(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return;
  try {
    final file = File(trimmed);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

/// Checks whether a local file exists and is non-empty.
Future<bool> localFileExistsAndNonEmpty(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return false;
  try {
    final file = File(trimmed);
    return await file.exists() && await file.length() > 0;
  } catch (_) {
    return false;
  }
}

/// Atomically writes [contents] to [filePath] via a temporary file.
Future<void> writeLocalTextFileAtomic(String filePath, String contents) async {
  final target = File(filePath);
  await target.parent.create(recursive: true);
  final tmp = File('$filePath.tmp');
  await tmp.writeAsString(contents, flush: true);
  if (await target.exists()) {
    await target.delete();
  }
  await tmp.rename(filePath);
}

/// Reads local text file at [filePath], returning null if missing.
Future<String?> readLocalTextFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) return null;
    return await file.readAsString();
  } catch (_) {
    return null;
  }
}
