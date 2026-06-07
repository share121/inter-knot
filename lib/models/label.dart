class LabelModel {
  final String name;
  final String color;

  const LabelModel({
    required this.name,
    required this.color,
  });

  factory LabelModel.fromJson(Map<String, dynamic> json) {
    return LabelModel(
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '',
    );
  }
}
