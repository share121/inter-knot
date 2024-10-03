class ReleaseModel {
  final String version;
  final List<ReleaseAssetModel> releaseAssets;
  final String? descriptionHTML;

  ReleaseModel({
    required this.version,
    required this.releaseAssets,
    required this.descriptionHTML,
  });

  factory ReleaseModel.fromJson(Map<String, dynamic> json) {
    return ReleaseModel(
      version: (json['tagName'] as String).substring(1),
      releaseAssets: ((json['releaseAssets'] as Map)['nodes'] as List)
          .cast<Map<String, dynamic>>()
          .map(ReleaseAssetModel.fromJson)
          .toList(),
      descriptionHTML: json['descriptionHTML'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReleaseModel && other.version == version;

  @override
  int get hashCode => version.hashCode;
}

class ReleaseAssetModel {
  final String downloadUrl;
  final String name;
  final int downloadCount;
  final int size;
  final DateTime updatedAt;

  ReleaseAssetModel({
    required this.downloadUrl,
    required this.name,
    required this.downloadCount,
    required this.size,
    required this.updatedAt,
  });

  factory ReleaseAssetModel.fromJson(Map<String, dynamic> json) {
    return ReleaseAssetModel(
      downloadUrl: json['downloadUrl'] as String,
      name: json['name'] as String,
      downloadCount: json['downloadCount'] as int,
      size: json['size'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReleaseAssetModel && other.downloadUrl == downloadUrl;

  @override
  int get hashCode => downloadUrl.hashCode;
}
