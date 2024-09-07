part of 'api_root.dart';

Future<Nodes<HData>> getPinnedDiscussions(String? after) async {
  final res = await graphql(
      '{ repository(owner: "$owner", name: "$repo") { pinnedDiscussions(first: 20, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { discussion { number } } } } } }');
  if (res.data
      case {
        'data': {
          'repository': {
            'pinnedDiscussions': {
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
                  'discussion': {
                    'number': final int number,
                  }
                }) {
              return HData(number, isPin: true);
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
