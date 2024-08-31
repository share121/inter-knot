part of 'api_root.dart';

Future<Release?> getNewVersion() async {
  final res = await graphql(
      '{ repository(owner: "$owner", name: "$repo") { releases(first: 1) { nodes { tagName descriptionHTML releaseAssets(first: 100) { nodes { downloadUrl name downloadCount size updatedAt } } } } }}');
  if (res.data
      case {
        'data': {
          'repository': {
            'releases': {
              'nodes': [
                {
                  'tagName': final String tagName,
                  'descriptionHTML': final String? descriptionHTML,
                  'releaseAssets': {'nodes': final List<dynamic> assets}
                }
              ]
            }
          }
        }
      }) {
    return Release(
      version: tagName.substring(1),
      descriptionHTML: descriptionHTML,
      releaseAssets: assets
          .map((e) {
            if (e
                case {
                  'downloadUrl': final String downloadUrl,
                  'name': final String name,
                  'downloadCount': final int downloadCount,
                  'size': final int size,
                  'updatedAt': final String updatedAt
                }) {
              return ReleaseAsset(
                downloadUrl: downloadUrl,
                name: name,
                downloadCount: downloadCount,
                size: size,
                updatedAt: DateTime.parse(updatedAt),
              );
            }
            return null;
          })
          .whereType<ReleaseAsset>()
          .toList(),
    );
  }
  return null;
}
