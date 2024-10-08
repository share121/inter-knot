import 'package:flutter/material.dart';
import 'package:inter_knot/models/discussion.dart';

class CommentCount extends StatelessWidget {
  const CommentCount({super.key, required this.discussion, this.color});

  final DiscussionModel discussion;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.comment_outlined, size: 18, color: color),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            discussion.commentsCount.toString(),
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}
