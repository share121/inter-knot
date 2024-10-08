import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Replies extends StatelessWidget {
  const Replies({super.key, required this.comment, required this.discussion});

  final CommentModel comment;
  final DiscussionModel discussion;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final reply in comment.replies)
          ListTile(
            titleAlignment: ListTileTitleAlignment.top,
            contentPadding: EdgeInsets.zero,
            horizontalTitleGap: 8,
            minVerticalPadding: 0,
            leading: MediaQuery.of(context).size.width > 400
                ? ClipOval(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: () => launchUrlString(reply.url),
                      child: Avatar(reply.author.avatar),
                    ),
                  )
                : null,
            title: Row(
              children: [
                Flexible(
                  child: InkWell(
                    onTap: () => launchUrlString(reply.url),
                    child: Obx(
                      () => Text(
                        reply.author.name(),
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
                      if (reply.author.login == discussion.author.login)
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
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Published on: '.tr + reply.createdAt.toLocal().toString(),
                ),
                if (reply.lastEditedAt != null)
                  Text(
                    'Last edited on: '.tr +
                        reply.lastEditedAt!.toLocal().toString(),
                  ),
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
