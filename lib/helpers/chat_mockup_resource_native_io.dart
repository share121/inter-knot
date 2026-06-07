import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String> ensureChatMockupNativeCacheDir() async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory(p.join(base.path, 'chat_mockup_media_cache'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return dir.path;
}

Future<String> writeChatMockupCacheFile(
  String dir,
  String fileName,
  List<int> bytes,
) async {
  final file = File(p.join(dir, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

Future<String?> pathIfChatMockupCacheFileReady(String dir, String fileName) async {
  final file = File(p.join(dir, fileName));
  if (await file.exists() && await file.length() > 0) {
    return file.path;
  }
  return null;
}
