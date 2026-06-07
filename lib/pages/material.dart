import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_canvas.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_theme.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/android_input_lock.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/video_archive_codec.dart';
import 'package:inter_knot/models/video_upload_prepare_result.dart';
import 'package:url_launcher/url_launcher_string.dart';

class KnockKnockPage extends StatefulWidget {
  const KnockKnockPage({super.key});

  @override
  State<KnockKnockPage> createState() => _KnockKnockPageState();
}

class _KnockKnockPageState extends State<KnockKnockPage> {
  static const _newGistLink = 'https://gist.github.com/';
  /// Persisted history of past stories for replay; separate from the `chat_mockup_draft` key (current canvas only).
  static const _localStoryTapeStorageKey = 'knock_knock_local_story_tape';
  static const _localStoryTapeMaxEntries = 80;
  final GlobalKey<ChatMockupCanvasState> _canvasKey =
      GlobalKey<ChatMockupCanvasState>();
  bool _isHandlingClose = false;
  bool _isHandlingNewStory = false;
  bool _isCanvasDraftLoaded = false;
  bool _isCanvasAiReady = false;
  bool _isCanvasEditing = false;
  /// When true, only the one-line header is shown; the horizontal list is hidden.
  bool _isLocalTapeCollapsed = true;
  final List<Map<String, dynamic>> _localStoryTape = [];

  static String _twoDigits(int n) => n.toString().padLeft(2, '0');

  static String _formatTapeTimeMs(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${_twoDigits(d.month)}-${_twoDigits(d.day)} '
        '${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
  }

  static String _tapeEntryTitle(Map<String, dynamic> entry) {
    final title = entry['chatTitle'];
    if (title is String && title.trim().isNotEmpty) {
      return title.trim();
    }
    return '旧的故事';
  }

  static int _tapeEntryMessageCount(Map<String, dynamic> entry) {
    final items = entry['items'];
    if (items is List) return items.length;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadLocalStoryTapeFromStorage();
  }

  void _trimLocalStoryTapeToMax() {
    if (_localStoryTape.length <= _localStoryTapeMaxEntries) return;
    _localStoryTape.removeRange(
      _localStoryTapeMaxEntries,
      _localStoryTape.length,
    );
  }

