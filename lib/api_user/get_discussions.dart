part of 'api_user.dart';

Future<Nodes<HData>> getDiscussions(String? after) async {
  final res = await graphql(
      '{ repository(owner: "$owner", name: "$repo") { discussions(first: 100, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { number } } } } }');
  if (res.data
      case {
        'data': {
          'repository': {
            'discussions': {
              'nodes': final List<dynamic> nodes,
              'pageInfo': {
                'hasNextPage': final bool hasNextPage,
                'endCursor': final String? endCursor
              },
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
