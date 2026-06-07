import 'package:flutter/material.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_story_planner.dart';

/// Bottom sheet: outer [ExpansionTile]「剧情构思」with inner「剧情大纲」「构思」.
///
/// Callback bundle keeps [StoryPlannerSheet] decoupled from [ChatMockupCanvasState].
class StoryPlannerSheetController {
  StoryPlannerSheetController({
    required this.getPlanner,
    required this.applyPlanner,
    required this.getItems,
    required this.buildPlotHistory,
    required this.runOutlineAi,
    required this.runIdeationAi,
    required this.rollbackPlannerChatLastUserIfMatches,
    required this.getPlannerAiBusy,
    required this.setPlannerAiBusy,
    required this.isAiInitialized,
    required this.isAiConfigured,
  });

  final ChatMockupStoryPlanner Function() getPlanner;
  final void Function(ChatMockupStoryPlanner next) applyPlanner;
  final List<ChatMockupItem> Function() getItems;
  final String Function(Iterable<ChatMockupItem> items) buildPlotHistory;
  final Future<bool> Function(
    void Function(String accumulated)? onStreamChunk,
  ) runOutlineAi;
  final Future<String?> Function(
    String userMessage,
    void Function(String accumulated)? onStreamChunk,
  ) runIdeationAi;
  final void Function(String userContent) rollbackPlannerChatLastUserIfMatches;
  final bool Function() getPlannerAiBusy;
  final void Function(bool busy) setPlannerAiBusy;
  final bool Function() isAiInitialized;
  final bool Function() isAiConfigured;
}

class StoryPlannerSheet extends StatefulWidget {
  const StoryPlannerSheet({super.key, required this.controller});

  final StoryPlannerSheetController controller;

  @override
  State<StoryPlannerSheet> createState() => _StoryPlannerSheetState();
}

class _StoryPlannerSheetState extends State<StoryPlannerSheet> {
  final _ideationInput = TextEditingController();
  String _ideationStreamPreview = '';
  String _outlineStreamPreview = '';
  bool _outlineStreamSlot = false;
  bool _ideationStreamSlot = false;
  String? _outlineError;

  StoryPlannerSheetController get c => widget.controller;

  @override
  void dispose() {
    _ideationInput.dispose();
    super.dispose();
  }

