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
    return PaginationModel(
      nodes: (json['nodes'] as List)
          .cast<Map<String, dynamic>>()
          .map(map)
          .toList(),
      hasNextPage: json['hasNextPage'] as bool,
      endCursor: json['endCursor'] as String?,
    );
  }
}
