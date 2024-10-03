import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
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
    final (:cover, :html) = parseHtml(json['bodyHTML'] as String, true);
    return CommentModel(
      author: AuthorModel.fromJson(json['author'] as Map<String, dynamic>),
      bodyHTML: html,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastEditedAt:
          (json['lastEditedAt'] as String?).use((v) => DateTime.parse(v)),
      replies: (json['replies'] as List<Map<String, dynamic>>)
          .map((e) => CommentModel.fromJson(e)),
      id: json['id'] as String,
      url: json['url'] as String,
    );
  }

  @override
  bool operator ==(Object other) => other is CommentModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
