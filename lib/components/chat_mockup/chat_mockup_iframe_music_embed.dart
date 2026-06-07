import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_bubble.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/helpers/chat_mockup_iframe_music_policy.dart';
import 'package:inter_knot/helpers/iframe_webview_error_utils.dart';
import 'package:inter_knot/helpers/logger.dart';

/// Visible [InAppWebView] for **chat mockup** iframe background music during preview.
///
/// When [active] becomes false, loads `about:blank` like [IframePlayer] to release media.
/// The platform view stays in the tree (offstage) until that navigation finishes; the
/// parent should keep [url] stable until [onTeardownComplete] runs with the matching
/// [teardownAckToken].
class ChatMockupIframeMusicEmbed extends StatefulWidget {
  const ChatMockupIframeMusicEmbed({
    super.key,
    required this.url,
    required this.active,
    required this.isMe,
    required this.teardownAckToken,
    this.onMainDocumentLoadFailed,
    this.onTeardownComplete,
  });

  final String? url;
  final bool active;
  final bool isMe;

  /// Token echoed in [onTeardownComplete]; parent must only clear iframe state when
  /// it still matches the pending teardown cycle.
  final int teardownAckToken;

  /// Called at most once per failed embed load (until error state is cleared),
  /// when the main document hits a fatal [WebResourceError] or HTTP error (4xx+).
  final void Function(String message)? onMainDocumentLoadFailed;

  /// Called after `about:blank` has been applied while still mounted (inactive branch).
  /// [token] is the [teardownAckToken] captured when this inactive teardown started.
  final void Function(int token)? onTeardownComplete;

  @override
  State<ChatMockupIframeMusicEmbed> createState() =>
      _ChatMockupIframeMusicEmbedState();
}

class _ChatMockupIframeMusicEmbedState extends State<ChatMockupIframeMusicEmbed> {
  static const double _maxInnerWidth = 210;

  bool _isReady = false;
  bool _hasError = false;
  bool _isTearingDown = false;
  bool _isDisposed = false;
  bool _inactiveTeardownVisual = false;
  int _ackTokenForThisTeardown = 0;
  bool _mainDocumentLoadFailureNotified = false;
  InAppWebViewController? _controller;

  void _clearEmbedErrorState() {
    _hasError = false;
    _mainDocumentLoadFailureNotified = false;
  }

  String _truncateDetail(String raw, {int maxLen = 120}) {
    final t = raw.trim();
    if (t.length <= maxLen) return t;
    return '${t.substring(0, maxLen - 1)}…';
  }

  void _setMainDocumentFatalError(String userDetail) {
    if (_mainDocumentLoadFailureNotified) return;
    if (!mounted) return;
    _mainDocumentLoadFailureNotified = true;
    setState(() {
      _hasError = true;
    });
    widget.onMainDocumentLoadFailed?.call(_truncateDetail(userDetail));
  }

  @override
  void initState() {
    super.initState();
    if (widget.active && (widget.url ?? '').trim().isNotEmpty) {
      _isReady = true;
    }
  }

  /// Blanks the document and releases media. Does not run after [_isDisposed].
  Future<void> _disposeWebView() async {
    if (_isDisposed) {
      logger.d(
        'ChatMockupIframeMusicEmbed teardown skip disposed '
        'url=${widget.url}',
      );
      return;
    }
    if (_isTearingDown) {
      logger.d(
        'ChatMockupIframeMusicEmbed teardown skip (already running) '
        'url=${widget.url}',
      );
      return;
    }
    _isTearingDown = true;
    logger.d(
      'ChatMockupIframeMusicEmbed teardown start url=${widget.url} '
      'op=${identityHashCode(this)}',
    );
    final controller = _controller;
    if (controller == null) {
      logger.d(
        'ChatMockupIframeMusicEmbed teardown end (no controller) '
        'url=${widget.url} op=${identityHashCode(this)}',
      );
      _isTearingDown = false;
      return;
    }
    try {
      await controller.stopLoading();
      if (_isDisposed) {
        logger.d(
          'ChatMockupIframeMusicEmbed teardown aborted after stopLoading '
          '(disposed) op=${identityHashCode(this)}',
        );
        _controller = null;
        return;
      }
      await controller.loadUrl(
        urlRequest: URLRequest(url: WebUri('about:blank')),
      );
      logger.d(
        'ChatMockupIframeMusicEmbed teardown end ok url=${widget.url} '
        'op=${identityHashCode(this)}',
      );
    } catch (e, s) {
      logger.d(
        'ChatMockupIframeMusicEmbed teardown fail url=${widget.url} err=$e '
        'op=${identityHashCode(this)}',
      );
      logger.d(s.toString());
    } finally {
      _isTearingDown = false;
    }
    _controller = null;
  }

  Future<void> _runInactiveTeardown() async {
    final tokenOut = _ackTokenForThisTeardown;
    try {
      await _disposeWebView();
    } finally {
      logger.d(
        'ChatMockupIframeMusicEmbed inactiveTeardown finally token=$tokenOut '
        'op=${identityHashCode(this)}',
      );
      widget.onTeardownComplete?.call(tokenOut);
    }
  }

