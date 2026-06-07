import 'dart:async';

import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_canvas.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/helpers/video_player_session_store.dart';
import 'package:inter_knot/models/video_archive_entry.dart';

enum _VideoSessionStartChoice {
  fresh,
  resume,
}

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.entry});

  final VideoArchiveEntry entry;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  GlobalKey<ChatMockupCanvasState> _canvasKey =
      GlobalKey<ChatMockupCanvasState>();

  _VideoSessionStartChoice? _startChoice;
  bool _isClosing = false;

  int get _discussionNumber => widget.entry.discussion.number;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_resolveStartChoice());
    });
  }

  Future<void> _resolveStartChoice() async {
    final decoded = widget.entry.decodedPayload;
    if (decoded == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startChoice = _VideoSessionStartChoice.fresh;
      });
      return;
    }

    final cached = readVideoPlayerSession(_discussionNumber);
    final hash = computeVideoPayloadSourceHash(decoded);
    if (cached == null || cached.sourceHash != hash) {
      if (!mounted) {
        return;
      }
      setState(() {
        _startChoice = _VideoSessionStartChoice.fresh;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    final choice = await showDialog<_VideoSessionStartChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('录像带 AI 对话'),
          content: const Text('检测到本作品有上次的会话记录，请选择如何开始。'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_VideoSessionStartChoice.fresh),
              child: const Text('开始新的对话'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_VideoSessionStartChoice.resume),
              child: const Text('继续上一次对话'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _startChoice = choice ?? _VideoSessionStartChoice.fresh;
    });
  }

  Map<String, dynamic>? _initialPayloadForChoice() {
    final raw = widget.entry.decodedPayload;
    if (raw == null) {
      return null;
    }
    if (_startChoice != _VideoSessionStartChoice.resume) {
      return raw;
    }
    final cached = readVideoPlayerSession(_discussionNumber);
    if (cached == null) {
      return raw;
    }
    return <String, dynamic>{
      ...raw,
      'chatMockup': extractChatMockupContentForSession(cached.chatMockup),
    };
  }

  ChatMockupBrowsePlaybackState? _initialPlaybackStateForChoice() {
    if (_startChoice != _VideoSessionStartChoice.resume) {
      return null;
    }
    final cached = readVideoPlayerSession(_discussionNumber);
    if (cached == null) {
      return null;
    }
    if (cached.visibleItemCount == null && cached.playbackComplete == null) {
      return null;
    }
    final items = cached.chatMockup['items'];
    final itemLength = items is List ? items.length : 0;
    final normalized = normalizeBrowsePlaybackState(
      visibleItemCount: cached.visibleItemCount ?? 0,
      itemLength: itemLength,
      playbackComplete: cached.playbackComplete ?? false,
    );
    return ChatMockupBrowsePlaybackState(
      visibleItemCount: normalized.visibleItemCount,
      playbackComplete: normalized.playbackComplete,
    );
  }

  Future<void> _persistSession() async {
    final decoded = widget.entry.decodedPayload;
    if (decoded == null) {
      return;
    }
    final canvas = _canvasKey.currentState;
    final snap = canvas?.buildCurrentSessionSnapshotForBrowse();
    if (snap == null) {
      return;
    }
    final items = snap['items'];
    final itemLength = items is List ? items.length : 0;
    final normalized = normalizeBrowsePlaybackState(
      visibleItemCount: snap['visibleItemCount'] is int
          ? snap['visibleItemCount'] as int
          : 0,
      itemLength: itemLength,
      playbackComplete: snap['playbackComplete'] == true,
    );
    try {
      await writeVideoPlayerSession(
        VideoPlayerSessionRecord(
          version: kVideoPlayerSessionRecordVersion,
          discussionNumber: _discussionNumber,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          chatMockup: extractChatMockupContentForSession(snap),
          sourceHash: computeVideoPayloadSourceHash(decoded),
          visibleItemCount: normalized.visibleItemCount,
          playbackComplete: normalized.playbackComplete,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('会话保存失败：$e')),
        );
      }
    }
  }

  Future<void> _handlePopInvoked(bool didPop, Object? result) async {
    if (didPop || _isClosing) {
      return;
    }
    _isClosing = true;
    await _persistSession();
    await _canvasKey.currentState?.shutdownBrowsePlaybackForRouteExit();
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _clearSessionAndReset() async {
    await clearVideoPlayerSession(_discussionNumber);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已清除本作品的会话记录')),
    );
    setState(() {
      _canvasKey = GlobalKey<ChatMockupCanvasState>();
      _startChoice = _VideoSessionStartChoice.fresh;
    });
  }

  @override
  Widget build(BuildContext context) {
    final decoded = widget.entry.decodedPayload;
    final choiceReady = _startChoice != null;
    final showCanvas = choiceReady && decoded != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.entry.displayTitle),
          actions: [
            PopupMenuButton<String>(
              itemBuilder: (ctx) => [
                const PopupMenuItem<String>(
                  value: 'clear',
                  child: Text('清除本作品会话记录'),
                ),
              ],
              onSelected: (value) {
                if (value == 'clear') {
                  unawaited(_clearSessionAndReset());
                }
              },
            ),
          ],
        ),
        body: Center(
          child: !choiceReady
              ? const CircularProgressIndicator()
              : !showCanvas
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('无法加载作品数据'),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: ChatMockupTheme.canvasMaxWidth,
                      ),
                      child: ChatMockupCanvas(
                        key: _canvasKey,
                        initialPayload: _initialPayloadForChoice(),
                        initialPlaybackState: _initialPlaybackStateForChoice(),
                        readOnly: true,
                        browseMode: true,
                        autoStartPlayback: true,
                        lockAiMode: true,
                      ),
                    ),
        ),
      ),
    );
  }
}
