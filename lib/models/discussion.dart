import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/pagination.dart';

class DiscussionModel {
  String title;
  String bodyHTML;
  String rawBodyText;
  String? cover;
  int number;
  String id;
  DateTime createdAt;
  DateTime? lastEditedAt;
  int commentsCount;
  AuthorModel author;
  List<PaginationModel<CommentModel>> comments;
  String get bodyText => rawBodyText.replaceAll(RegExp(r'\s+'), ' ').trim();

  DiscussionModel({
    required this.title,
    required this.bodyHTML,
    required this.rawBodyText,
    required this.cover,
    required this.number,
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    required this.lastEditedAt,
    required this.author,
    required this.comments,
  });

  factory DiscussionModel.fromJson(Map<String, dynamic> json) {
    final (:cover, :html) = parseHtml(json['bodyHTML'] as String);
    return DiscussionModel(
      title: json['title'] as String,
      bodyHTML: html,
      cover: cover,
      rawBodyText: json['bodyText'] as String,
      number: json['number'] as int,
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      commentsCount: (json['comments'] as Map<String, int>)['totalCount']!,
      lastEditedAt:
          (json['lastEditedAt'] as String?).use((v) => DateTime.parse(v)),
      author: AuthorModel.fromJson(json['author'] as Map<String, dynamic>),
      comments: [
        PaginationModel.fromJson(
          // ignore: avoid_dynamic_calls
          json['comments'] as Map<String, dynamic>,
          CommentModel.fromJson,
        ),
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiscussionModel && other.number == number;

  @override
  int get hashCode => number;
}