  Future<void> _confirmClearOutline() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xff262626),
          title: const Text('清空大纲', style: TextStyle(color: Colors.white)),
          content: const Text(
            '将删除已保存的剧情总纲与覆盖记录，之后可重新生成总结。构思对话不受影响。',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    final p = c.getPlanner();
    c.applyPlanner(p.copyWith(
      outlineSummary: '',
      outlineDirty: false,
      coverage: [],
    ));
    setState(() {
      _outlineError = null;
      _outlineStreamPreview = '';
    });
  }

  Future<void> _confirmClearIdeationChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xff262626),
          title: const Text('清空构思对话', style: TextStyle(color: Colors.white)),
          content: const Text(
            '将删除本页与 AI 的构思聊天记录，不影响剧情总纲、覆盖记录与正文。',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('清空'),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    final p = c.getPlanner();
    c.applyPlanner(p.copyWith(chat: []));
    setState(() => _ideationStreamPreview = '');
  }

  Future<void> _onGenerateOutline() async {
    if (!c.isAiInitialized()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 设置加载中…')),
      );
      return;
    }
    if (!c.isAiConfigured()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先补全 AI 设置')),
      );
      return;
    }
    setState(() {
      _outlineError = null;
      _outlineStreamPreview = '';
      _ideationStreamPreview = '';
    });
    c.setPlannerAiBusy(true);
    setState(() => _outlineStreamSlot = true);
    try {
      final ok = await c.runOutlineAi((acc) {
        if (!mounted) return;
        setState(() => _outlineStreamPreview = acc);
      });
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _outlineError = c.getPlanner().outlineDirty
              ? '大纲可能已过期，请先「清空大纲并重新开始」后再生成'
              : '生成失败或无可总结的新剧情';
          _outlineStreamPreview = '';
        });
        return;
      }
      setState(() {
        _outlineError = null;
        _outlineStreamPreview = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('大纲已更新')),
        );
      }
    } finally {
      c.setPlannerAiBusy(false);
      if (mounted) {
        setState(() {
          _outlineStreamSlot = false;
        });
      }
    }
  }

  Future<void> _sendIdeation() async {
    final msg = _ideationInput.text.trim();
    if (msg.isEmpty) return;
    if (!c.isAiInitialized()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI 设置加载中…')),
      );
      return;
    }
    if (!c.isAiConfigured()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先补全 AI 设置')),
      );
      return;
    }
    final p0 = c.getPlanner();
    final userTurn = PlannerChatTurn(
      role: 'user',
      content: msg,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    c.applyPlanner(p0.copyWith(chat: [...p0.chat, userTurn]));
    _ideationInput.clear();
    setState(() {
      _ideationStreamPreview = '';
      _ideationStreamSlot = true;
    });
    c.setPlannerAiBusy(true);
    try {
      final reply = await c.runIdeationAi(msg, (acc) {
        if (!mounted) return;
        setState(() => _ideationStreamPreview = acc);
      });
      if (!mounted) return;
      if (reply == null) {
        c.rollbackPlannerChatLastUserIfMatches(msg);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('构思已中断：画布已刷新，未写入回复')),
          );
        }
        return;
      }
      final trimmed = reply.trim();
      if (trimmed.isEmpty) {
        c.rollbackPlannerChatLastUserIfMatches(msg);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('构思未写入：模型返回为空')),
          );
        }
        return;
      }
      final p1 = c.getPlanner();
      c.applyPlanner(p1.copyWith(chat: [
        ...p1.chat,
        PlannerChatTurn(
          role: 'assistant',
          content: trimmed,
          createdAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      ]));
      setState(() => _ideationStreamPreview = '');
    } catch (e) {
      c.rollbackPlannerChatLastUserIfMatches(msg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('构思对话失败: $e')),
        );
      }
    } finally {
      c.setPlannerAiBusy(false);
      if (mounted) {
        setState(() {
          _ideationStreamSlot = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = c.getPlanner();
    final items = c.getItems();
    final gaps = computeUncoveredRanges(items: items, coverage: p.coverage);
    final busy = c.getPlannerAiBusy();
    final gapPreview = gaps.isEmpty
        ? '（当前剧情均已纳入总结覆盖范围）'
        : gaps.map((g) => '${g.startItemId} → ${g.endItemId}').join('；');

    final sheetHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Material(
          color: const Color(0xff161616),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    splashColor: Colors.white24,
                    hoverColor: Colors.white12,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                    children: [
                      ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        title: const Text(
                          '剧情构思',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          '展开后使用「剧情大纲」与「构思」',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        iconColor: Colors.white70,
                        collapsedIconColor: Colors.white70,
                        textColor: Colors.white,
                        collapsedTextColor: Colors.white,
                        backgroundColor: const Color(0xff1c1c1c),
                        collapsedBackgroundColor: const Color(0xff1c1c1c),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        children: [
                          ExpansionTile(
                            initiallyExpanded: true,
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text(
                              '剧情大纲',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            iconColor: Colors.white60,
                            collapsedIconColor: Colors.white60,
                            textColor: Colors.white,
                            collapsedTextColor: Colors.white,
                            backgroundColor: const Color(0xff202020),
                            collapsedBackgroundColor: const Color(0xff202020),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (p.outlineDirty)
                                      const Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          '大纲可能已过期（正文相对上次总结已有改动）。建议清空大纲后重新总结。',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    const Text(
                                      '已发生剧情总纲',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (p.outlineSummary.trim().isEmpty)
                                      const Text(
                                        '尚无总纲，点击下方按钮根据正文生成。',
                                        style: TextStyle(
                                            color: Colors.white38,
                                            fontSize: 12),
                                      )
                                    else
                                      SelectableText(
                                        p.outlineSummary,
                                        style: const TextStyle(
                                            color: Colors.white, height: 1.35),
                                      ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '未总结剧情段：$gapPreview',
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 12),
                                    ),
                                    const SizedBox(height: 8),
                                    if (gaps.isNotEmpty)
                                      Text(
                                        c.buildPlotHistory(
                                          items.sublist(
                                            gaps.first.startIndex,
                                            gaps.first.endIndex + 1,
                                          ),
                                        ),
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11),
                                      ),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                      onPressed: busy || p.outlineDirty
                                          ? null
                                          : _onGenerateOutline,
                                      icon: busy
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Icon(Icons.auto_awesome),
                                      label: Text(busy
                                          ? '生成中…'
                                          : (p.outlineSummary.trim().isEmpty
                                              ? '生成大纲'
                                              : '追加大纲')),
                                    ),
                                    if (_outlineStreamSlot &&
                                        _outlineStreamPreview.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: SelectableText(
                                          _outlineStreamPreview,
                                          style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12),
                                        ),
                                      ),
                                    if (_outlineError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          _outlineError!,
                                          style: const TextStyle(
                                              color: Colors.orangeAccent,
                                              fontSize: 12),
                                        ),
                                      ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: busy ? null : _confirmClearOutline,
                                      icon: const Icon(Icons.delete_sweep_outlined,
                                          color: Colors.white54, size: 18),
                                      label: const Text('清空大纲并重新开始'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          ExpansionTile(
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text(
                              '构思',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            iconColor: Colors.white60,
                            collapsedIconColor: Colors.white60,
                            textColor: Colors.white,
                            collapsedTextColor: Colors.white,
                            backgroundColor: const Color(0xff202020),
                            collapsedBackgroundColor: const Color(0xff202020),
                            shape: const Border(),
                            collapsedShape: const Border(),
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: p.chat.isEmpty || busy
                                            ? null
                                            : _confirmClearIdeationChat,
                                        child: const Text('清空构思对话'),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 240,
                                      child: ListView(
                                        padding: EdgeInsets.zero,
                                        children: [
                                          for (final m in p.chat)
                                            Align(
                                              alignment: m.role == 'user'
                                                  ? Alignment.centerRight
                                                  : Alignment.centerLeft,
                                              child: Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 8),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                constraints: BoxConstraints(
                                                  maxWidth:
                                                      MediaQuery.sizeOf(context)
                                                              .width *
                                                          0.82,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: m.role == 'user'
                                                      ? const Color(0xff2a3f5f)
                                                      : const Color(0xff2a2a2a),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: SelectableText(
                                                  m.content,
                                                  style: const TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          if (_ideationStreamSlot &&
                                              busy &&
                                              _ideationStreamPreview.isNotEmpty)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: SelectableText(
                                                '…\n$_ideationStreamPreview',
                                                style: const TextStyle(
                                                    color: Colors.white54),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: _ideationInput,
                                            minLines: 1,
                                            maxLines: 3,
                                            enabled: !busy,
                                            style: const TextStyle(
                                                color: Colors.white),
                                            decoration: const InputDecoration(
                                              hintText: '与 AI 讨论后续走向（不写正文）',
                                              hintStyle: TextStyle(
                                                  color: Colors.white30),
                                              filled: true,
                                              fillColor: Color(0xff202020),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton(
                                          onPressed:
                                              busy ? null : _sendIdeation,
                                          child: Text(busy ? '…' : '发送'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
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
