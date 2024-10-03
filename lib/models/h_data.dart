import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/helpers/use.dart';
import 'package:inter_knot/models/discussion.dart';

class HDataModel {
  static final _zeroDate = DateTime.fromMillisecondsSinceEpoch(0);
  static final api = Get.find<Api>();
  static final discussionsCache = <int, Future<DiscussionModel?>>{};

  int number;
  DateTime updatedAt;
  bool isPinned;

  HDataModel({
    required this.number,
    required DateTime? updatedAt,
    required this.isPinned,
  }) : updatedAt = updatedAt ?? _zeroDate;

  Future<DiscussionModel?> getDiscussion() =>
      discussionsCache[number] ??= api.getDiscussion(number);

  factory HDataModel.fromJson(Map<String, dynamic> json) {
    return HDataModel(
      number: json['number'] as int,
      updatedAt: (json['updatedAt'] as String?).use((v) => DateTime.parse(v)),
      isPinned: false,
    );
  }

  factory HDataModel.fromPinnedJson(Map<String, dynamic> json) {
    return HDataModel(
      number: json['number'] as int,
      updatedAt: (json['updatedAt'] as String?).use((v) => DateTime.parse(v)),
      isPinned: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HDataModel && number == other.number;

  @override
  int get hashCode => number;
}
