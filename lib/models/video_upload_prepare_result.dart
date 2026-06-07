enum VideoUploadPublishMode {
  inline,
  gistRequired,
}

class VideoUploadPrepareResult {
  const VideoUploadPrepareResult({
    required this.mode,
    required this.wrappedPayload,
    required this.encodedChars,
    required this.jsonChars,
    required this.recommendedBodySnippet,
  });

  final VideoUploadPublishMode mode;
  final String wrappedPayload;
  final int encodedChars;
  final int jsonChars;
  final String recommendedBodySnippet;
}
