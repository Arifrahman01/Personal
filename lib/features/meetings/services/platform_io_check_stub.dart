bool get isAndroidIoRuntime => false;
bool get isIoPlatformRuntime => false;

Future<void> deleteLocalFileIfExists(String path) async {}
Future<bool> localFileExistsAndNonEmpty(String path) async => false;
Future<void> writeLocalTextFileAtomic(String filePath, String contents) async {}
Future<String?> readLocalTextFile(String filePath) async => null;
