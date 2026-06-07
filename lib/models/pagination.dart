class PaginationModel<T> {
  List<T> nodes;
  bool hasNextPage;
  String? endCursor;

  PaginationModel({
    required this.nodes,
    required this.hasNextPage,
    required this.endCursor,
  });

  factory PaginationModel.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) map,
  ) {
    final pageInfo = json['pageInfo'] as Map<String, dynamic>?;
    final rawHasNextPage = pageInfo?['hasNextPage'] ?? json['hasNextPage'];
    final rawEndCursor = pageInfo?['endCursor'] ?? json['endCursor'];
    final nodesJson = (json['nodes'] as List?) ?? const [];
    return PaginationModel(
      nodes: nodesJson.whereType<Map<String, dynamic>>().map(map).toList(),
      hasNextPage: (rawHasNextPage as bool?) ?? false,
      endCursor: rawEndCursor as String?,
    );
  }
}
