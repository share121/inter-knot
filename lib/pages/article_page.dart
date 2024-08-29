import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/common.dart';
import 'package:inter_knot/widget/avatar.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

import '../widget/comment_count.dart';
import '../gen/assets.gen.dart';
import '../data.dart';
import '../widget/window_buttons.dart';

class ArticlePage extends StatefulWidget {
  const ArticlePage({super.key, required this.article, required this.heroKey});

  final Article article;
  final Object heroKey;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final scrollController = ScrollController();
  final c = Get.find<Controller>();

  @override
  void initState() {
    super.initState();
    Future(() {
      c.history({widget.article, ...c.history});
    });
    scrollController.addListener(() {
      final maxScroll = scrollController.position.maxScrollExtent;
      final currentScroll = scrollController.position.pixels;
      if (maxScroll - currentScroll < 200 && widget.article.hasNextPage()) {
        widget.article.fetchComments();
      }
    });
    widget.article.fetchComments().then((e) async {
      try {
        while (scrollController.position.maxScrollExtent == 0 &&
            widget.article.hasNextPage()) {
          await widget.article.fetchComments();
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
          const SizedBox(width: 8),
          if (isDesktop) const WindowButtons(),
        ],
        elevation: 4,
      ),
      body: LayoutBuilder(builder: (context, con) {
        if (con.maxWidth < 800) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                Container(
                  constraints: const BoxConstraints(maxHeight: 600),
                  width: double.infinity,
                  child:
                      Cover(heroKey: widget.heroKey, article: widget.article),
                ),
                RightBox(article: widget.article),
              ],
            ),
          );
        }
        return SizedBox.expand(
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Cover(heroKey: widget.heroKey, article: widget.article),
              ),
              Expanded(
                flex: 5,
                child: SizedBox.expand(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: RightBox(article: widget.article),
                  ),
                ),
              )
            ],
          ),
        );
      }),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: null,
            tooltip: 'Back to Top'.tr,
            onPressed: () => scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            ),
            child: const Icon(Icons.arrow_upward),
          ),
          if (canReport(widget.article)) ...[
            const SizedBox(height: 16),
            FloatingActionButton(
              heroTag: null,
              onPressed: () {
                Future.delayed(3.s).then((_) => launchUrlString(
                    'https://github.com/share121/inter-knot/discussions/1685#new_comment_form'));
                copyText(
                  '违规文章：#${widget.article.number}\n举报原因：',
                  title: 'Report template copied'.tr,
                  msg: 'Jump to the report page after 3 seconds'.tr,
                );
              },
              tooltip: 'Report'.tr,
              child: const Icon(Icons.report),
            ),
          ],
          const SizedBox(height: 16),
          Obx(() {
            final isLiked = c.bookmarks
                .map((e) => e.number)
                .contains(widget.article.number);
            return FloatingActionButton(
              heroTag: null,
              onPressed: () {
                if (isLiked) {
                  c.bookmarks
                      .removeWhere((e) => e.number == widget.article.number);
                } else {
                  c.bookmarks({widget.article, ...c.bookmarks});
                }
              },
              tooltip: isLiked ? 'Unlike'.tr : 'Like'.tr,
              child: Icon(isLiked ? Icons.favorite : Icons.favorite_outline),
            );
          }),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: null,
            onPressed: () =>
                launchUrlString('${widget.article.url}#new_comment_form'),
            tooltip: 'Write a review'.tr,
            child: const Icon(Icons.add_comment),
          ),
        ],
      ),
    );
  }
}

class RightBox extends StatelessWidget {
  const RightBox({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 32,
      ),
      child: Column(
        children: [
          MainArticle(article: article),
          const SizedBox(height: 16),
          const Divider(),
          if (article.number == reportDiscussionNumber)
            const ReportArticleComment()
          else
            Comments(article: article),
        ],
      ),
    );
  }
}

