import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/discussion_badge.dart';
import 'package:inter_knot/components/discussion_labels.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/ai_review_helper.dart';
import 'package:inter_knot/helpers/discussion_actions.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/video_archive_entry.dart';
import 'package:inter_knot/pages/discussion_page.dart';
import 'package:inter_knot/pages/video_player_page.dart';
import 'package:url_launcher/url_launcher_string.dart';

class VideoArchiveDetailPage extends StatefulWidget {
  const VideoArchiveDetailPage({super.key, required this.entry});

  final VideoArchiveEntry entry;

  @override
  State<VideoArchiveDetailPage> createState() => _VideoArchiveDetailPageState();
}

class _VideoArchiveDetailPageState extends State<VideoArchiveDetailPage>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final Controller _c = Get.find<Controller>();
  late final HDataModel _hData;
  bool _commentsRefreshBusy = false;
  bool _isOpeningPlayer = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAuthorContributions();
    final d = widget.entry.discussion;
    _hData = HDataModel(
      number: d.number,
      updatedAt: d.lastEditedAt ?? d.createdAt,
      isPinned: false,
      labels: d.labels,
      categoryId: d.categoryId,
      categoryName: d.categoryName,
    );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _refreshCommentsLocked(
          'VideoArchiveDetail open',
          showSnackOnManual: false,
        ),
      );
    });
  }

  Future<void> _refreshCommentsLocked(
    String logPrefix, {
    required bool showSnackOnManual,
  }) async {
    if (_commentsRefreshBusy) return;
    _commentsRefreshBusy = true;
    if (mounted) setState(() {});
    final messenger = ScaffoldMessenger.maybeOf(context);
    final d = widget.entry.discussion;
    try {
      await d.refreshComments();
      if (!mounted) return;
      try {
        while (mounted &&
            _scrollController.hasClients &&
            _scrollController.position.maxScrollExtent == 0 &&
            d.hasNextPage()) {
          await d.fetchComments();
        }
      } catch (e, s) {
        logger.e('Failed to get scroll position', error: e, stackTrace: s);
      }
      if (showSnackOnManual && messenger != null && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('评论已刷新')),
        );
      }
    } catch (e, s) {
      logger.w(
        '$logPrefix: refreshComments failed',
        error: e,
        stackTrace: s,
      );
      if (showSnackOnManual && messenger != null && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('评论刷新失败：$e')),
        );
      }
    } finally {
      _commentsRefreshBusy = false;
      if (mounted) {
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _commentsRefreshBusy) return;
          _fetchMoreIfScrollNearBottom();
        });
      }
    }
  }

  void _fetchMoreIfScrollNearBottom() {
    if (_commentsRefreshBusy) return;
    if (!_scrollController.hasClients) return;
    final d = widget.entry.discussion;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200 && d.hasNextPage()) {
      d.fetchComments();
    }
  }

  Future<void> _refreshAuthorContributions() async {
    final author = widget.entry.discussion.author;
    if (author.type != 'User') return;
    try {
      final total = await _c.getUserContributions(author.login);
      if (!mounted) return;
      setState(() {
        author.contributions = total;
        author.level = total ~/ 100;
      });
    } catch (e, s) {
      logger.w('Failed to load author contributions', error: e, stackTrace: s);
    }
  }

  void _onScroll() {
    if (_commentsRefreshBusy) return;
    _fetchMoreIfScrollNearBottom();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        _refreshCommentsLocked(
          'VideoArchiveDetail resume',
          showSnackOnManual: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildCommentRefreshToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Text(
            '评论',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_commentsRefreshBusy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade300,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => unawaited(
                _refreshCommentsLocked(
                  'VideoArchiveDetail manual',
                  showSnackOnManual: true,
                ),
              ),
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('刷新评论'),
            ),
        ],
      ),
    );
  }

  Future<void> _startPlay(BuildContext context) async {
    if (_isOpeningPlayer) return;
    final entry = widget.entry;
    if (!entry.isValid) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('数据格式错误'),
          content: SelectableText(entry.errorMessage ?? '未知错误'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _isOpeningPlayer = true);
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(builder: (_) => VideoPlayerPage(entry: entry)),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningPlayer = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final entry = widget.entry;

    return SafeArea(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: screenW < 800 ? 1 : 0.8,
            heightFactor: screenW < 800 ? 1 : 0.9,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color.fromARGB(59, 255, 255, 255),
                borderRadius: screenW < 800
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
                  borderRadius: screenW < 800
                      ? BorderRadius.zero
                      : const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                ),
                child: ClipRRect(
                  borderRadius: screenW < 800
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
                        DiscussionHeaderBar(
                          discussion: entry.discussion,
                          onClose: () => Get.back(),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, con) {
                              if (con.maxWidth < 600) {
                                return ListView(
                                  controller: _scrollController,
                                  children: [
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxHeight: 500),
                                      width: double.infinity,
                                      child: Cover(
                                        discussion: entry.discussion,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        24,
                                        16,
                                        0,
                                      ),
                                      child: _VideoArchiveDetailContentBox(
                                        entry: entry,
                                        hData: _hData,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        16,
                                        16,
                                        0,
                                      ),
                                      child: _VideoArchiveActionRow(
                                        discussion: entry.discussion,
                                        playEnabled: !_isOpeningPlayer,
                                        onPlay: () => unawaited(_startPlay(context)),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(color: Color(0xff2D2D2D)),
                                    _buildCommentRefreshToolbar(context),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: DiscussionCommentSection(
                                        discussion: entry.discussion,
                                        hData: _hData,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                );
                              }
                              return Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 16,
                                        left: 16,
                                        right: 8,
                                        bottom: 16,
                                      ),
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xff313132),
                                          width: 4,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Cover(
                                          discussion: entry.discussion,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 5,
                                    child: Container(
                                      margin: const EdgeInsets.only(
                                        top: 16,
                                        left: 8,
                                        right: 16,
                                        bottom: 16,
                                      ),
                                      height: double.infinity,
                                      decoration: BoxDecoration(
                                        color: const Color(0xff070707),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            24,
                                            16,
                                            24,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _VideoArchiveDetailContentBox(
                                                entry: entry,
                                                hData: _hData,
                                              ),
                                              const SizedBox(height: 16),
                                              _VideoArchiveActionRow(
                                                discussion: entry.discussion,
                                                playEnabled: !_isOpeningPlayer,
                                                onPlay: () => unawaited(
                                                  _startPlay(context),
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              const Divider(
                                                color: Color(0xff2D2D2D),
                                              ),
                                              _buildCommentRefreshToolbar(
                                                context,
                                              ),
                                              DiscussionCommentSection(
                                                discussion: entry.discussion,
                                                hData: _hData,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
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

class _VideoArchiveActionRow extends StatelessWidget {
  const _VideoArchiveActionRow({
    required this.discussion,
    required this.onPlay,
    this.playEnabled = true,
  });

  final DiscussionModel discussion;
  final VoidCallback onPlay;
  final bool playEnabled;

  BoxDecoration get _btnDecoration => BoxDecoration(
        color: const Color(0xff222222),
        borderRadius: BorderRadius.circular(maxRadius),
        border: Border.all(color: const Color(0xff2D2D2D), width: 4),
      );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: _btnDecoration,
            child: ClickRegion(
              onTap: () =>
                  launchUrlString('${discussion.url}#new_comment_form'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_comment_outlined),
                  const SizedBox(width: 8),
                  Text(
                    'Write a review'.tr,
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: _btnDecoration,
            child: ClickRegion(
              onTap: playEnabled ? onPlay : () {},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_circle_outline,
                    color: playEnabled ? null : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '开始游玩',
                    style: TextStyle(
                      fontSize: 16,
                      color: playEnabled ? null : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoArchiveDetailContentBox extends StatelessWidget {
  const _VideoArchiveDetailContentBox({
    required this.entry,
    required this.hData,
  });

  final VideoArchiveEntry entry;
  final HDataModel hData;

  @override
  Widget build(BuildContext context) {
    final discussion = entry.discussion;
    final badges = <Widget>[];
    final aiReviewRating =
        discussion.aiReviewRatingFromLabels ?? hData.aiReviewRatingFromLabels;
    final aiReviewView = mapAiReviewRatingView(aiReviewRating);
    final categoryView = mapDiscussionCategory(discussion.categoryName);
    final visibleLabels = filterBusinessLabels(discussion.labels);
    if (hData.isPin) {
      badges.add(
        DiscussionBadge(
          text: 'Top'.tr,
          color: const Color(0xffD7FF00),
        ),
      );
    }
    if (aiReviewView != null) {
      badges.add(
        DiscussionBadge(
          text: aiReviewView.displayName.tr,
          color: aiReviewView.color,
        ),
      );
    }
    if (categoryView != null) {
      badges.add(
        DiscussionBadge(
          text: categoryView.displayName,
          color: categoryView.color,
        ),
      );
    }

    final bodyText = entry.description.trim().isEmpty
        ? '暂无简介'
        : entry.description.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.displayTitle,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        if (badges.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges,
          ),
          const SizedBox(height: 8),
        ],
        if (visibleLabels.isNotEmpty) ...[
          DiscussionLabels(
            labels: visibleLabels,
            fontSize: 12,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Published on: '.tr + discussion.createdAt.toLocal().toString(),
        ),
        if (discussion.lastEditedAt != null)
          Text(
            'Last edited on: '.tr +
                discussion.lastEditedAt!.toLocal().toString(),
          ),
        const SizedBox(height: 16),
        SelectionArea(
          child: Text(
            bodyText,
            style: const TextStyle(fontSize: 16, height: 1.45),
          ),
        ),
        if (discussion.poll != null) ...[
          const SizedBox(height: 16),
          _VideoArchivePollSection(poll: discussion.poll!),
        ],
      ],
    );
  }
}

Widget _videoArchivePollOption(PollOptionModel option, int totalVotes) {
  final percent = totalVotes == 0 ? 0.0 : option.totalVoteCount / totalVotes;
  final percentLabel = (percent * 100).toStringAsFixed(0);
  return Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                option.option,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            if (option.viewerHasVoted)
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xff96c264),
              ),
            const SizedBox(width: 6),
            Text(
              '${option.totalVoteCount} ($percentLabel%)',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xffB3B3B1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: const Color(0xff2D2D2D),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff96c264)),
          ),
        ),
      ],
    ),
  );
}

class _VideoArchivePollSection extends StatelessWidget {
  const _VideoArchivePollSection({required this.poll});

  final PollModel poll;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xff222222),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xff2D2D2D), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Polls'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (poll.viewerHasVoted) ...[
                const SizedBox(width: 8),
                MyChip('You voted'.tr),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll.question,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Total votes: '.tr + poll.totalVoteCount.toString(),
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xffB3B3B1),
            ),
          ),
          ...poll.options
              .map((o) => _videoArchivePollOption(o, poll.totalVoteCount)),
        ],
      ),
    );
  }
}
