part of 'api_root.dart';

Future<Nodes<Comment>> getComments(int number, String? after) async {
  final res = await graphql(
      '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 20, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { author { avatarUrl(size: 50) login } id bodyHTML createdAt lastEditedAt replies(first: 100) { nodes { author { avatarUrl(size: 50) login } bodyHTML createdAt lastEditedAt } } } } } } } }');
  if (res.data
      case {
        'data': {
          'repository': {
            'discussion': {
              'comments': {
                'nodes': final List<dynamic> nodes,
                'pageInfo': {
                  'hasNextPage': final bool hasNextPage,
                  'endCursor': final String endCursor
                },
              },
            },
          },
        },
      }) {
    return (
      res: nodes
          .map((e) {
            if (e
                case {
                  'author': {
                    'avatarUrl': final String avatar,
                    'login': final String name,
                  },
                  'bodyHTML': final String bodyHTML,
                  'createdAt': final String createdAt,
                  'lastEditedAt': final String? lastEditedAt,
                  'id': final String id,
                  'replies': {
                    'nodes': final List<dynamic> replies,
                  },
                }) {
              final (:html, :cover) = parseHtml(bodyHTML, true);
              return Comment(
                author: Author(avatar: avatar, login: name),
                bodyHTML: html,
                createdAt: DateTime.parse(createdAt),
                lastEditedAt: lastEditedAt == null
                    ? null
                    : DateTime.tryParse(lastEditedAt),
                id: id,
                replies: replies
                    .map((e) {
                      if (e
                          case {
                            'author': {
                              'avatarUrl': final String avatar,
                              'login': final String name,
                            },
                            'bodyHTML': final String bodyHTML,
                            'createdAt': final String createdAt,
                            'lastEditedAt': final String? lastEditedAt,
                          }) {
                        final (:html, :cover) = parseHtml(bodyHTML, true);
                        return Reply(
                          author: Author(avatar: avatar, login: name),
                          bodyHTML: html,
                          createdAt: DateTime.parse(createdAt),
                          lastEditedAt: lastEditedAt == null
                              ? null
                              : DateTime.tryParse(lastEditedAt),
                        );
                      }
                    })
                    .whereType<Reply>()
                    .toList(),
              );
            }
          })
          .whereType<Comment>()
          .toList(),
      hasNextPage: hasNextPage,
      endCursor: endCursor,
    );
  }
  return (res: <Comment>[], hasNextPage: false, endCursor: null);
}
