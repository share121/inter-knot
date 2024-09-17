import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../common.dart';
import '../interface.dart';
import '../main.dart';
import '../widget/avatar.dart';
import '../widget/click_region.dart';
import '../widget/comment_count.dart';
import '../gen/assets.gen.dart';
import '../data.dart';
import '../widget/comments.dart';
import '../widget/my_chip.dart';
import '../widget/report_discussion_comment.dart';

class DiscussionPage extends StatefulWidget {
  const DiscussionPage({
    super.key,
    required this.discussion,
    required this.hData,
  });

  final Discussion discussion;
  final HData hData;

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends State<DiscussionPage> {
  final scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
    scrollController.dispose();
    super.dispose();
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: Assets.images.discussionPageBgPoint
                                  .provider(),
                              repeat: ImageRepeat.repeat,
                            ),
                            gradient: const LinearGradient(
                              colors: [Color(0xff161616), Color(0xff080808)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomLeft,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xff2D2D2D),
                                    width: 3,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(maxRadius),
                                ),
                                child: Avatar(widget.discussion.author.avatar),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Obx(() => Text(
                                          widget.discussion.author.name(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xff808080),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          CommentCount(
                                            discussion: widget.discussion,
                                            color: const Color(0xff808080),
                                          ),
                                          if (widget.discussion.author.login ==
                                              owner)
                                            MyChip('Founder of Inter-Knot'.tr),
                                          if (collaborators.contains(
                                              widget.discussion.author.login))
                                            MyChip(
                                                'Inter-Knot collaborator'.tr),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ClickRegion(
                                child: Assets.images.closeBtn.image(),
                                onTap: () => Get.back(),
                              )
                            ],
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(builder: (context, con) {
                            if (con.maxWidth < 600) {
                              return ListView(
                                controller: scrollController,
                                children: [
                                  Container(
                                    constraints:
                                        const BoxConstraints(maxHeight: 500),
                                    width: double.infinity,
                                    child: Cover(discussion: widget.discussion),
                                  ),
                                  RightBox(
                                    discussion: widget.discussion,
                                    hData: widget.hData,
                                  ),
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
                                        bottom: 16),
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
                                      child:
                                          Cover(discussion: widget.discussion),
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
                                        bottom: 16),
                                    height: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff070707),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: SingleChildScrollView(
                                      controller: scrollController,
                                      child: RightBox(
                                        discussion: widget.discussion,
                                        hData: widget.hData,
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            );
                          }),
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

class RightBox extends StatelessWidget {
  const RightBox({super.key, required this.discussion, required this.hData});

  final Discussion discussion;
  final HData hData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                discussion.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text('Published on: '.tr +
                  discussion.createdAt.toLocal().toString()),
              if (discussion.lastEditedAt != null)
                Text('Last edited on: '.tr +
                    discussion.lastEditedAt!.toLocal().toString()),
              const SizedBox(height: 16),
              SelectionArea(
                child: HtmlWidget(
                  discussion.bodyHTML,
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xff222222),
                    borderRadius: BorderRadius.circular(maxRadius),
                    border:
                        Border.all(color: const Color(0xff2D2D2D), width: 4),
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
                      border:
                          Border.all(color: const Color(0xff2D2D2D), width: 4),
                    ),
                    child: ClickRegion(
                      onTap: () {
                        Future.delayed(3.s).then((_) => launchUrlString(
                            'https://github.com/share121/inter-knot/discussions/$reportDiscussionNumber#new_comment_form'));
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
                final isLiked = c.bookmarks
                    .map((e) => e.number)
                    .contains(discussion.number);
                return Tooltip(
                  message: isLiked ? 'Dislike'.tr : 'Like'.tr,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xff222222),
                      borderRadius: BorderRadius.circular(maxRadius),
                      border:
                          Border.all(color: const Color(0xff2D2D2D), width: 4),
                    ),
                    child: ClickRegion(
                      onTap: () {
                        if (isLiked) {
                          c.bookmarks.removeWhere(
                              (e) => e.number == discussion.number);
                        } else {
                          c.bookmarks({hData, ...c.bookmarks});
                        }
                      },
                      child: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_outline),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          if (discussion.number == reportDiscussionNumber)
            const ReportDiscussionComment()
          else
            Comments(discussion: discussion),
        ],
      ),
    );
  }
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.discussion});

  final Discussion discussion;

  @override
  Widget build(BuildContext context) {
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
