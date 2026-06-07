import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/comment_count.dart';
import 'package:inter_knot/components/discussion_badge.dart';
import 'package:inter_knot/components/discussion_labels.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/ai_review_helper.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _discussionCardOuterRadius = BorderRadius.only(
  topLeft: Radius.circular(24),
  topRight: Radius.circular(24),
  bottomLeft: Radius.circular(24),
);
const _discussionCardInnerRadius = BorderRadius.only(
  topLeft: Radius.circular(20),
  topRight: Radius.circular(20),
  bottomLeft: Radius.circular(20),
);
const _discussionCardBorderWidth = 4.0;
const _discussionCardFill = Color(0xff222222);

class DiscussionCard extends StatefulWidget {
  const DiscussionCard({
    super.key,
    this.onTap,
    required this.discussion,
    required this.hData,
  });

  final DiscussionModel discussion;
  final HDataModel hData;
  final void Function()? onTap;

  @override
  State<DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<DiscussionCard>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();
  bool _isHovering = false;

  Color get _borderColor {
    if (_isHovering) return const Color(0xffD7FF00);
    if (widget.hData.isPin) return Colors.blue;
    return Colors.black;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Obx(() {
      final historyItems = c.history();
      HDataModel? historyItem;
      for (final item in historyItems) {
        if (item.number == widget.discussion.number) {
          historyItem = item;
          break;
        }
      }
      final isLabelVisible = historyItem == null ||
          historyItem.updatedAt != widget.hData.updatedAt;
      final card = _buildCard(context);

      return Badge(
        isLabelVisible: isLabelVisible,
        child: card,
      );
    });
  }

  Widget _buildCard(BuildContext context) {
    if (!c.canVisit(widget.discussion, widget.hData.isPin)) {
      return AspectRatio(
        aspectRatio: 5 / 6,
        child: InkWell(
          onTap: () => launchUrlString(widget.discussion.url),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'This discussion is suspected of violating regulations'.tr,
                ),
                Text(
                  'This discussion was reported by @count people'.trParams({
                    'count':
                        c.report[widget.discussion.number]!.length.toString(),
                  }),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _borderColor,
          borderRadius: _discussionCardOuterRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.all(_discussionCardBorderWidth),
          child: ClipRRect(
            borderRadius: _discussionCardInnerRadius,
            child: Material(
              color: _discussionCardFill,
              child: InkWell(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                onTap: widget.onTap,
                child: _buildContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final badges = <Widget>[];
    final aiReviewRating = widget.discussion.aiReviewRatingFromLabels ??
        widget.hData.aiReviewRatingFromLabels;
    final aiReviewView = mapAiReviewRatingView(aiReviewRating);
    final categoryView = mapDiscussionCategory(widget.discussion.categoryName);
    final visibleLabels = filterBusinessLabels(widget.discussion.labels);
    if (widget.hData.isPin) {
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Cover(
              discussion: widget.discussion,
              isHovering: _isHovering,
            ),
            Positioned(
              top: 10,
              left: 12,
              child: CommentCount(
                discussion: widget.discussion,
                color: Colors.white,
              ),
            ),
            if (badges.isNotEmpty)
              Positioned(
                top: 10,
                right: 12,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: badges,
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
                  top: -28,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: _discussionCardFill,
                      shape: BoxShape.circle,
                    ),
                    child: Avatar(
                      widget.discussion.author.avatar,
                      size: 50,
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
                        widget.discussion.author.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
        if (visibleLabels.isNotEmpty) ...[
          const SizedBox(height: 8),
          DiscussionLabels(
            labels: visibleLabels,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ],
        if (widget.discussion.rawBodyText.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              widget.discussion.bodyText,
              style: const TextStyle(
                color: Color(0xffE0E0E0),
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class Cover extends StatelessWidget {
  const Cover({
    super.key,
    required this.discussion,
    this.isHovering = false,
  });

  final DiscussionModel discussion;
  final bool isHovering;

  @override
  Widget build(BuildContext context) {
    if (discussion.coverIsIframe && discussion.cover != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: const Color(0xff171717),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.smart_display_rounded, color: Color(0xffD7FF00)),
              const SizedBox(height: 8),
              Text(
                'Enter discussion to load iframe'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xffC0C0C0),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final coverUrl = discussion.cover;
    Widget image;
    if (coverUrl == null) {
      image = Assets.images.defaultCover.image(
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else {
      image = Image.network(
        coverUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox.shrink();
        },
        errorBuilder: (context, error, stackTrace) =>
            Assets.images.defaultCover.image(fit: BoxFit.cover),
      );
    }

    return AspectRatio(
      aspectRatio: 643 / 408,
      child: ClipRect(
        child: AnimatedScale(
          scale: isHovering ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          child: image,
        ),
      ),
    );
  }
}
