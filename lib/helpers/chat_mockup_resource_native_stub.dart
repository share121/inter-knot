Future<String> ensureChatMockupNativeCacheDir() {
  return Future.error(
    UnsupportedError('Native cache dir is not available on this platform.'),
  );
}

Future<String> writeChatMockupCacheFile(
  String dir,
  String fileName,
  List<int> bytes,
) {
  return Future.error(
    UnsupportedError('Native cache file is not available on this platform.'),
  );
}

Future<String?> pathIfChatMockupCacheFileReady(String dir, String fileName) {
  return Future<String?>.value();
}