  void _loadLocalStoryTapeFromStorage() {
    final raw = box.read(_localStoryTapeStorageKey);
    if (raw is! String || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final e in decoded) {
        if (e is Map<String, dynamic>) {
          _localStoryTape.add(Map<String, dynamic>.from(e));
        } else if (e is Map) {
          _localStoryTape.add(Map<String, dynamic>.from(e));
        }
      }
      final beforeTrim = _localStoryTape.length;
      _trimLocalStoryTapeToMax();
      if (_localStoryTape.length < beforeTrim && !_persistLocalStoryTape()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '本地阵列条目过多已自动裁剪，但未能写回本机，刷新后仍可能看到旧条目',
              ),
            ),
          );
        });
      }
    } catch (e, st) {
      debugPrint('KnockKnock local story tape load failed: $e\n$st');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本地阵列加载失败，本次会话将从空白阵列开始')),
        );
      });
    }
  }

  bool _persistLocalStoryTape() {
    try {
      box.write(_localStoryTapeStorageKey, jsonEncode(_localStoryTape));
      return true;
    } catch (e, st) {
      debugPrint('KnockKnock local story tape persist failed: $e\n$st');
      return false;
    }
  }

  Future<void> _confirmClearLocalStoryTape() async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('清空本地阵列'),
          content: const Text(
            '将移除本页记录的所有本地故事条目（不影响当前画布草稿）。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() {
      _localStoryTape.clear();
      _isLocalTapeCollapsed = true;
    });
    if (!_persistLocalStoryTape()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('清空后未能写入本机，刷新后阵列可能仍会显示旧数据'),
        ),
      );
    }
  }

  void _deleteLocalTapeEntryAt(int index) {
    if (index < 0 || index >= _localStoryTape.length) return;
    setState(() {
      _localStoryTape.removeAt(index);
      if (_localStoryTape.isEmpty) {
        _isLocalTapeCollapsed = true;
      }
    });
    if (!_persistLocalStoryTape()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('删除后未能写入本机，刷新后阵列可能仍会显示旧数据'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteLocalTapeEntryAt(int index) async {
    if (!mounted || index < 0 || index >= _localStoryTape.length) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('删除本地故事'),
          content: const Text('将从本地阵列移除这一条记录（不影响当前画布草稿）。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    if (index < 0 || index >= _localStoryTape.length) return;
    _deleteLocalTapeEntryAt(index);
  }

  Future<void> _showLocalTapeEntryMenu(
    BuildContext menuContext,
    Offset globalPosition,
    int index,
  ) async {
    final overlay = Navigator.of(menuContext).overlay!.context.findRenderObject()!
        as RenderBox;
    final topLeft = overlay.localToGlobal(Offset.zero);
    final menuPosition = RelativeRect.fromRect(
      Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 1, 1),
      Rect.fromLTWH(
        topLeft.dx,
        topLeft.dy,
        overlay.size.width,
        overlay.size.height,
      ),
    );
    final selected = await showMenu<String>(
      context: menuContext,
      position: menuPosition,
      items: const [
        PopupMenuItem<String>(
          value: 'delete',
          child: Text('删除旧的故事'),
        ),
      ],
    );
    if (!mounted || selected != 'delete') return;
    await _confirmDeleteLocalTapeEntryAt(index);
  }

  Future<void> _handleNewStoryPressed() async {
    final canvas = _canvasKey.currentState;
    if (!mounted ||
        canvas == null ||
        !_isCanvasDraftLoaded ||
        _isHandlingClose ||
        _isCanvasEditing ||
        canvas.isEditingText ||
        _isHandlingNewStory) {
      return;
    }
    _isHandlingNewStory = true;
    try {
      final canProceedInvalid =
          await _handlePendingInvalidDraftBeforeNewStory(canvas);
      if (!mounted || !canProceedInvalid) return;

      final snap = await canvas.buildCurrentStorySnapshot();
      if (!mounted || snap == null) return;

      // Draft key only ever stores the **current** canvas; this persists what we're leaving.
      final savedOld = await canvas.saveDraftCache();
      if (!mounted) return;
      if (!savedOld) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('旧故事保存失败')),
        );
        return;
      }

      final archiveTape = !canvas.isSnapshotEquivalentToFreshTemplate(snap);
      var tapeInserted = false;
      if (archiveTape) {
        setState(() {
          _localStoryTape.insert(0, Map<String, dynamic>.from(snap));
          _trimLocalStoryTapeToMax();
        });
        tapeInserted = true;
        if (!_persistLocalStoryTape() && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('本地阵列未保存到本机，刷新后可能丢失'),
            ),
          );
        }
      }

      final resetOk = await canvas.startNewStory();
      if (!mounted) return;
      if (!resetOk) {
        if (tapeInserted) {
          setState(() {
            if (_localStoryTape.isNotEmpty) {
              _localStoryTape.removeAt(0);
            }
          });
          _persistLocalStoryTape();
        }
        final restored = await canvas.restoreStoryFromSnapshot(snap);
        if (!mounted) return;
        final message = switch (restored) {
          ChatMockupStoryRestoreResult.failed =>
            '新故事草稿写入失败，且未能恢复刚才的故事，请尽快导出当前内容',
          ChatMockupStoryRestoreResult.failedPreviewActive =>
            '新故事草稿写入失败：恢复前请先停止预览',
          ChatMockupStoryRestoreResult.failedAiBusy =>
            '新故事草稿写入失败：恢复前请等待或停止 AI 生成',
          ChatMockupStoryRestoreResult.failedEditingText =>
            '新故事草稿写入失败：恢复前请先结束编辑',
          ChatMockupStoryRestoreResult.failedUnmounted =>
            '新故事草稿写入失败：页面已切换，请手动检查画布内容',
          ChatMockupStoryRestoreResult.restoredPersistFailed =>
            '新故事草稿写入失败，已恢复刚才的故事，但草稿未能写入本地，请尽快导出备份',
          ChatMockupStoryRestoreResult.restoredPersisted =>
            '新故事草稿写入失败，已恢复刚才的故事',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        return;
      }

      if (!_isLocalTapeCollapsed) {
        setState(() {
          _isLocalTapeCollapsed = true;
        });
      }
      final successMsg = archiveTape
          ? '旧故事已存入本地故事阵列，已开始新的空白故事。（草稿槽仅保存当前正在编辑的一篇）'
          : '已开始新的空白故事；先前无可归档内容，未写入阵列。（草稿槽仅为当前篇）';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } finally {
      _isHandlingNewStory = false;
    }
  }

  Future<void> _onLocalTapeEntryTapped(Map<String, dynamic> entry) async {
    final canvas = _canvasKey.currentState;
    if (!mounted ||
        canvas == null ||
        !_isCanvasDraftLoaded ||
        _isHandlingClose ||
        _isCanvasEditing ||
        canvas.isEditingText ||
        _isHandlingNewStory) {
      return;
    }
    final restored = await canvas.restoreStoryFromSnapshot(entry);
    if (!mounted) return;
    final message = switch (restored) {
      ChatMockupStoryRestoreResult.failed => '恢复故事失败',
      ChatMockupStoryRestoreResult.failedPreviewActive =>
        '请先停止预览再恢复故事',
      ChatMockupStoryRestoreResult.failedAiBusy =>
        '请等待 AI 生成结束或停止后再恢复故事',
      ChatMockupStoryRestoreResult.failedEditingText =>
        '请先结束编辑再恢复故事',
      ChatMockupStoryRestoreResult.failedUnmounted =>
        '页面已切换，恢复未完成',
      ChatMockupStoryRestoreResult.restoredPersistFailed =>
        '已从本地阵列恢复该故事，但草稿保存失败，请尽快导出备份',
      ChatMockupStoryRestoreResult.restoredPersisted => '已从本地阵列恢复该故事',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _buildPublishTemplate(VideoUploadPrepareResult result) {
    return result.recommendedBodySnippet;
  }

  Future<void> _showUploadGuideDialog(
    BuildContext context,
    ChatMockupCanvasState canvas,
    VideoUploadPrepareResult result,
  ) async {
    final isGistRequired = result.mode == VideoUploadPublishMode.gistRequired;
    final gistController = TextEditingController();
    final gistFocusNode = FocusNode();
    String? validatedGistRawUrl;
    String? gistValidationError;
    String buildFinalBodyText() {
      if (!isGistRequired) return _buildPublishTemplate(result);
      final url = validatedGistRawUrl ??
          'https://gist.githubusercontent.com/<user>/<gist-id>/raw';
      return '【影片简介】\n（在这里写简介）\n\n$url';
    }

    final modeText =
        result.mode == VideoUploadPublishMode.inline ? '内联模式' : 'Gist 模式（必需）';
    final modeHint = result.mode == VideoUploadPublishMode.inline
        ? '正文末尾直接粘贴 {payload}'
        : '正文末尾粘贴 gist raw 链接（单独一行）';
    final steps = result.mode == VideoUploadPublishMode.inline
        ? <String>[
            '已复制影片数据',
            '打开 GitHub 影片发布页',
            '标题填写：影片标题 + [标签]',
            '正文先写简介，再把 {payload} 粘贴到最后一行',
            '点击发布',
          ]
        : <String>[
            '已复制影片数据',
            '打开 Gist 新建页并粘贴内容后创建',
            '粘贴 gist 链接并点击「校验并规范化」',
            '打开 GitHub 影片发布页',
            '点击「复制最终正文」并发布',
          ];
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocalState) {
              final finalBody = buildFinalBodyText();
              final canFinish = !isGistRequired || validatedGistRawUrl != null;
              return Dialog(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 720, maxHeight: 820),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '上传影片到 GitHub',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: isGistRequired
                                ? const Color(0xFFFFF1F1)
                                : const Color(0xFFF3F8FF),
                            border: Border.all(
                              color: isGistRequired
                                  ? const Color(0xFFFF9393)
                                  : const Color(0xFF93B9FF),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '发布模式：$modeText',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(modeHint),
                              const SizedBox(height: 4),
                              Text(
                                  '原始 ${result.jsonChars} 字符，压缩后 ${result.encodedChars} 字符'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '步骤',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        for (var i = 0; i < steps.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text('${i + 1}. ${steps[i]}'),
                          ),
                        if (isGistRequired) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: gistController,
                            focusNode: gistFocusNode,
                            onTap: AndroidInputLock.lock,
                            onTapOutside: (_) {
                              if (AndroidInputLock.isLocked) return;
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            decoration: const InputDecoration(
                              labelText:
                                  '粘贴 Gist 链接（支持 gist.github / gist raw）',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              AnimatedBuilder(
                                animation: Listenable.merge([
                                  AndroidInputLock.lockedListenable,
                                  gistFocusNode,
                                ]),
                                builder: (context, _) {
                                  final showConfirm = AndroidInputLock
                                          .requiresExplicitConfirm &&
                                      AndroidInputLock.isLocked &&
                                      gistFocusNode.hasFocus;
                                  if (!showConfirm) {
                                    return const SizedBox.shrink();
                                  }
                                  return OutlinedButton(
                                    onPressed: () {
                                      AndroidInputLock.unlock();
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                    },
                                    child: const Text('确认输入'),
                                  );
                                },
                              ),
                              OutlinedButton(
                                onPressed: () {
                                  AndroidInputLock.unlock();
                                  final checked =
                                      normalizeVideoPayloadGistRawUrlDetailed(
                                    gistController.text,
                                  );
                                  setLocalState(() {
                                    if (checked.rawUrl != null) {
                                      validatedGistRawUrl = checked.rawUrl;
                                      gistValidationError = null;
                                      gistController.text = checked.rawUrl!;
                                    } else {
                                      validatedGistRawUrl = null;
                                      gistValidationError = checked.error;
                                    }
                                  });
                                },
                                child: const Text('校验并规范化'),
                              ),
                              if (validatedGistRawUrl != null)
                                SelectableText(
                                  '已规范化：$validatedGistRawUrl',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              if (gistValidationError != null)
                                SelectableText(
                                  '校验失败：$gistValidationError',
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          '最终正文（可复制）',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFF7F7F7),
                              border:
                                  Border.all(color: const Color(0xFFDDDDDD)),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(finalBody),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                if (canvas.isEditingText) return;
                                await canvas.prepareVideoUpload();
                              },
                              child: const Text('复制数据'),
                            ),
                            OutlinedButton(
                              onPressed: () => launchUrlString(_newGistLink),
                              child: const Text('打开 Gist'),
                            ),
                            OutlinedButton(
                              onPressed: () =>
                                  launchUrlString(newVideoDiscussionLink),
                              child: const Text('新建发布页'),
                            ),
                            OutlinedButton(
                              onPressed: isGistRequired &&
                                      validatedGistRawUrl == null
                                  ? null
                                  : () async {
                                      await Clipboard.setData(
                                        ClipboardData(text: finalBody),
                                      );
                                      if (!ctx.mounted) return;
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                            content: Text('已复制最终正文')),
                                      );
                                    },
                              child: const Text('复制最终正文'),
                            ),
                            FilledButton(
                              onPressed: canFinish
                                  ? () => Navigator.of(ctx).pop()
                                  : null,
                              child: const Text('完成'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      AndroidInputLock.unlock();
      gistFocusNode.dispose();
      gistController.dispose();
    }
  }

  void _showDraftSaveFailedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('草稿保存失败，请先导出当前内容。')),
    );
  }

  /// Resolves [ChatMockupCanvasState.hasPendingInvalidDraft] before archiving the
  /// current story; unlike close, export / keep-old paths do not continue「新的故事」.
  Future<bool> _handlePendingInvalidDraftBeforeNewStory(
    ChatMockupCanvasState canvas,
  ) async {
    if (!canvas.hasPendingInvalidDraft) {
      return true;
    }
    if (!mounted) return false;
    final action = await showDialog<_PendingInvalidDraftAction>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('旧草稿待处理'),
          content: const Text(
            '当前仍有旧草稿待处理，不能直接保存新草稿，否则会覆盖旧草稿。\n'
            '若要开始新的故事，请先导出备份，或丢弃旧草稿并保存当前画布。',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_PendingInvalidDraftAction.cancel),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.exportCurrent),
              child: const Text('导出当前内容'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.keepOldDiscardCurrent),
              child: const Text('保留旧草稿（取消）'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.discardOldSaveCurrent),
              child: const Text('丢弃旧草稿并保存当前内容'),
            ),
          ],
        );
      },
    );
    if (action == null || action == _PendingInvalidDraftAction.cancel) {
      return false;
    }
    switch (action) {
      case _PendingInvalidDraftAction.exportCurrent:
        final exported = await canvas.exportJson();
        if (!exported && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('导出失败，未开始新的故事')),
          );
        } else if (exported && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已导出。旧草稿仍未处理，请再选择丢弃旧草稿或取消'),
            ),
          );
        }
        return false;
      case _PendingInvalidDraftAction.keepOldDiscardCurrent:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已取消：未开始新的故事')),
          );
        }
        return false;
      case _PendingInvalidDraftAction.discardOldSaveCurrent:
        final saved = await canvas.forceSaveDraftCache();
        if (!saved) _showDraftSaveFailedSnack();
        return saved;
      case _PendingInvalidDraftAction.cancel:
        return false;
    }
  }

  Future<bool> _handlePendingInvalidDraftBeforeClose(
    ChatMockupCanvasState canvas,
  ) async {
    if (!canvas.hasPendingInvalidDraft) {
      final saved = await canvas.saveDraftCache();
      if (!saved) _showDraftSaveFailedSnack();
      return saved;
    }
    if (!mounted) return false;
    final action = await showDialog<_PendingInvalidDraftAction>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('旧草稿待处理'),
          content: const Text(
            '当前仍有旧草稿待处理，不能直接保存新草稿，否则会覆盖旧草稿。',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(_PendingInvalidDraftAction.cancel),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.exportCurrent),
              child: const Text('导出当前内容并关闭'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.keepOldDiscardCurrent),
              child: const Text('丢弃当前内容，保留旧草稿'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx)
                  .pop(_PendingInvalidDraftAction.discardOldSaveCurrent),
              child: const Text('丢弃旧草稿并保存当前内容'),
            ),
          ],
        );
      },
    );
    if (action == null || action == _PendingInvalidDraftAction.cancel) {
      return false;
    }
    switch (action) {
      case _PendingInvalidDraftAction.exportCurrent:
        final exported = await canvas.exportJson();
        return exported;
      case _PendingInvalidDraftAction.keepOldDiscardCurrent:
        return true;
      case _PendingInvalidDraftAction.discardOldSaveCurrent:
        final saved = await canvas.forceSaveDraftCache();
        if (!saved) _showDraftSaveFailedSnack();
        return saved;
      case _PendingInvalidDraftAction.cancel:
        return false;
    }
  }

  Future<bool> _handleClosePressed() async {
    if (_isHandlingClose) return false;
    if (_canvasKey.currentState?.isEditingText == true) return false;
    _isHandlingClose = true;
    try {
      final canvas = _canvasKey.currentState;
      if (canvas == null) {
        Get.back();
        return true;
      }
      if (!canvas.isDraftLoaded) return false;
      if (!canvas.hasUnexportedChanges) {
        final canClose = await _handlePendingInvalidDraftBeforeClose(canvas);
        if (!canClose || !mounted) return false;
        if (!mounted) return false;
        Get.back();
        return true;
      }
      if (!mounted) return false;
      final action = await showDialog<_CloseAction>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('存在未导出修改'),
            content: const Text('关闭前可先导出。若选择不导出并关闭，不会导出文件，但会保留本机草稿。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(_CloseAction.cancel),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_CloseAction.closeWithoutExport),
                child: const Text('不导出并关闭'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(ctx).pop(_CloseAction.exportAndClose),
                child: const Text('导出并关闭'),
              ),
            ],
          );
        },
      );
      if (action == null || action == _CloseAction.cancel) return false;
      if (action == _CloseAction.exportAndClose) {
        final exported = await canvas.exportJson();
        if (!exported || !mounted) return false;
      }
      final canClose = await _handlePendingInvalidDraftBeforeClose(canvas);
      if (!canClose || !mounted) return false;
      if (!mounted) return false;
      Get.back();
      return true;
    } finally {
      _isHandlingClose = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final canOperateTopActions =
        _isCanvasDraftLoaded && !_isHandlingClose && !_isCanvasEditing;
    final canUpload = canOperateTopActions && _isCanvasAiReady;
    final canNewStory = canOperateTopActions && !_isHandlingNewStory;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        await _handleClosePressed();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      enabled: canOperateTopActions,
                      onSelected: (value) async {
                        final canvas = _canvasKey.currentState;
                        if (canvas == null) return;
                        if (canvas.isEditingText) return;
                        switch (value) {
                          case 'upload':
                            final result = await canvas.prepareVideoUpload();
                            if (result == null || !context.mounted) return;
                            await _showUploadGuideDialog(
                              context,
                              canvas,
                              result,
                            );
                          case 'export':
                            await canvas.exportJson();
                          case 'export_clean':
                            await canvas.exportCleanText();
                          case 'import':
                            canvas.importJson();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'upload',
                          enabled: canUpload,
                          child: const Text('上传'),
                        ),
                        PopupMenuItem<String>(
                          value: 'export',
                          enabled: canOperateTopActions,
                          child: const Text('导出'),
                        ),
                        PopupMenuItem<String>(
                          value: 'export_clean',
                          enabled: canOperateTopActions,
                          child: const Text('干净导出'),
                        ),
                        PopupMenuItem<String>(
                          value: 'import',
                          enabled: canOperateTopActions,
                          child: const Text('导入'),
                        ),
                      ],
                      child: Builder(
                        builder: (context) {
                          final theme = Theme.of(context);
                          final states = <WidgetState>{
                            if (!canOperateTopActions) WidgetState.disabled,
                          };
                          final fg = TextButtonTheme.of(context)
                                  .style
                                  ?.foregroundColor
                                  ?.resolve(states) ??
                              (canOperateTopActions
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.38));
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '文件',
                              style: theme.textTheme.labelLarge?.copyWith(
                                    color: fg,
                                  ) ??
                                  TextStyle(color: fg),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: canNewStory
                          ? () {
                              if (_canvasKey.currentState?.isEditingText ==
                                  true) {
                                return;
                              }
                              unawaited(_handleNewStoryPressed());
                            }
                          : null,
                      child: const Text('新的故事'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: canOperateTopActions
                          ? () {
                              if (_canvasKey.currentState?.isEditingText ==
                                  true) {
                                return;
                              }
                              _canvasKey.currentState?.showAiSettings();
                            }
                          : null,
                      child: const Text('AI'),
                    ),
                    const SizedBox(width: 8),
                    ClickRegion(
                      onTap: () {
                        if (!canOperateTopActions) {
                          return;
                        }
                        if (_canvasKey.currentState?.isEditingText == true) {
                          return;
                        }
                        unawaited(_handleClosePressed());
                      },
                      child:
                          Assets.images.closeBtn.image(width: 44, height: 44),
                    ),
                  ],
                ),
              ),
              if (_localStoryTape.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: Tooltip(
                            message: _isLocalTapeCollapsed ? '展开列表' : '收起列表',
                            waitDuration: const Duration(milliseconds: 400),
                            child: Semantics(
                              button: true,
                              label: _isLocalTapeCollapsed
                                  ? '展开本地故事列表'
                                  : '收起本地故事列表',
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isLocalTapeCollapsed =
                                        !_isLocalTapeCollapsed;
                                  });
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '本地故事阵列 (${_localStoryTape.length})',
                                          style: TextStyle(
                                            color: Colors.grey.shade400,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      ExcludeSemantics(
                                        child: Icon(
                                          _isLocalTapeCollapsed
                                              ? Icons.expand_more
                                              : Icons.expand_less,
                                          size: 20,
                                          color: Colors.grey.shade500,
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
                      TextButton(
                        onPressed: canOperateTopActions && !_isHandlingNewStory
                            ? _confirmClearLocalStoryTape
                            : null,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade500,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('清空'),
                      ),
                    ],
                  ),
                ),
              if (_localStoryTape.isNotEmpty)
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _isLocalTapeCollapsed
                      ? const SizedBox.shrink()
                      : SizedBox(
                          height: 88,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            scrollDirection: Axis.horizontal,
                            itemCount: _localStoryTape.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final entry = _localStoryTape[index];
                              final ms = entry['capturedAtMs'];
                              final timeLabel = ms is int
                                  ? _formatTapeTimeMs(ms)
                                  : '';
                              final title = _tapeEntryTitle(entry);
                              final count = _tapeEntryMessageCount(entry);
                              final canTapeTap = canOperateTopActions &&
                                  !_isHandlingNewStory;
                              final canTapeMenu = canTapeTap;
                              return Material(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(10),
                                child: Builder(
                                  builder: (tapeCtx) {
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(10),
                                      onTap: canTapeTap
                                          ? () => unawaited(
                                              _onLocalTapeEntryTapped(entry),
                                            )
                                          : null,
                                      onLongPress: canTapeMenu
                                          ? () {
                                              final box = tapeCtx
                                                      .findRenderObject()
                                                  as RenderBox?;
                                              if (box == null) return;
                                              final global = box.localToGlobal(
                                                box.size.center(Offset.zero),
                                              );
                                              unawaited(
                                                _showLocalTapeEntryMenu(
                                                  tapeCtx,
                                                  global,
                                                  index,
                                                ),
                                              );
                                            }
                                          : null,
                                      onSecondaryTapDown: canTapeMenu
                                          ? (details) => unawaited(
                                                _showLocalTapeEntryMenu(
                                                  tapeCtx,
                                                  details.globalPosition,
                                                  index,
                                                ),
                                              )
                                          : null,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 160,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                timeLabel.isEmpty
                                                    ? '—'
                                                    : timeLabel,
                                                style: TextStyle(
                                                  color: Colors.grey.shade500,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$count 条消息',
                                                style: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ChatMockupTheme.canvasMaxWidth,
                    ),
                    child: ChatMockupCanvas(
                      key: _canvasKey,
                      onDraftLoadedChanged: (loaded) {
                        if (!mounted) return;
                        setState(() {
                          _isCanvasDraftLoaded = loaded;
                          _isCanvasAiReady =
                              _canvasKey.currentState?.isAiInitialized ?? false;
                        });
                      },
                      onAiInitializedChanged: (ready) {
                        if (!mounted) return;
                        setState(() => _isCanvasAiReady = ready);
                      },
                      onEditingChanged: (editing) {
                        if (!mounted) return;
                        setState(() => _isCanvasEditing = editing);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _CloseAction {
  exportAndClose,
  closeWithoutExport,
  cancel,
}

enum _PendingInvalidDraftAction {
  /// Backup current canvas to file; does not close the page by itself.
  exportCurrent,
  keepOldDiscardCurrent,
  discardOldSaveCurrent,
  cancel,
}
