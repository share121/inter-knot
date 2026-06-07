import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/avatar.dart';
import 'package:inter_knot/components/my_chip.dart';
import 'package:inter_knot/components/my_html_widget.dart';
import 'package:inter_knot/constants/globals.dart';
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
            title: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Offstage(
                    child: InkWell(
                      onTap: () => launchUrlString(reply.url),
                      child: const Text(''),
                    ),
                  ),
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
                Builder(
                  builder: (context) {
                    final hasIframe = RegExp(
                      r'<\s*iframe\b',
                      caseSensitive: false,
                    ).hasMatch(reply.bodyHTML);
                    if (hasIframe) {
                      return MyHtmlWidget(
                        html: reply.bodyHTML,
                        textStyle: const TextStyle(fontSize: 16),
                        inDiscussionDetail: true,
                      );
                    }
                    return SelectionArea(
                      child: MyHtmlWidget(
                        html: reply.bodyHTML,
                        textStyle: const TextStyle(fontSize: 16),
                        inDiscussionDetail: true,
                      ),
                    );
                  },
                ),
                const Divider(),
              ],
            ),
          ),
      ],
    );
  }
}
