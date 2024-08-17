import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';

import '../data.dart';

class DiscussionCard extends StatefulWidget {
  const DiscussionCard({
    super.key,
    required this.title,
    required this.bodyHTML,
    required this.bodyText,
    required this.author,
    required this.cover,
  });

  final String title;
  final String cover;
  final String bodyHTML;
  final String bodyText;
  final Author author;

  @override
  State<DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<DiscussionCard> {
  var elevation = 1.0;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: elevation,
      child: InkWell(
        onTap: () {},
        onTapDown: (_) => setState(() => elevation = 4),
        onTapUp: (_) => setState(() => elevation = 1),
        onTapCancel: () => setState(() => elevation = 1),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 157, maxHeight: 600),
              child: Image.network(
                widget.cover,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  return Shimmer.fromColors(
                    baseColor: Colors.grey.shade800.withOpacity(0),
                    highlightColor: Colors.grey.shade800.withOpacity(0.5),
                    child: Container(height: 157, color: Colors.black),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    Image.asset('assets/images/default-cover.png'),
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
                        child: SizedBox.square(
                          dimension: 50,
                          child: Image.network(
                            widget.cover,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              return Shimmer.fromColors(
                                baseColor: Colors.grey.shade800.withOpacity(0),
                                highlightColor:
                                    Colors.grey.shade800.withOpacity(0.5),
                                child:
                                    Container(height: 157, color: Colors.black),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Image.asset('assets/images/profile-photo.png'),
                          ),
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
                            widget.author.name,
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.title,
                style: Get.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.bodyText,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  color:
                      Get.theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