  @override
  void didUpdateWidget(covariant ChatMockupIframeMusicEmbed oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wantShow = widget.active && (widget.url ?? '').trim().isNotEmpty;
    final oldShow = oldWidget.active && (oldWidget.url ?? '').trim().isNotEmpty;

    logger.d(
      'ChatMockupIframeMusicEmbed didUpdate wantShow=$wantShow oldShow=$oldShow '
      'url=${widget.url} active=${widget.active} '
      'inactiveVisual=$_inactiveTeardownVisual op=${identityHashCode(this)}',
    );

    if (!wantShow && oldShow) {
      _ackTokenForThisTeardown = widget.teardownAckToken;
      _inactiveTeardownVisual = true;
      if (mounted) {
        setState(() {});
      }
      unawaited(_runInactiveTeardown());
      return;
    }

    if (wantShow && !oldShow) {
      _inactiveTeardownVisual = false;
      if (mounted) {
        setState(() {
          _isReady = true;
          _clearEmbedErrorState();
        });
      }
    }

    if (wantShow &&
        oldShow &&
        widget.url != oldWidget.url &&
        _controller != null) {
      _inactiveTeardownVisual = false;
      final next = widget.url!.trim();
      if (mounted) {
        setState(() {
          _clearEmbedErrorState();
        });
      }
      logger.d(
        'ChatMockupIframeMusicEmbed url change loadUrl next=$next '
        'op=${identityHashCode(this)}',
      );
      unawaited(
        _controller!.loadUrl(
          urlRequest: URLRequest(url: WebUri(next)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    logger.d(
      'ChatMockupIframeMusicEmbed dispose url=${widget.url} '
      'inactiveVisual=$_inactiveTeardownVisual op=${identityHashCode(this)}',
    );
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.url?.trim();
    final showActive =
        widget.active && trimmed != null && trimmed.isNotEmpty;
    final needsShell =
        showActive || (_inactiveTeardownVisual && trimmed != null && trimmed.isNotEmpty);

    if (!needsShell) {
      return const SizedBox.shrink();
    }

    final innerH = chatMockupIframeMusicEmbedInnerHeight(trimmed);
    final background =
        widget.isMe ? ChatMockupTheme.outgoing : ChatMockupTheme.incoming;

    final webStack = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ChatMockupBubbleShell(
        isMe: widget.isMe,
        color: background,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: _maxInnerWidth,
              height: innerH,
              child: _isReady && !_hasError
                  ? InAppWebView(
                      key: ValueKey<String>(trimmed),
                      onWebViewCreated: (controller) {
                        if (_isDisposed) {
                          logger.d(
                            'ChatMockupIframeMusicEmbed late create; stopLoading only '
                            'op=${identityHashCode(this)}',
                          );
                          unawaited(controller.stopLoading());
                          return;
                        }
                        _controller = controller;
                      },
                      initialUrlRequest: URLRequest(
                        url: WebUri(trimmed),
                      ),
                      initialSettings: InAppWebViewSettings(
                        mediaPlaybackRequiresUserGesture: false,
                        transparentBackground: true,
                      ),
                      onLoadStart: (_, __) {},
                      onLoadStop: (_, __) {
                        debugPrint(
                          '[IframeWebView][ChatMockupIframeMusicEmbed] onLoadStop '
                          'url=$trimmed',
                        );
                      },
                      onReceivedError: (_, request, error) {
                        final fatal = iframeWebViewRequestIsMainDocumentFailure(
                          request,
                          trimmed,
                        );
                        debugPrintIframeWebResourceErrorDetails(
                          label: 'ChatMockupIframeMusicEmbed',
                          requestUrl: request.url,
                          isForMainFrame: request.isForMainFrame,
                          error: error,
                          fatal: fatal,
                        );
                        if (!fatal || !mounted) return;
                        final desc = error.description.trim();
                        _setMainDocumentFatalError(
                          desc.isNotEmpty
                              ? desc
                              : 'WebView 错误 (${error.type})',
                        );
                      },
                      onReceivedHttpError: (_, request, response) {
                        final code = response.statusCode;
                        final mainDoc =
                            iframeWebViewHttpErrorIsMainDocumentFailure(
                          request,
                          trimmed,
                        );
                        final fatal = mainDoc && code != null && code >= 400;
                        debugPrintIframeWebHttpErrorDetails(
                          label: 'ChatMockupIframeMusicEmbed',
                          requestUrl: request.url,
                          isForMainFrame: request.isForMainFrame,
                          statusCode: code ?? -1,
                          fatal: fatal,
                        );
                        if (!fatal || !mounted) return;
                        _setMainDocumentFatalError('HTTP $code');
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );

    if (_inactiveTeardownVisual && !showActive) {
      return Offstage(
        child: Opacity(
          opacity: 0,
          child: webStack,
        ),
      );
    }
    return webStack;
  }
}
