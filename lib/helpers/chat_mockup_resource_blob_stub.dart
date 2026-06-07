void revokeResourceBlobUrl(String? url) {}

String createResourceBlobUrl(List<int> bytes, String mimeType) {
  throw UnsupportedError('Blob URLs are only used on web.');
}
