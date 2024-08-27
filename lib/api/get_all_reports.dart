import 'dart:async';

import 'common.dart';
import '../data.dart';

Future<List<Comment>> getAllReports(int number) async {
  final res = <Comment>[];
  String? after;
  while (true) {
    final data = await graphql(
        '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 100, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { author { login } bodyHTML } } } } }');
    if (data.data
        case {
          'data': {
            'repository': {
              'discussion': {
                'comments': {
                  'pageInfo': {
                    'hasNextPage': final bool hasNextPage,
                    'endCursor': final String endCursor
                  },
                  'nodes': final List<dynamic> nodes
                }
              }
            }
          }
        }) {
      res.addAll(nodes.map((e) {
        if (e
            case {
              'author': {
                'login': final String name,
              },
              'bodyHTML': final String bodyHTML,
            }) {
          return Comment(
            author: Author(login: name, avatar: ''),
            bodyHTML: bodyHTML,
            createdAt: DateTime.now(),
            replies: [],
            id: '',
          );
        }
        return null;
      }).whereType<Comment>());
      if (!hasNextPage) break;
      after = endCursor;
    }
  }
  return res;
}
