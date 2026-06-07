import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class NewDiscussionPage extends StatefulWidget {
  const NewDiscussionPage({
    super.key,
    required this.url,
  });

  final String url;

  @override
  State<NewDiscussionPage> createState() => _NewDiscussionPageState();
}

class _NewDiscussionPageState extends State<NewDiscussionPage> {
  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;

  void _setLoading(bool value) {
    if (!mounted) return;
    setState(() {
      _isLoading = value;
    });
  }

  void _setError(bool value) {
    if (!mounted) return;
    setState(() {
      _hasError = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isCompact = screenW < 800;
    return SafeArea(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Align(
          alignment: Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: isCompact ? 1 : 0.7,
            heightFactor: isCompact ? 1 : 0.9,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color.fromARGB(59, 255, 255, 255),
                borderRadius: isCompact
                    ? BorderRadius.zero
                    : const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: isCompact
                      ? BorderRadius.zero
                      : const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                ),
                child: ClipRRect(
                  borderRadius: isCompact
                      ? BorderRadius.zero
                      : const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                  child: Scaffold(
                    backgroundColor: const Color(0xff121212),
                    body: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xff161616), Color(0xff080808)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Create a new discussion'.tr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                tooltip: 'Refresh'.tr,
                                onPressed: () => _controller?.reload(),
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                              IconButton(
                                tooltip: 'Open in Browser'.tr,
                                onPressed: () => launchUrlString(widget.url),
                                icon: const Icon(Icons.open_in_new),
                              ),
                              IconButton(
                                tooltip: 'Close'.tr,
                                onPressed: () => Get.back(),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              if (!_hasError)
                                InAppWebView(
                                  initialUrlRequest: URLRequest(
                                    url: WebUri(widget.url),
                                  ),
                                  initialSettings: InAppWebViewSettings(
                                    transparentBackground: true,
                                  ),
                                  onWebViewCreated: (controller) {
                                    _controller = controller;
                                  },
                                  onLoadStart: (_, __) {
                                    _setError(false);
                                    _setLoading(true);
                                  },
                                  onLoadStop: (_, __) => _setLoading(false),
                                  onReceivedError: (_, __, ___) {
                                    _setError(true);
                                    _setLoading(false);
                                  },
                                  onReceivedHttpError: (_, __, ___) {
                                    _setError(true);
                                    _setLoading(false);
                                  },
                                )
                              else
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        color: Color(0xffB3B3B1),
                                        size: 32,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Unable to load embedded page'.tr,
                                        style: const TextStyle(
                                          color: Color(0xffB3B3B1),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                        onPressed: () =>
                                            launchUrlString(widget.url),
                                        child: Text('Open in Browser'.tr),
                                      ),
                                    ],
                                  ),
                                ),
                              if (_isLoading && !_hasError)
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
