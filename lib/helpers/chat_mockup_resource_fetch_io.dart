import 'dart:io';

import 'package:inter_knot/helpers/chat_mockup_resource_fetch_types.dart';

/// Loopback hosts bypass `HTTP_PROXY` / system proxy so local dev servers stay reachable.
String _findProxy(Uri uri) {
  final h = uri.host.toLowerCase();
  if (h == 'localhost' || h == '127.0.0.1' || h == '::1') {
    return 'DIRECT';
  }
  return HttpClient.findProxyFromEnvironment(uri);
}

/// Native IO: custom [HttpClient] — localhost直连，其余走环境代理。
Future<ChatMockupResourceHttpResponse> fetchChatMockupResource(
  String url,
  Duration timeout,
  int maxBodyBytes,
) async {
  final uri = Uri.parse(url);
  final client = HttpClient()
    ..connectionTimeout = timeout
    ..findProxy = _findProxy;

  try {
    final request = await client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final code = response.statusCode;
    if (code != 200 && code != 206) {
      await response.drain();
      throw FormatException('HTTP $code');
    }

    final ct = response.headers.value('content-type');
    var length = 0;
    final acc = <int>[];
    await for (final chunk in response) {
      length += chunk.length;
      if (length > maxBodyBytes) {
        throw const FormatException('resource too large');
      }
      acc.addAll(chunk);
    }

    return ChatMockupResourceHttpResponse(
      statusCode: code,
      bodyBytes: acc,
      contentType: ct,
    );
  } finally {
    client.close(force: true);
  }
}
