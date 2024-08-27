import 'package:inter_knot/api/common.dart';
import 'package:inter_knot/data.dart';

class Version {
  final String version;
  final List<ReleaseAsset> releaseAssets;
  final String? descriptionHTML;

  Version({
    required this.version,
    required this.releaseAssets,
    this.descriptionHTML,
  });
}

class ReleaseAsset {
  final String downloadUrl;
  final String name;
  final int downloadCount;
  final int size;
  final DateTime updatedAt;

  ReleaseAsset({
    required this.downloadUrl,
    required this.name,
    required this.downloadCount,
    required this.size,
    required this.updatedAt,
  });
}

Future<Version?> getNewVersion() async {
  final res = await graphql(
      '{ repository(owner: "$owner", name: "inter_knot") { releases(first: 1) { nodes { tagName descriptionHTML releaseAssets(first: 100) { nodes { downloadUrl name downloadCount size updatedAt } } } } }}');

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
    return Version(
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
