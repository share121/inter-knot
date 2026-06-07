import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/models/discussion.dart';

final _fetchingComments = <int>{};

extension DiscussionActions on DiscussionModel {
  bool hasNextPage() => comments.isNotEmpty && comments.last.hasNextPage;

  Future<void> fetchComments() async {
    if (_fetchingComments.contains(number)) return;
    if (!hasNextPage()) return;
    final cursor = comments.last.endCursor;
    if (cursor == null) return;
    _fetchingComments.add(number);
    try {
      final api = Get.find<Api>();
      final page = await api.getComments(number, cursor);
      comments.add(page);
    } finally {
      _fetchingComments.remove(number);
    }
  }

  Future<void> refreshComments() async {
    final api = Get.find<Api>();
    final page = await api.getComments(number, null);
    comments.assignAll([page]);
  }
}
