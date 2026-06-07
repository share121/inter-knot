class AuthorModel {
  String login;
  String avatar;
  late String name;
  String type;
  int level;
  int contributions;

  late final url = 'https://github.com/$login';
  String get displayName => name.trim().isEmpty ? login : name;

  AuthorModel({
    required this.login,
    required this.avatar,
    required this.level,
    required this.contributions,
    required String? name,
    String? type,
  })  : name = (name == null || name.trim().isEmpty) ? login : name,
        type = type ?? 'User';

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    final contributions = _readContributionsTotal(json);
    return AuthorModel(
      login: json['login'] as String,
      avatar: json['avatarUrl'] as String,
      level: contributions ~/ 100,
      contributions: contributions,
      name: json['name'] as String?,
      type: json['__typename'] as String?,
    );
  }

  factory AuthorModel.deleted() {
    return AuthorModel(
      login: 'deleted',
      avatar: '',
      level: 0,
      contributions: 0,
      name: null,
      type: 'Unknown',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthorModel && other.login == login;

  @override
  int get hashCode => login.hashCode;
}

int _readContributionsTotal(Map<String, dynamic> json) {
  final total = json['contributionsTotal'] as int?;
  if (total != null) return total;
  final thisYear = (json['thisYear'] as Map<String, dynamic>?)?[
          'contributionCalendar'] as Map<String, dynamic>? ??
      {};
  final lastYear = (json['lastYear'] as Map<String, dynamic>?)?[
          'contributionCalendar'] as Map<String, dynamic>? ??
      {};
  return (thisYear['totalContributions'] as int? ?? 0) +
      (lastYear['totalContributions'] as int? ?? 0);
}
