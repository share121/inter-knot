// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void revokeResourceBlobUrl(String? url) {
  if (url == null || url.isEmpty) return;
  html.Url.revokeObjectUrl(url);
}

String createResourceBlobUrl(List<int> bytes, String mimeType) {
  final blob = html.Blob(<Uint8List>[Uint8List.fromList(bytes)], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}
