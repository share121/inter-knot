import 'package:html/parser.dart';

import 'interface.dart';

({String? cover, String html}) parseHtml(String html,
    [bool isComment = false]) {
  final document = parseFragment(html);
  if (!isComment) {
    final img = document.querySelector('img');
    final cover = img?.attributes['src'];
    img?.remove();
    var parent = img?.parent;
    while (parent != null && parent.nodes.isEmpty) {
      parent.remove();
      parent = parent.parent;
    }
    return (html: document.outerHtml, cover: cover);
  }
  document.querySelectorAll('.email-hidden-toggle').forEach((e) => e.remove());
  document.querySelectorAll('.email-hidden-reply').forEach((e) => e.remove());
  return (html: document.outerHtml, cover: null);
}

String encode(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\r', '\\r')
    .replaceAll('\n', '\\n');

Report transformReports(
    List<({String login, Set<int> numbers, String bodyHTML})> arr) {
  final Report obj = {};
  for (final i in arr) {
    for (final num in i.numbers) {
      if (obj[num] == null) {
        obj[num] = {ReportComment(login: i.login, bodyHTML: i.bodyHTML)};
      } else if (!obj[num]!.map((e) => e.login).contains(i.login)) {
        obj[num]!.add(ReportComment(login: i.login, bodyHTML: i.bodyHTML));
      }
    }
  }
  return obj;
}
