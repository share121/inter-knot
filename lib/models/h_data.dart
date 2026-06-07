import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/label.dart';

class HDataModel {
  static final _zeroDate = DateTime.fromMillisecondsSinceEpoch(0);
  static final api = Get.find<Api>();
  static final discussionsCache = <int, Future<DiscussionModel?>>{};

  int number;
  DateTime updatedAt;
  bool isPinned;
  List<LabelModel> labels;
  String? categoryId;
  String? categoryName;
  bool get isPin => isPinned;
  String get url => '$discussionsLink/$number';
  Future<DiscussionModel?> get discussion => getDiscussion();
  AiReviewRating? get aiReviewRatingFromLabels =>
      deriveAiReviewRatingFromLabels(labels);

  HDataModel({
    required this.number,
    required DateTime? updatedAt,
    required this.isPinned,
    required this.labels,
    this.categoryId,
    this.categoryName,
  }) : updatedAt = updatedAt ?? _zeroDate;

  Future<DiscussionModel?> getDiscussion() {
    final cached = discussionsCache[number];
    if (cached != null) {
      return cached.catchError((Object error, StackTrace stackTrace) {
        discussionsCache.remove(number);
        return api.getDiscussion(number);
      });
    }
    return discussionsCache[number] = api.getDiscussion(number).then(
      (value) => value,
      onError: (Object error, StackTrace stackTrace) {
        discussionsCache.remove(number);
        throw error;
      },
    );
  }

  factory HDataModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return HDataModel(
      number: json['number'] as int,
      updatedAt: (json['updatedAt'] as String?).use((v) => DateTime.parse(v)),
      isPinned: false,
      labels: _parseLabels(json['labels'] as Map<String, dynamic>?),
      categoryId: category?['id'] as String?,
      categoryName: category?['name'] as String?,
    );
  }

  factory HDataModel.fromPinnedJson(Map<String, dynamic> json) {
    final discussion = json['discussion'] as Map<String, dynamic>? ?? json;
    final category = discussion['category'] as Map<String, dynamic>?;
    return HDataModel(
      number: discussion['number'] as int,
      updatedAt:
          (discussion['updatedAt'] as String?).use((v) => DateTime.parse(v)),
      isPinned: true,
      labels:
          _parseLabels(discussion['labels'] as Map<String, dynamic>?),
      categoryId: category?['id'] as String?,
      categoryName: category?['name'] as String?,
    );
  }

  factory HDataModel.fromStr(String value) {
    final parts = value.split(',');
    final number = int.tryParse(parts.first) ?? 0;
    final updatedAt = parts.length > 1 ? DateTime.tryParse(parts[1]) : null;
    return HDataModel(
      number: number,
      updatedAt: updatedAt,
      isPinned: false,
      labels: const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HDataModel && number == other.number;

  @override
  int get hashCode => number;

  static List<LabelModel> _parseLabels(Map<String, dynamic>? labelsJson) {
    final nodes = labelsJson?['nodes'] as List<dynamic>? ?? [];
    return nodes
        .whereType<Map<String, dynamic>>()
        .map(LabelModel.fromJson)
        .toList();
  }
}
