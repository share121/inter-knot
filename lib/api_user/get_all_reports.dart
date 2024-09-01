part of 'api_user.dart';

Future<Report> getAllReports(int number) async {
  final res = <({String login, Set<int> numbers, String bodyHTML})>[];
  String? after;
  while (true) {
    final data = await graphql(
        '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 100, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { author { login } body bodyHTML } } } } }');
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
      res.addAll(nodes
          .map((e) {
            if (e
                case {
                  'author': {
                    'login': final String login,
                  },
                  'body': final String body,
                  'bodyHTML': final String bodyHTML,
                }) {
              return (login: login, bodyHTML: bodyHTML, body: body);
            }
            return null;
          })
          .whereType<({String login, String bodyHTML, String body})>()
          .map((e) {
            if (!e.body.contains('原因')) return null;
            final numbers = RegExp(r'#(\d+)')
                .allMatches(e.body)
                .map((e) => e.group(1))
                .whereType<String>()
                .map((e) => int.parse(e))
                .toSet();
            if (numbers.isEmpty) return null;
            return (
              login: e.login,
              bodyHTML: e.bodyHTML,
              numbers: numbers,
            );
          })
          .whereType<({String login, Set<int> numbers, String bodyHTML})>());
      if (!hasNextPage) break;
      after = endCursor;
    }
  }
  final t = await Future.wait(transformReports(res)
      .entries
      .map((e) => isDiscussionAvailable(e.key).then((v) => v ? e : null))
      .toList());
  return Map.fromEntries(t.whereType<MapEntry<int, Set<ReportComment>>>());
}
