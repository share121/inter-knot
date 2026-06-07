import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Whether a failed [request] should be treated as the **top-level embed document**
/// failing (user-visible fatal), as opposed to a sub-frame or sub-resource.
///
/// Uses [WebResourceRequest.isForMainFrame] when it is `false` to exclude
/// sub-resources immediately. When the platform reports `true`, we still require
/// [request.url] to match [expectedEmbedUrl] after normalization: on Android API
/// levels below 21, `isForMainFrame` is documented as always `true`, so ads and
/// 404 static assets would otherwise look like a main-document failure.
///
/// When [WebResourceRequest.isForMainFrame] is `null`, only the URL match applies.
bool iframeWebViewRequestIsMainDocumentFailure(
  WebResourceRequest request,
  String expectedEmbedUrl,
) {
  if (request.isForMainFrame == false) {
    return false;
  }
  return _iframeWebViewUrlsMatchMainNavigation(
    request.url.toString(),
    expectedEmbedUrl,
  );
}

/// [onReceivedHttpError] always includes [WebResourceRequest]; there is no separate
/// "frame" flag beyond [WebResourceRequest.isForMainFrame]. Same rules as
/// [iframeWebViewRequestIsMainDocumentFailure]: only count HTTP errors as fatal for
/// the main document when the failing request is the main frame **and** the URL
/// matches the embed (or `isForMainFrame` is unknown and URLs match).
bool iframeWebViewHttpErrorIsMainDocumentFailure(
  WebResourceRequest request,
  String expectedEmbedUrl,
) {
  return iframeWebViewRequestIsMainDocumentFailure(request, expectedEmbedUrl);
}

bool _iframeWebViewUrlsMatchMainNavigation(String requestUrl, String expected) {
  final a = Uri.tryParse(requestUrl.trim());
  final b = Uri.tryParse(expected.trim());
  if (a == null || b == null) {
    return requestUrl.trim() == expected.trim();
  }
  return a.scheme == b.scheme &&
      a.host.toLowerCase() == b.host.toLowerCase() &&
      a.path == b.path &&
      a.query == b.query;
}

/// Debug line for [WebResourceError]: [WebResourceErrorType] exposes a platform
/// code via [WebResourceErrorType.toNativeValue] when mapped.
void debugPrintIframeWebResourceErrorDetails({
  required String label,
  required WebUri? requestUrl,
  required bool? isForMainFrame,
  required WebResourceError error,
  required bool fatal,
}) {
  final type = error.type;
  final native = type.toNativeValue();
  debugPrint(
    '[IframeWebView][$label] fatal=$fatal url=$requestUrl '
    'isForMainFrame=$isForMainFrame type=$type nativeCode=$native '
    'desc=${error.description}',
  );
}

void debugPrintIframeWebHttpErrorDetails({
  required String label,
  required WebUri? requestUrl,
  required bool? isForMainFrame,
  required int statusCode,
  required bool fatal,
}) {
  debugPrint(
    '[IframeWebView][$label] fatal=$fatal HTTP $statusCode '
    'url=$requestUrl isForMainFrame=$isForMainFrame',
  );
}