class ReportArticleComment extends StatelessWidget {
  const ReportArticleComment({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        children: [
          for (final MapEntry(:key, :value) in c.report.entries) ...[
            ListTile(
              contentPadding: const EdgeInsets.all(0),
              title: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Articles that have been reported: '.tr),
                  TextSpan(
                    text: '#$key',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => launchUrlString(
                          'https://github.com/share121/inter-knot/discussions/$key'),
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: Theme.of(context).colorScheme.primary,
                      decorationColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const TextSpan(text: '\n'),
                  TextSpan(
                    text: 'A total of @count reports'
                        .trParams({'count': value.length.toString()}),
                  ),
                ]),
              ),
              subtitle: Column(
                children: [
                  for (final (index, comment) in value.indexed)
                    ListTile(
                      minVerticalPadding: 0,
                      title: InkWell(
                        onTap: () => launchUrlString(comment.url),
                        child: Text(comment.login),
                      ),
                      subtitle: Column(
                        children: [
                          SelectionArea(
                            child: HtmlWidget(comment.bodyHTML),
                          ),
                          if (index != value.length - 1) const Divider(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
          ]
        ],
      );
    });
  }
}

class MainArticle extends StatelessWidget {
  const MainArticle({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                article.title,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CommentCount(article: article),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: const EdgeInsets.all(0),
          horizontalTitleGap: 8,
          minVerticalPadding: 0,
          onTap: () => launchUrlString(article.author.url),
          leading: Avatar(article.author.avatar),
          title: Obx(() => Text(
                article.author.name(),
                style: Theme.of(context).textTheme.titleMedium,
              )),
          subtitle: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Obx(() => MyChip('Lv${article.author.level()}')),
                if (article.author.login == owner)
                  MyChip('Founder of Inter-Knot'.tr),
                if (collaborators.contains(article.author.login))
                  MyChip('Inter-Knot collaborator'.tr),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Published on: '.tr + article.createdAt.toLocal().toString()),
        if (article.lastEditedAt != null)
          Text('Last edited on: '.tr +
              article.lastEditedAt!.toLocal().toString()),
        const SizedBox(height: 16),
        SelectionArea(
          child: HtmlWidget(
            article.bodyHTML,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}

class Comments extends StatelessWidget {
  const Comments({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return Column(
        children: [
          for (final (index, comment) in article.comments.indexed)
            ListTile(
              titleAlignment: ListTileTitleAlignment.top,
              contentPadding: const EdgeInsets.all(0),
              horizontalTitleGap: 8,
              minVerticalPadding: 0,
              leading: ClipOval(
                child: InkWell(
                  borderRadius: BorderRadius.circular(50),
                  onTap: () => launchUrlString(comment.author.url),
                  child: Avatar(comment.author.avatar),
                ),
              ),
              title: Row(
                children: [
                  InkWell(
                    onTap: () => launchUrlString(comment.author.url),
                    child: Obx(() => Text(comment.author.name())),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Obx(() => MyChip('Lv${comment.author.level()}')),
                          if (comment.author.login == article.author.login)
                            MyChip('landlord'.tr),
                          if (comment.author.login == owner)
                            MyChip('Founder of Inter-Knot'.tr),
                          if (collaborators.contains(comment.author.login))
                            MyChip('Inter-Knot collaborator'.tr),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              trailing: MyChip('F${index + 1}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Published on: '.tr +
                      comment.createdAt.toLocal().toString()),
                  if (comment.lastEditedAt != null)
                    Text('Last edited on: '.tr +
                        comment.lastEditedAt!.toLocal().toString()),
                  const SizedBox(height: 8),
                  SelectionArea(
                    child: HtmlWidget(
                      comment.bodyHTML,
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const Divider(),
                  Replies(comment: comment, article: article),
                ],
              ),
            ),
          Obx(() {
            if (article.hasNextPage.isTrue) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            } else {
              return Text('No more comments'.tr);
            }
          })
        ],
      );
    });
  }
}

class Replies extends StatelessWidget {
  const Replies({super.key, required this.comment, required this.article});

  final Comment comment;
  final Article article;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final reply in comment.replies)
          ListTile(
            titleAlignment: ListTileTitleAlignment.top,
            contentPadding: const EdgeInsets.all(0),
            horizontalTitleGap: 8,
            minVerticalPadding: 0,
            leading: MediaQuery.of(context).size.width > 400
                ? ClipOval(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: () => launchUrlString(reply.author.url),
                      child: Avatar(reply.author.avatar),
                    ),
                  )
                : null,
            title: Row(
              children: [
                InkWell(
                  onTap: () => launchUrlString(reply.author.url),
                  child: Obx(() => Text(reply.author.name())),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Obx(() => MyChip('Lv${reply.author.level()}')),
                        if (reply.author.login == article.author.login)
                          MyChip('landlord'.tr),
                        if (reply.author.login == comment.author.login)
                          MyChip('layer master'.tr),
                        if (reply.author.login == owner)
                          MyChip('Founder of Inter-Knot'.tr),
                        if (collaborators.contains(reply.author.login))
                          MyChip('Inter-Knot collaborator'.tr),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Published on: '.tr + reply.createdAt.toLocal().toString()),
                if (reply.lastEditedAt != null)
                  Text('Last edited on: '.tr +
                      reply.lastEditedAt!.toLocal().toString()),
                const SizedBox(height: 8),
                SelectionArea(
                  child: HtmlWidget(
                    reply.bodyHTML,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const Divider(),
              ],
            ),
          ),
      ],
    );
  }
}

class MyChip extends StatelessWidget {
  const MyChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(text, style: const TextStyle(fontSize: 10)),
      ),
    );
  }
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.article, required this.heroKey});

  final Article article;
  final Object heroKey;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroKey,
      child: article.cover == null
          ? Assets.images.defaultCover.image(fit: BoxFit.contain)
          : MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => launchUrlString(article.cover!),
                child: CachedNetworkImage(
                  imageUrl: article.cover!,
                  fit: BoxFit.contain,
                  progressIndicatorBuilder: (context, url, downloadProgress) {
                    return Center(
                      child: CircularProgressIndicator(
                        value: downloadProgress.progress,
                      ),
                    );
                  },
                  errorWidget: (context, url, error) =>
                      Assets.images.defaultCover.image(fit: BoxFit.contain),
                ),
              ),
            ),
    );
  }
}
