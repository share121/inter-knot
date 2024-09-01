part of 'api_root.dart';

Future<({int? totalCount, String? name})> getUserInfo(String login) async {
  final res = await graphql(
      '{ user(login: "${encode(login)}") { repositories { totalCount }, name } }');
  if (res.data
      case {
        'data': {
          'user': {
            'repositories': {
              'totalCount': final int totalCount,
            },
            'name': final String name,
          }
        }
      }) {
    return (totalCount: totalCount, name: name);
  }
  return (totalCount: null, name: null);
}
