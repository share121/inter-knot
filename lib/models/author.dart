class AuthorModel {
  String login;
  String avatar;
  late String name;
  int level;

  late final url = 'https://github.com/$login';

  AuthorModel({
    required this.login,
    required this.avatar,
    required this.level,
    required String? name,
  }) : name = name ?? login;

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    return AuthorModel(
      login: json['login'] as String,
      avatar: json['avatarUrl'] as String,
      level: (json['repositories'] as Map<String, int>?)?['totalCount'] ?? 0,
      name: json['name'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthorModel && other.login == login;

  @override
  int get hashCode => login.hashCode;
}
