import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../common.dart';
import '../gen/assets.gen.dart';
import '../interface.dart';
import 'avatar.dart';
import 'comment_count.dart';

class DiscussionCard extends StatefulWidget {
  const DiscussionCard({super.key, this.onTap, required this.article});

  final Article article;
  final void Function(Object heroKey)? onTap;

  @override
  State<DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<DiscussionCard> {
  var elevation = 1.0;
  final heroKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: elevation,
      child: Obx(() {
        if (!c.canVisit(widget.article)) {
          return AspectRatio(
            aspectRatio: 5 / 6,
            child: InkWell(
              onTap: () => launchUrlString(widget.article.url),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('This article is suspected of violating regulations'
                        .tr),
                    Text('This article was reported by @count people'.trParams({
                      'count':
                          c.report[widget.article.number]!.length.toString(),
                    })),
                  ],
                ),
              ),
            ),
          );
        }
        return InkWell(
          onTap: () => widget.onTap?.call(heroKey),
          onTapDown: (_) => setState(() => elevation = 4),
          onTapUp: (_) => setState(() => elevation = 1),
          onTapCancel: () => setState(() => elevation = 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 600, minHeight: 100),
                    child: Cover(heroKey: heroKey, article: widget.article),
                  ),
                  Positioned(
                    top: 8,
                    left: 12,
                    child: CommentCount(
                      article: widget.article,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.article.isPin)
                    Positioned(
                      top: 8,
                      right: 12,
                      child: Text(
                        'Top'.tr,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        top: -26,
                        child: Avatar(widget.article.author.avatar),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 54),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              widget.article.author.login,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Divider(height: 1),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.article.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              if (widget.article.rawBodyText.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.article.bodyText,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      }),
    );
  }
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.heroKey, required this.article});

  final Object heroKey;
  final Article article;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroKey,
      child: article.cover == null
          ? Assets.images.defaultCover.image(
              width: double.infinity,
              fit: BoxFit.cover,
            )
          : CachedNetworkImage(
              imageUrl: article.cover!,
              width: double.infinity,
              fit: BoxFit.cover,
              progressIndicatorBuilder: (context, url, downloadProgress) {
                return AspectRatio(
                  aspectRatio: 643 / 408,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: downloadProgress.progress,
                    ),
                  ),
                );
              },
              errorWidget: (context, url, error) =>
                  Assets.images.defaultCover.image(
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}
