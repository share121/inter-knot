import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/video_archive_codec.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/video_archive_entry.dart';
import 'package:inter_knot/pages/video_archive_detail_page.dart';

class VideoArchivePage extends StatefulWidget {
  const VideoArchivePage({super.key});

  @override
  State<VideoArchivePage> createState() => _VideoArchivePageState();
}

class _VideoArchivePageState extends State<VideoArchivePage> {
  final Api _api = Get.find<Api>();
  final ScrollController _gridScrollController = ScrollController();
  bool _loading = true;
  String? _error;
  final List<VideoArchiveEntry> _entries = [];
  final Map<String, String> _gistPayloadTextCache = <String, String>{};
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    assert(() {
      _runMetaParserSelfCheck();
      return true;
    }());
    _load();
  }

  @override
  void dispose() {
    _gridScrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final loaded = <VideoArchiveEntry>[];
      final seenNumbers = <int>{};
      String? endCur;
      var hasNextPage = true;
      while (hasNextPage) {
        final page =
            await _api.search('category:$videoDiscussionCategoryName', endCur);
        for (final item in page.nodes) {
          if (!seenNumbers.add(item.number)) continue;
          final discussion = await item.discussion;
          if (discussion == null) continue;
          if (!isVideoDiscussion(discussion)) continue;
          loaded.add(await _parseEntry(discussion));
        }
        endCur = page.endCursor;
        hasNextPage = page.hasNextPage;
      }
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(loaded);
        _selectedIndex =
            loaded.isEmpty ? 0 : _selectedIndex.clamp(0, loaded.length - 1);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<VideoArchiveEntry> _parseEntry(DiscussionModel discussion) async {
    final tags = RegExp(r'\[([^\]]+)\]')
        .allMatches(discussion.title)
        .map((m) => (m.group(1) ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final displayTitle =
        discussion.title.replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
    try {
      final body = extractVideoBodyParts(discussion.rawBodyText);
      if (body.gistUrlError != null) {
        throw FormatException('gist 链接格式错误: ${body.gistUrlError}');
      }
      String? encodedPayload = body.encodedPayload;
      if ((encodedPayload == null || encodedPayload.isEmpty) &&
          body.gistRawUrl != null) {
        encodedPayload = await _loadEncodedPayloadFromGistRaw(body.gistRawUrl!);
      }
      if (encodedPayload == null || encodedPayload.isEmpty) {
        throw const FormatException('正文末尾缺少 {payload} 或 gist raw 链接');
      }
      final decoded = decodeVideoPayload(encodedPayload);
      return VideoArchiveEntry(
        discussion: discussion,
        displayTitle: displayTitle.isEmpty ? discussion.title : displayTitle,
        tags: tags,
        description: body.description,
        encodedPayload: encodedPayload,
        decodedPayload: decoded,
        errorMessage: null,
      );
    } catch (e) {
      return VideoArchiveEntry(
        discussion: discussion,
        displayTitle: displayTitle.isEmpty ? discussion.title : displayTitle,
        tags: tags,
        description: discussion.bodyText,
        encodedPayload: null,
        decodedPayload: null,
        errorMessage: '$e',
      );
    }
  }

  Future<String> _loadEncodedPayloadFromGistRaw(String url) async {
    final normalized = normalizeVideoPayloadGistRawUrlDetailed(url);
    final normalizedUrl = normalized.rawUrl;
    if (normalizedUrl == null) {
      throw FormatException('gist 链接格式错误: ${normalized.error ?? url}');
    }
    final cached = _gistPayloadTextCache[normalizedUrl];
    if (cached != null) return cached;
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      throw FormatException('gist raw URL 无效: $normalizedUrl');
    }
    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw FormatException('gist 内容拉取超时: $normalizedUrl');
    } catch (e) {
      throw FormatException('gist 内容拉取失败（网络异常）: $e');
    }
    if (response.statusCode != 200) {
      throw FormatException('gist 内容拉取失败 (HTTP ${response.statusCode})');
    }
    final token = extractEncodedPayloadToken(response.body);
    if (token == null || token.isEmpty) {
      throw const FormatException('gist 内容无法解析出影片 payload');
    }
    _gistPayloadTextCache[normalizedUrl] = token;
    return token;
  }

  VideoArchiveEntry? get _selectedEntry {
    if (_entries.isEmpty) return null;
    return _entries[_selectedIndex.clamp(0, _entries.length - 1)];
  }

  _ArchiveMeta _extractMeta(List<String> tags) {
    String? theme;
    String? category;
    int? level;

    const themeHints = <String>[
      '主题',
      '特别篇',
      '专栏',
      '手册',
      '纪行',
      '实录',
      '寓言',
      '番外',
      '电台',
    ];
    const categoryHints = <String>[
      '访谈',
      '动作',
      '剧情',
      '悬疑',
      '喜剧',
      '搞笑',
      '情感',
      '惊悚',
      '竞技',
      '人文',
      '探险',
      '奇幻',
      '真人秀',
      '音乐',
      '科幻',
      '冒险',
    ];

    for (final rawTag in tags) {
      final tag = rawTag.trim();

      final themeMatch =
          RegExp(r'^(?:主题|theme)\s*[:：]\s*(.+)$', caseSensitive: false)
              .firstMatch(tag);
      if (theme == null && themeMatch != null) {
        final value = (themeMatch.group(1) ?? '').trim();
        if (value.isNotEmpty) theme = value;
      }

      final categoryMatch =
          RegExp(r'^(?:分类|category|cat)\s*[:：]\s*(.+)$', caseSensitive: false)
              .firstMatch(tag);
      if (category == null && categoryMatch != null) {
        final value = (categoryMatch.group(1) ?? '').trim();
        if (value.isNotEmpty) category = value;
      }

      level ??= _parseLevelTag(tag);
    }

    if (theme == null) {
      for (final tag in tags) {
        final normalized = tag.trim().toLowerCase();
        if (themeHints.any((hint) => normalized.contains(hint.toLowerCase()))) {
          theme = tag;
          break;
        }
      }
    }
    if (category == null) {
      for (final tag in tags) {
        final normalized = tag.trim().toLowerCase();
        if (categoryHints
            .any((hint) => normalized.contains(hint.toLowerCase()))) {
          category = tag;
          break;
        }
      }
    }

    return _ArchiveMeta(theme: theme, category: category, level: level);
  }

  int? _parseLevelTag(String tag) {
    final trimmed = tag.trim();
    final match = RegExp(
      r'^(?:等级\s*[:：]?\s*([1-5])|([1-5])\s*级|l(?:v|evel)?\s*[:：]?\s*([1-5]))$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match == null) return null;
    final raw = match.group(1) ?? match.group(2) ?? match.group(3);
    return int.tryParse(raw ?? '');
  }

  void _runMetaParserSelfCheck() {
    assert(_parseLevelTag('等级3') == 3);
    assert(_parseLevelTag('等级:3') == 3);
    assert(_parseLevelTag('等级 3') == 3);
    assert(_parseLevelTag('3级') == 3);
    assert(_parseLevelTag('L4') == 4);
    assert(_parseLevelTag('LV3') == 3);
    assert(_parseLevelTag('lv:2') == 2);
    assert(_parseLevelTag('level:2') == 2);

    final meta = _extractMeta(<String>['theme:推理专栏', 'Category:动作']);
    assert(meta.theme == '推理专栏');
    assert(meta.category == '动作');

    final empty = _extractMeta(const <String>[]);
    assert(empty.theme == null);
    assert(empty.category == null);
    assert(empty.level == null);
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntry = _selectedEntry;
    final selectedMeta = selectedEntry == null
        ? const _ArchiveMeta()
        : _extractMeta(selectedEntry.tags);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 92,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: Get.back,
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFF3333), width: 2),
                          color: const Color(0x66120000),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFFFF3333),
                          size: 20,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white70),
                      tooltip: '刷新',
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _DiagonalStripeBackgroundPainter(),
                      ),
                    ),
                  ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SelectableText(
                          _error!,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    )
                  else if (_entries.isEmpty)
                    const Center(
                      child: Text('暂无可展示的录像带',
                          style: TextStyle(color: Colors.white70)),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 900;
                        final infoPanelWidth =
                            (constraints.maxWidth * 0.34).clamp(360.0, 480.0);
                        final panel = _ArchiveInfoPanel(
                          entry: selectedEntry!,
                          meta: selectedMeta,
                          compact: isCompact,
                        );
                        final grid = _ArchiveGrid(
                          entries: _entries,
                          selectedIndex: _selectedIndex,
                          compact: isCompact,
                          scrollController: _gridScrollController,
                          onItemTap: (index) {
                            setState(() => _selectedIndex = index);
                            final entry = _entries[index];
                            showGeneralDialog<void>(
                              context: context,
                              barrierDismissible: true,
                              barrierLabel: 'Close'.tr,
                              pageBuilder: (ctx, animation, secondaryAnimation) {
                                return VideoArchiveDetailPage(entry: entry);
                              },
                              transitionDuration: 300.ms,
                              transitionBuilder:
                                  (ctx, animation, secondaryAnimation, child) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.1, 0),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: animation,
                                        curve: Curves.ease,
                                      ),
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                            );
                          },
                        );
                        if (isCompact) {
                          return Column(
                            children: [
                              panel,
                              Expanded(child: grid),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            SizedBox(width: infoPanelWidth, child: panel),
                            Expanded(child: grid),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveInfoPanel extends StatelessWidget {
  const _ArchiveInfoPanel({
    required this.entry,
    required this.meta,
    required this.compact,
  });

  final VideoArchiveEntry entry;
  final _ArchiveMeta meta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final desc =
        entry.description.trim().isEmpty ? '暂无简介' : entry.description.trim();
    return Padding(
      padding:
          EdgeInsets.fromLTRB(compact ? 16 : 28, 10, compact ? 16 : 24, 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xAA0A0A0A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              bottom: -40,
              child: Icon(
                Icons.blur_circular_rounded,
                size: compact ? 140 : 200,
                color: const Color(0x1FFFFFFF),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Text(
                    entry.displayTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta.theme != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      meta.theme!,
                      style: const TextStyle(
                        color: Color(0xFFB6B6B6),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (meta.category != null || meta.level != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (meta.category != null)
                          Text(
                            meta.category!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        if (meta.category != null && meta.level != null)
                          const SizedBox(width: 16),
                        if (meta.level != null)
                          Text(
                            '等级${meta.level}',
                            style: const TextStyle(
                              color: Color(0xFFD7FF00),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      height: 1.45,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveGrid extends StatelessWidget {
  const _ArchiveGrid({
    required this.entries,
    required this.selectedIndex,
    required this.compact,
    required this.scrollController,
    required this.onItemTap,
  });

  final List<VideoArchiveEntry> entries;
  final int selectedIndex;
  final bool compact;
  final ScrollController scrollController;
  final ValueChanged<int> onItemTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(compact ? 16 : 8, 14, compact ? 16 : 24, 18),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: compact ? 220 : 210,
        mainAxisExtent: compact ? 250 : 238,
        mainAxisSpacing: compact ? 16 : 20,
        crossAxisSpacing: compact ? 14 : 18,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _ArchiveCard(
          entry: entry,
          selected: index == selectedIndex,
          onTap: () => onItemTap(index),
        );
      },
    );
  }
}

class _ArchiveCard extends StatefulWidget {
  const _ArchiveCard({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final VideoArchiveEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ArchiveCard> createState() => _ArchiveCardState();
}

class _ArchiveCardState extends State<_ArchiveCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _hovered ? 1.02 : 1,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.selected
                    ? const Color(0xFFD7FF00)
                    : Colors.transparent,
                width: 2,
              ),
              color: _hovered ? const Color(0x22000000) : Colors.transparent,
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    widget.entry.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _VhsCaseFrame(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.entry.discussion.cover != null &&
                              widget.entry.discussion.cover!.isNotEmpty &&
                              !widget.entry.discussion.coverIsIframe
                          ? Image.network(
                              widget.entry.discussion.cover!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, _, __) => Assets
                                  .images.defaultCover
                                  .image(fit: BoxFit.cover),
                            )
                          : Assets.images.defaultCover.image(
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VhsCaseFrame extends StatelessWidget {
  const _VhsCaseFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF222222), Color(0xFF101010)],
        ),
        border: Border.all(color: const Color(0xFF4A4A4A)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 22,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(9)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2C2C2C), Color(0xFF161616)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 5,
            top: 12,
            bottom: 12,
            width: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 7, 8, 7),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalStripeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFF090909);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final stripePaint = Paint()
      ..color = const Color(0x17FFFFFF)
      ..strokeWidth = 1.1;
    const spacing = 8.0;
    for (double x = -size.height; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        stripePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArchiveMeta {
  const _ArchiveMeta({this.theme, this.category, this.level});

  final String? theme;
  final String? category;
  final int? level;
}
