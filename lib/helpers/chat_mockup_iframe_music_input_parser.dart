import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' show parseFragment;

final RegExp _iframeTagOpenRe = RegExp(r'<\s*iframe\b', caseSensitive: false);

dom.Element? _findFirstIframeElement(dom.Node node) {
  if (node is dom.Element) {
    if (node.localName?.toLowerCase() == 'iframe') {
      return node;
    }
    for (final child in node.nodes) {
      final found = _findFirstIframeElement(child);
      if (found != null) {
        return found;
      }
    }
  }
  return null;
}

String? _iframeSrcOrDataSrc(dom.Element iframe) {
  final src = iframe.attributes['src']?.trim();
  if (src != null && src.isNotEmpty) {
    return src;
  }
  final dataSrc = iframe.attributes['data-src']?.trim();
  if (dataSrc != null && dataSrc.isNotEmpty) {
    return dataSrc;
  }
  return null;
}

/// Extracts the embed URL from **raw iframe HTML** or returns the trimmed string as a
/// **candidate URL** (no allowlist; no `//` → `https:` here — use
/// [normalizeChatMockupMusicIframeInput] next).
///
/// Throws [FormatException] when the input looks like iframe HTML but no usable
/// `src` / `data-src` can be read.
String extractChatMockupIframeMusicEmbedUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('无法解析 iframe 地址：输入为空。');
  }
  if (!_iframeTagOpenRe.hasMatch(trimmed)) {
    return trimmed;
  }
  final fragment = parseFragment(trimmed);
  dom.Element? iframe;
  for (final n in fragment.nodes) {
    iframe = _findFirstIframeElement(n);
    if (iframe != null) {
      break;
    }
  }
  if (iframe == null) {
    throw const FormatException(
      '无法解析 iframe 地址：内容含 iframe 标记但未找到可用的 iframe 元素。',
    );
  }
  final url = _iframeSrcOrDataSrc(iframe);
  if (url == null || url.isEmpty) {
    throw const FormatException(
      '无法解析 iframe 地址：iframe 缺少有效的 src 或 data-src 属性。',
    );
  }
  return url;
}
