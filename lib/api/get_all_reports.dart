import 'dart:async';

import 'common.dart';
import '../data.dart';

Future<List<dynamic>> getAllReports(int number) async {
  final res = <dynamic>[];
  String? after;
  while (true) {
    if ((await graphql(
                '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 20, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { author { login } bodyHTML } } } } }'))
            .data
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
      res.addAll(nodes);
      if (hasNextPage == false) break;
      after = endCursor;
    }
  }
  return res;
}
