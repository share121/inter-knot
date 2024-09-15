import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../common.dart';
import '../gen/assets.gen.dart';
import '../interface.dart';
import 'avatar.dart';
import 'comment_count.dart';

class DiscussionCard extends StatefulWidget {
  const DiscussionCard(
      {super.key, this.onTap, required this.discussion, required this.isPin});

  final Discussion discussion;
  final bool isPin;
  final void Function()? onTap;

  @override
  State<DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<DiscussionCard>
    with AutomaticKeepAliveClientMixin {
  var elevation = 1.0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: elevation,
      color: const Color(0xff222222),
      child: Obx(() {
        if (!c.canVisit(widget.discussion, widget.isPin)) {
          return AspectRatio(
            aspectRatio: 5 / 6,
            child: InkWell(
              onTap: () => launchUrlString(widget.discussion.url),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('This discussion is suspected of violating regulations'
                        .tr),
                    Text('This discussion was reported by @count people'
                        .trParams({
                      'count':
                          c.report[widget.discussion.number]!.length.toString(),
                    })),
                  ],
                ),
              ),
            ),
          );
        }
        return InkWell(
          onTap: () => widget.onTap?.call(),
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
                    child: Cover(discussion: widget.discussion),
                  ),
                  Positioned(
                    top: 8,
                    left: 12,
                    child: CommentCount(
                      discussion: widget.discussion,
                      color: Colors.white,
                    ),
                  ),
                  if (widget.isPin)
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
                        child: Avatar(
                          widget.discussion.author.avatar,
                          size: 50,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 54),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              widget.discussion.author.login,
                              style: const TextStyle(
                                color: Color(0xff626262),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
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
                  widget.discussion.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              if (widget.discussion.rawBodyText.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    widget.discussion.bodyText,
                    style: const TextStyle(color: Color(0xffB3B3B1)),
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

  @override
  bool get wantKeepAlive => true;
}

class Cover extends StatelessWidget {
  const Cover({super.key, required this.discussion});

  final Discussion discussion;

  @override
  Widget build(BuildContext context) {
    return discussion.cover == null
        ? Assets.images.defaultCover.image(
            width: double.infinity,
            fit: BoxFit.cover,
          )
        : Image.network(
            discussion.cover!,
            width: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, p) {
              if (p == null) return child;
              final total = p.expectedTotalBytes;
              final cur = p.cumulativeBytesLoaded;
              return AspectRatio(
                aspectRatio: 643 / 408,
                child: Center(
                  child: CircularProgressIndicator(
                    value: total == null || cur == 0 ? null : cur / total,
                  ),
                ),
              );
            },
            errorBuilder: (context, e, s) => Assets.images.defaultCover.image(
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
  }
}
