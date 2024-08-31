part of 'api_user.dart';

Future<Article?> getDiscussion(int number) async {
  final res = await graphql(
      '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { number author { avatarUrl(size: 50) login } createdAt lastEditedAt bodyHTML id bodyText title comments { totalCount } } } }');
  if (res.data
      case {
        'data': {
          'repository': {
            'discussion': {
              'author': {
                'avatarUrl': final String avatar,
                'login': final String name,
              },
              'id': final String id,
              'bodyHTML': final String bodyHTML,
              'bodyText': final String bodyText,
              'title': final String title,
              'number': final int number,
              'createdAt': final String createdAt,
              'lastEditedAt': final String? lastEditedAt,
              'comments': {
                'totalCount': final int commentsCount,
              },
            },
          },
        }
      }) {
    final (:html, :cover, :partition) = parseHtml(bodyHTML);
    return Article(
      title: title,
      bodyHTML: html,
      rawBodyText: bodyText,
      author: Author(avatar: avatar, login: name),
      cover: cover,
      number: number,
      id: id,
      createdAt: DateTime.parse(createdAt),
      lastEditedAt:
          lastEditedAt == null ? null : DateTime.tryParse(lastEditedAt),
      commentsCount: commentsCount,
      isPin: false,
      partition: partition!,
    );
  }
  return null;
}
