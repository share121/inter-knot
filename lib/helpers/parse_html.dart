import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:inter_knot/constants/globals.dart';

String _decodeHtmlEntities(String input) {
  return input
      .replaceAll('&amp;lt;', '&lt;')
      .replaceAll('&amp;gt;', '&gt;')
      .replaceAll('&amp;quot;', '&quot;')
      .replaceAll('&amp;#39;', '&#39;')
      .replaceAll('&amp;#x27;', '&#x27;')
      .replaceAll('&amp;#60;', '&#60;')
      .replaceAll('&amp;#62;', '&#62;')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&#60;', '<')
      .replaceAll('&#62;', '>')
      .replaceAll('&#x3C;', '<')
      .replaceAll('&#x3c;', '<')
      .replaceAll('&#x3E;', '>')
      .replaceAll('&#x3e;', '>')
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&');
}

String _restoreEscapedIframe(String html) {
  var result = html;
  final pattern = RegExp(
    r'(?:&lt;|&#60;|&#x3[cC];)\s*iframe\b[\s\S]*?(?:&lt;|&#60;|&#x3[cC];)\s*/\s*iframe\s*(?:&gt;|&#62;|&#x3[eE];)',
    caseSensitive: false,
  );
  for (var i = 0; i < 3; i++) {
    final normalized = result
        .replaceAll('&amp;lt;', '&lt;')
        .replaceAll('&amp;gt;', '&gt;')
        .replaceAll('&amp;#60;', '&#60;')
        .replaceAll('&amp;#62;', '&#62;');
    final next =
        normalized.replaceAllMapped(pattern, (m) => _decodeHtmlEntities(m[0]!));
    if (next == result) break;
    result = next;
  }
  return result;
}

void _restoreIframeInTextNodes(dom.DocumentFragment document) {
  final containers = <dom.Node>[document, ...document.querySelectorAll('*')];
  for (final container in containers) {
    final children = List<dom.Node>.from(container.nodes);
    for (final node in children) {
      if (node is! dom.Text) continue;
      final raw = node.text;
      if (!raw.contains('iframe') && !raw.contains('IFRAME')) continue;
      final restored = _restoreEscapedIframe(raw);
      if (!RegExp(r'<\s*iframe\b', caseSensitive: false).hasMatch(restored)) {
        continue;
      }
      final fragment = parseFragment(restored);
      if (fragment.querySelector('iframe') == null) continue;
      final index = container.nodes.indexOf(node);
      if (index < 0) continue;
      node.remove();
      container.nodes.insertAll(index, fragment.nodes);
    }
  }
}

({String? cover, bool coverIsIframe, String html}) parseHtml(
  String html, [
  bool isComment = false,
]) {
  final document = parseFragment(_restoreEscapedIframe(html));
  _restoreIframeInTextNodes(document);
  document.querySelectorAll('iframe').forEach((iframe) {
    final src = iframe.attributes['src'];
    if (src == null || src.isEmpty) return;
    if (!src.startsWith('//')) return;
    iframe.attributes['src'] = 'https:$src';
  });
  document.querySelectorAll('img').forEach((img) {
    final src = img.attributes['src'];
    if (src == null || src.isEmpty) return;
    if (src.startsWith(imageProxyUrl)) return;
    final uri = Uri.tryParse(src);
    if (uri == null) return;
    final isGithubUserImages = uri.host.endsWith('githubusercontent.com');
    if (!isGithubUserImages) return;
    final proxied = '$imageProxyUrl?url=${Uri.encodeComponent(src)}';
    img.attributes['src'] = proxied;
  });
  if (!isComment) {
    final coverElement = document.querySelector('img,iframe');
    final cover = switch (coverElement?.localName) {
      'img' => coverElement?.attributes['src'],
      'iframe' => coverElement?.outerHtml,
      _ => null,
    };
    final coverIsIframe = coverElement?.localName == 'iframe';
    coverElement?.remove();
    var parent = coverElement?.parent;
    while (parent != null && parent.nodes.isEmpty) {
      parent.remove();
      parent = parent.parent;
    }
    return (html: document.outerHtml, cover: cover, coverIsIframe: coverIsIframe);
  }
  document.querySelectorAll('.email-hidden-toggle').forEach((e) => e.remove());
  document.querySelectorAll('.email-hidden-reply').forEach((e) => e.remove());
  return (html: document.outerHtml, cover: null, coverIsIframe: false);
}
