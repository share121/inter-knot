import 'package:inter_knot/models/report_comment.dart';

typedef Report = Map<int, Set<ReportCommentModel>>;

Report transformReports(
  List<({String login, Set<int> numbers, String bodyHTML})> arr,
) {
  final Report obj = {};
  for (final i in arr) {
    for (final num in i.numbers) {
      if (obj[num] == null) {
        obj[num] = {ReportCommentModel(login: i.login, bodyHTML: i.bodyHTML)};
      } else if (!obj[num]!.map((e) => e.login).contains(i.login)) {
        obj[num]!.add(ReportCommentModel(login: i.login, bodyHTML: i.bodyHTML));
      }
    }
  }
  return obj;
}
