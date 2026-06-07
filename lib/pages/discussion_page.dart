import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/components/comment.dart';
import 'package:inter_knot/components/comment_count.dart';
import 'package:inter_knot/components/discussion_badge.dart';
import 'package:inter_knot/components/discussion_labels.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/components/my_html_widget.dart';
import 'package:inter_knot/components/report_discussion_comment.dart';
import 'package:inter_knot/components/user_badge.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/ai_review_helper.dart';
import 'package:inter_knot/helpers/copy_text.dart';
import 'package:inter_knot/helpers/discussion_actions.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DiscussionPage extends StatefulWidget {
  const DiscussionPage({
    super.key,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

Widget _buildPollOption(PollOptionModel option, int totalVotes) {
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

Widget _buildPollSection(PollModel poll) {
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
            .map((option) => _buildPollOption(option, poll.totalVoteCount)),
      ],
    ),
  );
}

class _DiscussionPageState extends State<DiscussionPage>
    with WidgetsBindingObserver {
  final scrollController = ScrollController();
  final c = Get.find<Controller>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshAuthorContributions();
    Future(() {
      c.history({widget.hData, ...c.history});
    });
    scrollController.addListener(() {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;
      if (maxScroll - currentScroll < 200 && widget.discussion.hasNextPage()) {
        widget.discussion.fetchComments();
      }
    });
    widget.discussion.fetchComments().then((e) async {
      try {
        while (scrollController.position.maxScrollExtent == 0 &&
            widget.discussion.hasNextPage()) {
          await widget.discussion.fetchComments();
        }
      } catch (e, s) {
        logger.e('Failed to get scroll position', error: e, stackTrace: s);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshAuthorContributions() async {
    final author = widget.discussion.author;
    if (author.type != 'User') return;
    try {
      final total = await c.getUserContributions(author.login);
      if (!mounted) return;
      setState(() {
        author.contributions = total;
        author.level = total ~/ 100;
      });
    } catch (e, s) {
      logger.w('Failed to load author contributions', error: e, stackTrace: s);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && c.isLogin()) {
      widget.discussion.refreshComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
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
                          discussion: widget.discussion,
                          onClose: () => Get.back(),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, con) {
                              if (con.maxWidth < 600) {
                                return ListView(
                                  controller: scrollController,
                                  children: [
                                    Container(
                                      constraints:
                                          const BoxConstraints(maxHeight: 500),
                                      width: double.infinity,
                                      child: Cover(
                                        discussion: widget.discussion,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 24, 16, 0),
                                      child: DiscussionDetailBox(
                                        discussion: widget.discussion,
                                        hData: widget.hData,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 16, 16, 0),
                                      child: DiscussionActionButtons(
                                        discussion: widget.discussion,
                                        hData: widget.hData,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      child: DiscussionCommentSection(
                                        discussion: widget.discussion,
                                        hData: widget.hData,
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
                                          discussion: widget.discussion,
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
                                        controller: scrollController,
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 24, 16, 24),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              DiscussionDetailBox(
                                                discussion: widget.discussion,
                                                hData: widget.hData,
                                              ),
                                              const SizedBox(height: 16),
                                              DiscussionActionButtons(
                                                discussion: widget.discussion,
                                                hData: widget.hData,
                                              ),
                                              const SizedBox(height: 16),
                                              const Divider(),
                                              DiscussionCommentSection(
                                                discussion: widget.discussion,
                                                hData: widget.hData,
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

class DiscussionHeaderBar extends StatelessWidget {
  const DiscussionHeaderBar({
    super.key,
    required this.discussion,
    required this.onClose,
  });

  final DiscussionModel discussion;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: Assets.images.discussionPageBgPoint.provider(),
          repeat: ImageRepeat.repeat,
        ),
        gradient: const LinearGradient(
          colors: [Color(0xff161616), Color(0xff080808)],
          begin: Alignment.topLeft,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: UserBadge(
                      avatarUrl: discussion.author.avatar,
                      name: discussion.author.displayName,
                      contributions: discussion.author.contributions,
                      level: discussion.author.level,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Visibility(
                        visible: false,
                        child: Text(
                          '',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xff808080),
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            CommentCount(
                              discussion: discussion,
                              color: const Color(0xff808080),
                            ),
                            if (discussion.author.login == owner)
                              MyChip('Founder of Inter-Knot'.tr),
                            if (collaborators.contains(discussion.author.login))
                              MyChip('Inter-Knot collaborator'.tr),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ClickRegion(
              onTap: onClose,
              child: Assets.images.closeBtn.image(),
            ),
          ),
        ],
      ),
    );
  }
}

class DiscussionDetailBox extends StatelessWidget {
  const DiscussionDetailBox({
    super.key,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;

  @override
  Widget build(BuildContext context) {
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

    final hasIframe = RegExp(r'<\s*iframe\b', caseSensitive: false)
        .hasMatch(discussion.bodyHTML);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          discussion.title,
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
        if (hasIframe)
          MyHtmlWidget(
            html: discussion.bodyHTML,
            textStyle: const TextStyle(fontSize: 16),
            inDiscussionDetail: true,
          )
        else
          SelectionArea(
            child: MyHtmlWidget(
              html: discussion.bodyHTML,
              textStyle: const TextStyle(fontSize: 16),
              inDiscussionDetail: true,
            ),
          ),
        if (discussion.poll != null) ...[
          const SizedBox(height: 16),
          _buildPollSection(discussion.poll!),
        ],
      ],
    );
  }
}

class DiscussionActionButtons extends StatelessWidget {
  const DiscussionActionButtons({
    super.key,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xff222222),
              borderRadius: BorderRadius.circular(maxRadius),
              border: Border.all(color: const Color(0xff2D2D2D), width: 4),
            ),
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
        if (canReport(discussion, hData.isPin)) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Report'.tr,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff222222),
                borderRadius: BorderRadius.circular(maxRadius),
                border: Border.all(color: const Color(0xff2D2D2D), width: 4),
              ),
              child: ClickRegion(
                onTap: () {
                  Future.delayed(3.s).then(
                    (_) => launchUrlString(
                      discordLink,
                    ),
                  );
                  copyText(
                    '违规讨论：#${discussion.number}\n举报原因：',
                    title: 'Report template copied'.tr,
                    msg: 'Jump to the report page after 3 seconds'.tr,
                  );
                },
                child: const Icon(Icons.report_outlined),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Obx(() {
          final isLiked =
              c.bookmarks.map((e) => e.number).contains(discussion.number);
          return Tooltip(
            message: isLiked ? 'Dislike'.tr : 'Like'.tr,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xff222222),
                borderRadius: BorderRadius.circular(maxRadius),
                border: Border.all(color: const Color(0xff2D2D2D), width: 4),
              ),
              child: ClickRegion(
                onTap: () {
                  if (isLiked) {
                    c.bookmarks.removeWhere(
                      (e) => e.number == discussion.number,
                    );
                  } else {
                    c.bookmarks({hData, ...c.bookmarks});
                  }
                },
                child: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_outline,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class DiscussionCommentSection extends StatelessWidget {
  const DiscussionCommentSection({
    super.key,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;

  @override
  Widget build(BuildContext context) {
    if (discussion.number == reportDiscussionNumber) {
      return const ReportDiscussionComment();
    }
    return Comment(discussion: discussion);
  }
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.discussion});

  final DiscussionModel discussion;

  @override
  Widget build(BuildContext context) {
    if (discussion.coverIsIframe && discussion.cover != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: MyHtmlWidget(
          html: discussion.cover!,
          inDiscussionDetail: true,
        ),
      );
    }
    return discussion.cover == null
        ? Assets.images.defaultCover.image(fit: BoxFit.contain)
        : ClickRegion(
            onTap: () => launchUrlString(discussion.cover!),
            child: Image.network(
              discussion.cover!,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, p) {
                if (p == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: p.expectedTotalBytes == null
                        ? null
                        : p.cumulativeBytesLoaded / p.expectedTotalBytes!,
                  ),
                );
              },
              errorBuilder: (context, e, s) =>
                  Assets.images.defaultCover.image(fit: BoxFit.contain),
            ),
          );
  }
}
