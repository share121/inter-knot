class DiscussionCategoryModel {
  final String id;
  final String name;
  final String? description;
  final String? emoji;
  final bool isAnswerable;

  DiscussionCategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.isAnswerable,
  });

  factory DiscussionCategoryModel.fromJson(Map<String, dynamic> json) {
    return DiscussionCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      emoji: json['emoji'] as String?,
      isAnswerable: (json['isAnswerable'] as bool?) ?? false,
    );
  }
}
