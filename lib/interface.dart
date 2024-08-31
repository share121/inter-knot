import 'package:get/get.dart';

import 'api/api_root.dart' as api_root;
import 'data.dart';

typedef Nodes<T> = ({List<T> res, bool hasNextPage, String? endCursor});

typedef Report = Map<int, Set<ReportComment>>;

class ReportComment {
  final String login;
  final String bodyHTML;
  late final url = 'https://github.com/$login';

  ReportComment({required this.login, required this.bodyHTML});

  @override
  operator ==(Object other) =>
      other is ReportComment &&
      other.login == login &&
      other.bodyHTML == bodyHTML;

  @override
  int get hashCode => login.hashCode ^ bodyHTML.hashCode;
}

class Release {
  final String version;
  final List<ReleaseAsset> releaseAssets;
  final String? descriptionHTML;

  Release({
    required this.version,
    required this.releaseAssets,
    this.descriptionHTML,
  });

  @override
  operator ==(Object other) => other is Release && other.version == version;

  @override
  int get hashCode => version.hashCode;
}

class ReleaseAsset {
  final String downloadUrl;
  final String name;
  final int downloadCount;
  final int size;
  final DateTime updatedAt;

  ReleaseAsset({
    required this.downloadUrl,
    required this.name,
    required this.downloadCount,
    required this.size,
    required this.updatedAt,
  });

  @override
  operator ==(Object other) =>
      other is ReleaseAsset && other.downloadUrl == downloadUrl;

  @override
  int get hashCode => downloadUrl.hashCode;
}

class Article extends GetxController {
  final String title;
  final String bodyHTML;
  final String rawBodyText;
  final Author author;
  final String? cover;
  final int number;
  late final url = 'https://github.com/$owner/$repo/discussions/$number';
  final String id;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final int commentsCount;
  final comments = <Comment>{}.obs;
  var hasNextPage = true.obs;
  String? endCursor;
  final bool isPin;
  late final bodyText = rawBodyText.replaceAll(RegExp(r'\s+'), ' ').trim();

  final cache = <String?>{};
  Future<void> fetchComments() async {
    if (hasNextPage.isFalse || cache.contains(endCursor)) {
      return;
    }
    final (:res, hasNextPage: newHasNextPage, endCursor: newEndCursor) =
        await api_root.getComments(number, endCursor);
    comments.addAll(res);
    hasNextPage.value = newHasNextPage;
    endCursor = newEndCursor;
  }

  Article({
    required this.title,
    required this.bodyHTML,
    required this.rawBodyText,
    required this.author,
    this.cover,
    required this.number,
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    this.lastEditedAt,
    required this.isPin,
  });

  @override
  operator ==(Object other) => other is Article && other.number == number;

  @override
  int get hashCode => number;
}

class Comment extends GetxController {
  final Author author;
  final String bodyHTML;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final replies = <Reply>{}.obs;
  final String id;

  Comment({
    required this.author,
    required this.bodyHTML,
    required this.createdAt,
    this.lastEditedAt,
    required Iterable<Reply> replies,
    required this.id,
  }) {
    this.replies.addAll(replies);
  }

  @override
  operator ==(Object other) => other is Comment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Reply {
  final Author author;
  final String bodyHTML;
  final DateTime createdAt;
  final DateTime? lastEditedAt;

  Reply({
    required this.author,
    required this.bodyHTML,
    required this.createdAt,
    this.lastEditedAt,
  });

  @override
  operator ==(Object other) =>
      other is Reply &&
      other.author == author &&
      other.bodyHTML == bodyHTML &&
      other.createdAt == createdAt &&
      other.lastEditedAt == lastEditedAt;

  @override
  int get hashCode => Object.hash(author, bodyHTML, createdAt, lastEditedAt);
}

class Author {
  final String login;
  final String avatar;
  late final url = 'https://github.com/$login';

  Author({required this.login, required this.avatar});

  @override
  operator ==(Object other) => other is Author && other.login == login;

  @override
  int get hashCode => login.hashCode;
}
