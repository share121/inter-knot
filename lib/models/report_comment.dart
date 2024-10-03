class ReportCommentModel {
  String login;
  String bodyHTML;
  String get url => 'https://github.com/$login';

  ReportCommentModel({required this.login, required this.bodyHTML});

  @override
  bool operator ==(Object other) =>
      other is ReportCommentModel && other.login == login;

  @override
  int get hashCode => login.hashCode;
}
