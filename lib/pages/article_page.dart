import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
// import 'package:get/get.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

import '../data.dart';
import '../main.dart';
import '../widget/github_button.dart';
import '../widget/window_buttons.dart';

class ArticlePage extends StatefulWidget {
  const ArticlePage({super.key, required this.article, required this.heroKey});

  final Article article;
  final UniqueKey heroKey;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final scrollController = ScrollController();
  final c = Get.find<Controller>();

  @override
  void initState() {
    super.initState();
    scrollController.addListener(() async {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        await widget.article.fetchComments();
        setState(() {});
      }
    });
    widget.article.fetchComments().then((e) async {
      setState(() {});
      while (scrollController.position.maxScrollExtent == 0 &&
          widget.article.hasNextPage) {
        await widget.article.fetchComments();
        setState(() {});
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
    return Scaffold(
      appBar: AppBar(
        title: DragToMoveArea(child: Text(widget.article.title)),
        flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in Browser'.tr,
            onPressed: () => launchUrlString(widget.article.url),
          ),
          const SizedBox(width: 4),
          const GithubButton(),
          const SizedBox(width: 8),
          if (isDesktop) const WindowButtons(),
        ],
        elevation: 4,
      ),
      body: LayoutBuilder(builder: (context, con) {
        return SizedBox.expand(
          child: Flex(
            direction: Axis.horizontal,
            children: [
              Expanded(
                flex: 4,
                child: Hero(
                  tag: widget.heroKey,
                  child: widget.article.cover == null
                      ? Assets.images.defaultCover.image()
                      : Image.network(
                          widget.article.cover!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            final progress =
                                loadingProgress.cumulativeBytesLoaded;
                            return SizedBox(
                              height: 100,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes
                                      .use((e) => progress / e),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Assets.images.defaultCover.image(),
                        ),
                ),
              ),
              Expanded(
                flex: 5,
                child: SizedBox.expand(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 32,
                      ),
                      child: Flex(
                        direction: Axis.vertical,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.article.title,
                                      style: Get.textTheme.headlineMedium,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.comment_outlined,
                                            size: 18),
                                        const SizedBox(width: 4),
                                        Text(widget.article.commentsCount
                                            .toString()),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ClipOval(
                                    child: Image.network(
                                      widget.article.author.avatar,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error,
                                              stackTrace) =>
                                          Assets.images.profilePhoto.image(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.article.author.name),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (widget.article.author.level !=
                                              null)
                                            Chip(
                                              label: Text(
                                                  'Lv${widget.article.author.level!}'),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(50),
                                              ),
                                              padding: const EdgeInsets.all(0),
                                              labelStyle:
                                                  Get.textTheme.labelSmall,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Published on: '.tr +
                                  widget.article.createdAt
                                      .toLocal()
                                      .toString()),
                              if (widget.article.lastEditedAt != null)
                                Text('Last edited on: '.tr +
                                    widget.article.lastEditedAt!
                                        .toLocal()
                                        .toString()),
                              const SizedBox(height: 16),
                              HtmlWidget(
                                widget.article.bodyHTML,
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              for (final (index, comment)
                                  in widget.article.comments.indexed)
                                ListTile(
                                  titleAlignment: ListTileTitleAlignment.top,
                                  leading: ClipOval(
                                    child: Image.network(
                                      comment.author.avatar,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error,
                                              stackTrace) =>
                                          Assets.images.profilePhoto.image(),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(comment.author.name),
                                      if (comment.author.level != null) ...[
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(
                                              'Lv${comment.author.level!}'),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(50),
                                          ),
                                          padding: const EdgeInsets.all(0),
                                          labelStyle: Get.textTheme.labelSmall,
                                        ),
                                      ],
                                      if (comment.author.name ==
                                          widget.article.author.name) ...[
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text('landlord'.tr),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(50),
                                          ),
                                          padding: const EdgeInsets.all(0),
                                          labelStyle: Get.textTheme.labelSmall,
                                        ),
                                      ],
                                      if (comment.author.name == owner) ...[
                                        const SizedBox(width: 8),
                                        Chip(
                                          label:
                                              Text('Founder of Inter-Knot'.tr),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(50),
                                          ),
                                          padding: const EdgeInsets.all(0),
                                          labelStyle: Get.textTheme.labelSmall,
                                        ),
                                      ],
                                      if (collaborators
                                          .contains(comment.author.name)) ...[
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(
                                              'Inter-Knot collaborator'.tr),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(50),
                                          ),
                                          padding: const EdgeInsets.all(0),
                                          labelStyle: Get.textTheme.labelSmall,
                                        ),
                                      ],
                                      const Spacer(),
                                      const SizedBox(width: 8),
                                      Chip(
                                        label: Text('F${index + 1}'),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(50),
                                        ),
                                        padding: const EdgeInsets.all(0),
                                        labelStyle: Get.textTheme.labelSmall,
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Published on: '.tr +
                                          comment.createdAt
                                              .toLocal()
                                              .toString()),
                                      if (comment.lastEditedAt != null)
                                        Text('Last edited on: '.tr +
                                            comment.lastEditedAt!
                                                .toLocal()
                                                .toString()),
                                      const SizedBox(height: 8),
                                      HtmlWidget(
                                        comment.bodyHTML,
                                        textStyle:
                                            const TextStyle(fontSize: 16),
                                      ),
                                      for (final (index, reply)
                                          in comment.replies.indexed)
                                        ListTile(
                                          titleAlignment:
                                              ListTileTitleAlignment.top,
                                          leading: ClipOval(
                                            child: Image.network(
                                              reply.author.avatar,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Assets.images.profilePhoto
                                                      .image(),
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Text(reply.author.name),
                                              if (reply.author.level !=
                                                  null) ...[
                                                const SizedBox(width: 8),
                                                Chip(
                                                  label: Text(
                                                      'Lv${reply.author.level!}'),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(0),
                                                  labelStyle:
                                                      Get.textTheme.labelSmall,
                                                ),
                                              ],
                                              if (reply.author.name ==
                                                  widget
                                                      .article.author.name) ...[
                                                const SizedBox(width: 8),
                                                Chip(
                                                  label: Text('landlord'.tr),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(0),
                                                  labelStyle:
                                                      Get.textTheme.labelSmall,
                                                ),
                                              ],
                                              if (reply.author.name ==
                                                  owner) ...[
                                                const SizedBox(width: 8),
                                                Chip(
                                                  label: Text(
                                                      'Founder of Inter-Knot'
                                                          .tr),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(0),
                                                  labelStyle:
                                                      Get.textTheme.labelSmall,
                                                ),
                                              ],
                                              if (collaborators.contains(
                                                  reply.author.name)) ...[
                                                const SizedBox(width: 8),
                                                Chip(
                                                  label: Text(
                                                      'Inter-Knot collaborator'
                                                          .tr),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(0),
                                                  labelStyle:
                                                      Get.textTheme.labelSmall,
                                                ),
                                              ],
                                              const Spacer(),
                                              const SizedBox(width: 8),
                                              Chip(
                                                label: Text('F${index + 1}'),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(50),
                                                ),
                                                padding:
                                                    const EdgeInsets.all(0),
                                                labelStyle:
                                                    Get.textTheme.labelSmall,
                                              ),
                                            ],
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Published on: '.tr +
                                                  reply.createdAt
                                                      .toLocal()
                                                      .toString()),
                                              if (reply.lastEditedAt != null)
                                                Text('Last edited on: '.tr +
                                                    reply.lastEditedAt!
                                                        .toLocal()
                                                        .toString()),
                                              const SizedBox(height: 8),
                                              HtmlWidget(
                                                reply.bodyHTML,
                                                textStyle: const TextStyle(
                                                    fontSize: 16),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Back to Top'.tr,
        onPressed: () => scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        ),
        child: const Icon(Icons.arrow_upward),
      ),
    );
  }
}
