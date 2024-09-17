part of 'api_user.dart';

Future<Nodes<HData>> search(String query, String? after) async {
  final res = await graphql(
      '{ search(first: 100, type: DISCUSSION, query: "repo:$owner/$repo ${encode(query)}", after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { ... on Discussion { number updatedAt } } } }');
  if (res.data
      case {
        'data': {
          'search': {
            'nodes': final List<dynamic> nodes,
            'pageInfo': {
              'hasNextPage': final bool hasNextPage,
              'endCursor': final String? endCursor
            },
          },
        }
      }) {
    return (
      res: nodes
          .map((e) {
            if (e
                case {
                  'number': final int number,
                  'updatedAt': final String updatedAt,
                }) {
              return HData(number, DateTime.parse(updatedAt));
            }
          })
          .whereType<HData>()
          .toList(),
      hasNextPage: hasNextPage,
      endCursor: endCursor
    );
  }
  return (res: <HData>[], hasNextPage: false, endCursor: null);
}
