import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/gen/assets.gen.dart';

import '../data.dart';

class DiscussionCard extends StatefulWidget {
  const DiscussionCard({
    super.key,
    this.onTap,
    required this.article,
  });

  final Article article;
  final void Function(UniqueKey heroKey)? onTap;

  @override
  State<DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<DiscussionCard>
    with AutomaticKeepAliveClientMixin {
  var elevation = 1.0;
  final heroKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: elevation,
      child: InkWell(
        onTap: () => widget.onTap?.call(heroKey),
        onTapDown: (_) => setState(() => elevation = 4),
        onTapUp: (_) => setState(() => elevation = 1),
        onTapCancel: () => setState(() => elevation = 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: Hero(
                tag: heroKey,
                child: widget.article.cover == null
                    ? Assets.images.defaultCover.image()
                    : Image.network(
                        widget.article.cover!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          final progress =
                              loadingProgress.cumulativeBytesLoaded;
                          return SizedBox(
                            height: 157,
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
                      child: ClipOval(
                        child: Image.network(
                          widget.article.author.avatar,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Assets.images.profilePhoto.image(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 54),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            widget.article.author.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Get.theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Divider(height: 1)
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
                style: Get.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            if (widget.article.bodyText.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  widget.article.bodyText,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: TextStyle(
                    color:
                        Get.theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
