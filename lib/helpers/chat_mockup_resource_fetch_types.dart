/// Response from [fetchChatMockupResource] (HTTP body already capped by caller rules).
class ChatMockupResourceHttpResponse {
  const ChatMockupResourceHttpResponse({
    required this.statusCode,
    required this.bodyBytes,
    this.contentType,
  });

  final int statusCode;
  final List<int> bodyBytes;

  /// Raw `Content-Type` header (may include parameters).
  final String? contentType;
}
