import 'package:get/get.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/parse_html.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/label.dart';
import 'package:inter_knot/models/pagination.dart';

enum AiReviewRating {
  highQuality,
  normal,
  lowQuality,
  risk,
}

const aiReviewLabelNames = <AiReviewRating, String>{
  AiReviewRating.highQuality: '高质',
  AiReviewRating.normal: '普通',
  AiReviewRating.lowQuality: '可能是答便',
  AiReviewRating.risk: '风险',
};

const aiReviewRawLabelNames = <String>{
  '高质',
  '普通',
  '可能是答便',
  '风险',
};

const _labelNameToRating = <String, AiReviewRating>{
  '高质': AiReviewRating.highQuality,
  '普通': AiReviewRating.normal,
  '可能是答便': AiReviewRating.lowQuality,
  '风险': AiReviewRating.risk,
};

const _aiReviewLabelPriority = <AiReviewRating, int>{
  AiReviewRating.risk: 0,
  AiReviewRating.lowQuality: 1,
  AiReviewRating.normal: 2,
  AiReviewRating.highQuality: 3,
};

AiReviewRating? parseAiReviewRatingFromLabelName(String raw) {
  final normalized = raw.trim();
  return _labelNameToRating[normalized];
}

AiReviewRating? deriveAiReviewRatingFromLabels(List<LabelModel> labels) {
  AiReviewRating? best;
  var bestPriority = 1 << 30;
  for (final label in labels) {
    final rating = parseAiReviewRatingFromLabelName(label.name);
    if (rating == null) continue;
    final priority = _aiReviewLabelPriority[rating]!;
    if (best == null || priority < bestPriority) {
      best = rating;
      bestPriority = priority;
    }
  }
  return best;
}

class DiscussionModel {
  String title;
  String bodyHTML;
  String rawBodyText;
  String? cover;
  bool coverIsIframe;
  int number;
  String id;
  DateTime createdAt;
  DateTime? lastEditedAt;
  int commentsCount;
  AuthorModel author;
  String? categoryName;
  String? categoryId;
  PollModel? poll;
  final List<LabelModel> labels;
  final RxList<PaginationModel<CommentModel>> comments;
  String get bodyText {
    final cleaned = rawBodyText
        .replaceAll(
          RegExp(
            r'&lt;\s*iframe\b[\s\S]*?&lt;\s*/\s*iframe\s*&gt;',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<\s*iframe\b[\s\S]*?<\s*/\s*iframe\s*>',
            caseSensitive: false,
          ),
          ' ',
        );
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  String get url => '$discussionsLink/$number';

  DiscussionModel({
    required this.title,
    required this.bodyHTML,
    required this.rawBodyText,
    required this.cover,
    required this.coverIsIframe,
    required this.number,
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    required this.lastEditedAt,
    required this.author,
    required this.categoryName,
    required this.categoryId,
    required this.poll,
    required this.labels,
    required List<PaginationModel<CommentModel>> comments,
  }) : comments = comments.obs;

  AiReviewRating? get aiReviewRatingFromLabels =>
      deriveAiReviewRatingFromLabels(labels);

  factory DiscussionModel.fromJson(Map<String, dynamic> json) {
    final (:cover, :coverIsIframe, :html) = parseHtml(json['bodyHTML'] as String);
    final comments = json['comments'] as Map<String, dynamic>?;
    final category = json['category'] as Map<String, dynamic>?;
    final pollJson = json['poll'] as Map<String, dynamic>?;
    final labelsJson = json['labels'] as Map<String, dynamic>?;
    final labelNodes = labelsJson?['nodes'] as List<dynamic>? ?? [];
    return DiscussionModel(
      title: json['title'] as String,
      bodyHTML: html,
      cover: cover,
      coverIsIframe: coverIsIframe,
      rawBodyText: json['bodyText'] as String,
      number: (json['number'] as int?) ?? 0,
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      commentsCount: (comments?['totalCount'] as int?) ?? 0,
      lastEditedAt:
          (json['lastEditedAt'] as String?).use((v) => DateTime.parse(v)),
      author: AuthorModel.fromJson(json['author'] as Map<String, dynamic>),
      categoryName: category?['name'] as String?,
      categoryId: category?['id'] as String?,
      poll: pollJson == null ? null : PollModel.fromJson(pollJson),
      labels: labelNodes
          .whereType<Map<String, dynamic>>()
          .map(LabelModel.fromJson)
          .toList(),
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

class PollOptionModel {
  final String id;
  final String option;
  final int totalVoteCount;
  final bool viewerHasVoted;

  PollOptionModel({
    required this.id,
    required this.option,
    required this.totalVoteCount,
    required this.viewerHasVoted,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      id: json['id'] as String,
      option: json['option'] as String,
      totalVoteCount: (json['totalVoteCount'] as int?) ?? 0,
      viewerHasVoted: (json['viewerHasVoted'] as bool?) ?? false,
    );
  }
}

class PollModel {
  final String question;
  final int totalVoteCount;
  final bool viewerCanVote;
  final bool viewerHasVoted;
  final List<PollOptionModel> options;

  PollModel({
    required this.question,
    required this.totalVoteCount,
    required this.viewerCanVote,
    required this.viewerHasVoted,
    required this.options,
  });

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final optionsJson = json['options'] as Map<String, dynamic>?;
    final nodes = optionsJson?['nodes'] as List<dynamic>? ?? [];
    return PollModel(
      question: json['question'] as String,
      totalVoteCount: (json['totalVoteCount'] as int?) ?? 0,
      viewerCanVote: (json['viewerCanVote'] as bool?) ?? false,
      viewerHasVoted: (json['viewerHasVoted'] as bool?) ?? false,
      options: nodes
          .whereType<Map<String, dynamic>>()
          .map(PollOptionModel.fromJson)
          .toList(),
    );
  }
}
