import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:inter_knot/helpers/iframe_webview_error_utils.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:visibility_detector/visibility_detector.dart';

class IframePlayer extends StatefulWidget {
  const IframePlayer({
    super.key,
    required this.url,
    required this.aspectRatio,
    this.active = true,
  });

  final String url;
  final double aspectRatio;
  final bool active;

  @override
  State<IframePlayer> createState() => _IframePlayerState();
}

class _IframePlayerState extends State<IframePlayer> {
  final _visibilityKey = UniqueKey();
  bool _isInitializing = false;
  bool _isReady = false;
  bool _hasError = false;
  /// First [onLoadStop] after the current navigation (main document finished per platform).
  bool _mainDocumentLoaded = false;
  bool _isTearingDown = false;
  bool _isDisposed = false;
  InAppWebViewController? _controller;

  Future<void> _initWebView() async {
    if (!widget.active) return;
    if (_isInitializing || _isReady) return;
    _isInitializing = true;
    try {
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _disposeWebView() async {
    if (_isTearingDown) {
      logger
          .d('IframePlayer teardown skipped (already running): ${widget.url}');
      return;
    }
    _isTearingDown = true;
    logger.d('IframePlayer teardown started: ${widget.url}');
    final controller = _controller;
    if (controller == null) {
      logger.d('IframePlayer teardown finished (no controller): ${widget.url}');
      _isTearingDown = false;
      return;
    }
    try {
      await controller.stopLoading();
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
      logger.d('IframePlayer teardown finished: ${widget.url}');
    } catch (e, s) {
      logger.d('IframePlayer teardown failed: $e');
      logger.d(s.toString());
    } finally {
      _isTearingDown = false;
    }
    _controller = null;
  }

  @override
  void didUpdateWidget(covariant IframePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url && mounted) {
      setState(() {
        _hasError = false;
        _mainDocumentLoaded = false;
      });
    }
    if (!widget.active && oldWidget.active) {
      unawaited(_disposeWebView());
      if (_isReady && mounted) {
        setState(() {
          _isReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    logger.d('IframePlayer dispose triggered: ${widget.url}');
    unawaited(_disposeWebView());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) {
        if (!widget.active) return;
        if (info.visibleFraction <= 0) return;
        _initWebView();
      },
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: const Color(0xff111111),
            child: _isReady && !_hasError
                ? InAppWebView(
                    key: ValueKey<String>(widget.url),
                    onWebViewCreated: (controller) {
                      if (_isDisposed) {
                        logger.d(
                          'IframePlayer created after dispose, tearing down: ${widget.url}',
                        );
                        unawaited(controller.stopLoading());
                        unawaited(
                          controller.loadUrl(
                            urlRequest: URLRequest(url: WebUri('about:blank')),
                          ),
                        );
                        return;
                      }
                      _controller = controller;
                    },
                    initialUrlRequest: URLRequest(
                      url: WebUri(widget.url),
                    ),
                    initialSettings: InAppWebViewSettings(
                      mediaPlaybackRequiresUserGesture: false,
                      transparentBackground: true,
                    ),
                    onLoadStart: (_, __) {
                      if (!mounted) return;
                      setState(() {
                        _mainDocumentLoaded = false;
                      });
                    },
                    onLoadStop: (_, __) {
                      if (!mounted) return;
                      setState(() {
                        _mainDocumentLoaded = true;
                      });
                      debugPrint(
                        '[IframeWebView][IframePlayer] onLoadStop '
                        'mainDocumentLoaded=$_mainDocumentLoaded '
                        'url=${widget.url}',
                      );
                    },
                    onReceivedError: (_, request, error) {
                      final fatal = iframeWebViewRequestIsMainDocumentFailure(
                        request,
                        widget.url,
                      );
                      debugPrintIframeWebResourceErrorDetails(
                        label: 'IframePlayer',
                        requestUrl: request.url,
                        isForMainFrame: request.isForMainFrame,
                        error: error,
                        fatal: fatal,
                      );
                      if (!fatal || !mounted) return;
                      setState(() {
                        _hasError = true;
                      });
                    },
                    onReceivedHttpError: (_, request, response) {
                      final code = response.statusCode;
                      final mainDoc =
                          iframeWebViewHttpErrorIsMainDocumentFailure(
                        request,
                        widget.url,
                      );
                      final fatal =
                          mainDoc && code != null && code >= 400;
                      debugPrintIframeWebHttpErrorDetails(
                        label: 'IframePlayer',
                        requestUrl: request.url,
                        isForMainFrame: request.isForMainFrame,
                        statusCode: code ?? -1,
                        fatal: fatal,
                      );
                      if (!fatal || !mounted) return;
                      setState(() {
                        _hasError = true;
                      });
                    },
                  )
                : Center(
                    child: _hasError
                        ? TextButton(
                            onPressed: () => launchUrlString(widget.url),
                            child: const Text('Open embedded content'),
                          )
                        : const CircularProgressIndicator(),
                  ),
          ),
        ),
      ),
    );
  }
}
