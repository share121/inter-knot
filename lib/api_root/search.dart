part of 'api_root.dart';

Future<Nodes<HData>> search(String query, String? after) async {
  final res = await graphql(
      '{ search(first: 20, type: DISCUSSION, query: "repo:$owner/$repo ${encode(query)}", after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { ... on Discussion { number } } } }');
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
                }) {
              return HData(number);
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
