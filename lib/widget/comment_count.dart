import 'package:flutter/material.dart';
import 'package:inter_knot/data.dart';

class CommentCount extends StatelessWidget {
  const CommentCount({
    super.key,
    required this.article,
  });

  final Article article;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.comment_outlined, size: 18),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(article.commentsCount.toString()),
        ),
      ],
    );
  }
}
