import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/components/replies.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/flatten.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Comment extends StatelessWidget {
  const Comment({super.key, required this.discussion});

  final DiscussionModel discussion;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            for (final (index, comment)
                in discussion.comments.map((e) => e.nodes).flat.indexed)
              ListTile(
                titleAlignment: ListTileTitleAlignment.top,
                contentPadding: EdgeInsets.zero,
                horizontalTitleGap: 8,
                minVerticalPadding: 0,
                leading: ClipOval(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => launchUrlString(comment.url),
                    child: Avatar(comment.author.avatar),
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () => launchUrlString(comment.url),
                        child: Obx(
                          () => Text(
                            comment.author.name(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (comment.author.login == discussion.author.login)
                            MyChip('landlord'.tr),
                          if (comment.author.login == owner)
                            MyChip('Founder of Inter-Knot'.tr),
                          if (collaborators.contains(comment.author.login))
                            MyChip('Inter-Knot collaborator'.tr),
                        ],
                      ),
                    ),
                  ],
                ),
                trailing: MyChip('F${index + 1}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Published on: '.tr +
                          comment.createdAt.toLocal().toString(),
                    ),
                    if (comment.lastEditedAt != null)
                      Text(
                        'Last edited on: '.tr +
                            comment.lastEditedAt!.toLocal().toString(),
                      ),
                    const SizedBox(height: 8),
                    SelectionArea(
                      child: HtmlWidget(
                        comment.bodyHTML,
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const Divider(),
                    Replies(comment: comment, discussion: discussion),
                  ],
                ),
              ),
            Obx(() {
              if (discussion.comments.last.hasNextPage.isTrue) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              } else {
                return Text('No more comments'.tr);
              }
            }),
          ],
        ),
      );
    });
  }
}
