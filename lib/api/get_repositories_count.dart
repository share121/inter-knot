import 'dart:async';

import 'common.dart';

Future<int?> getRepositoriesCount(String login) async {
  final res = await graphql(
      '{ user(login: "${encode(login)}") { repositories { totalCount } } }');
  if (res.data
      case {
        'data': {
          'user': {
            'repositories': {
              'totalCount': final int totalCount,
            }
          }
        }
      }) {
    return totalCount;
  }
  return null;
}
