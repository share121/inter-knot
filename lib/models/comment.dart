import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/models/author.dart';

class CommentModel {
  final AuthorModel author;
  final String bodyHTML;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final replies = <CommentModel>{};
  final String id;
  final String url;

  CommentModel({
    required this.author,
    required this.bodyHTML,
    required this.createdAt,
    required this.lastEditedAt,
    required Iterable<CommentModel> replies,
    required this.id,
    required this.url,
  }) {
    this.replies.addAll(replies);
  }

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final parsed = parseHtml(json['bodyHTML'] as String, true);
    final repliesJson = json['replies'];
    final repliesNodes = switch (repliesJson) {
      {'nodes': final List nodes} => nodes,
      List _ => repliesJson,
      _ => const [],
    };
    final authorJson = json['author'] as Map<String, dynamic>?;
    final createdAtRaw = json['createdAt'] as String?;
    final lastEditedRaw = json['lastEditedAt'] as String?;
    return CommentModel(
      author: authorJson == null
          ? AuthorModel.deleted()
          : AuthorModel.fromJson(authorJson),
      bodyHTML: parsed.html,
      createdAt:
          DateTime.tryParse(createdAtRaw ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      lastEditedAt:
          lastEditedRaw == null ? null : DateTime.tryParse(lastEditedRaw),
      replies: repliesNodes
          .whereType<Map<String, dynamic>>()
          .map((e) => CommentModel.fromJson(e)),
      id: (json['id'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
    );
  }

  @override
  bool operator ==(Object other) => other is CommentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
