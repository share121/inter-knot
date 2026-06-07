import 'package:http/http.dart' as http;
import 'package:inter_knot/helpers/chat_mockup_resource_fetch_types.dart';

/// Web / VM-without-IO: uses `package:http` (browser stack proxy rules).
Future<ChatMockupResourceHttpResponse> fetchChatMockupResource(
  String url,
  Duration timeout,
  int maxBodyBytes,
) async {
  final resp = await http.get(Uri.parse(url)).timeout(timeout);
  if (resp.bodyBytes.length > maxBodyBytes) {
    throw const FormatException('resource too large');
  }
  return ChatMockupResourceHttpResponse(
    statusCode: resp.statusCode,
    bodyBytes: resp.bodyBytes,
    contentType: resp.headers['content-type'],
  );
}
