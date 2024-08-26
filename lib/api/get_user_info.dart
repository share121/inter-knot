import 'dart:async';

import 'common.dart';
import '../data.dart';

Future<Author?> getUserInfo() async {
  final res = await graphql(
      '{ viewer { avatarUrl(size: 50) login repositories { totalCount } } }');
  if (res.data
      case {
        'data': {
          'viewer': {
            'login': final String name,
            'avatarUrl': final String avatar,
            'repositories': {
              'totalCount': final int level,
            },
          },
        }
      }) {
    return Author(
      name: name,
      avatar: avatar,
      level: level,
    );
  }
  return null;
}
