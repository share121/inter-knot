import 'dart:convert';

import 'package:xml/xml.dart';

/// Logical channel for a parsed JSON string field in AI output.
enum ChatMockupAiFieldKind {
  action,
  user,
  character,
}

/// One successfully parsed `"key": "value"` occurrence in document order.
class ChatMockupAiFieldEvent {
  const ChatMockupAiFieldEvent({
    required this.kind,
    required this.rawValue,
  });

  final ChatMockupAiFieldKind kind;
  final String rawValue;
}

/// Helpers for AI reply text: XML strict parse + field scan (primary), JSON
/// bracket repair + strict parse (legacy finalize), and ordered field scanning
/// for streaming / finalize fallback.
///
/// **Finalize** resolution order (canvas): XML strict → XML/JSON field scan →
/// legacy JSON strict → legacy JSON repair → (streaming only) cached projection.
///
/// **Live stream UI** uses [ChatMockupAiXmlStreamFieldParser] (strict closed leaf
/// tags only). [scanDirectorFields] with [forStreamPreview] remains for legacy
/// JSON finalize / tests; canvas streaming does not call it.
///
/// XML field scanning walks the buffer once with a hand-written scanner (CDATA,
/// unclosed tags for [forStreamPreview]). JSON field scanning tries JSON-like
/// `"key": "value"` first, then loose forms (`action:`, quoted `'key':`, etc.).
class ChatMockupAiStreamPreview {
  ChatMockupAiStreamPreview._();

  /// Normalized text for UI preview only (same pipeline as [repairForProjection]).
  static String previewTextFromRaw(String rawBuffer) {
    return repairForProjection(rawBuffer);
  }

  /// Strip fences, take `{`… suffix; drop excess closers, trim structural trailing
  /// commas, then append missing closers so [tryParseProjectedObject] can succeed
  /// on **repaired** buffers (legacy JSON finalize, not field scan).
  static String repairForProjection(String rawBuffer) {
    return _repairJsonTailForPreview(rawBuffer.trim());
  }

  /// [jsonDecode] of a string already passed through [repairForProjection]; used in
  /// legacy JSON finalize. Returns `null` on failure.
  static Map<String, dynamic>? tryParseProjectedObject(String repaired) {
    try {
      final decoded = jsonDecode(repaired);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Trim, strip Markdown ``` fences, then slice from first `<chat` through last
  /// `</chat>` (inclusive) when present.
  static String preprocessForXmlParse(String raw) {
    var t = raw.trim();
    if (t.startsWith('```')) {
      final fenceIndex = t.indexOf('\n');
      if (fenceIndex >= 0) {
        t = t.substring(fenceIndex + 1);
      }
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
      t = t.trim();
    }
    final start = t.indexOf('<chat');
    if (start >= 0) {
      t = t.substring(start);
      const chatClose = '</chat>';
      final end = t.lastIndexOf(chatClose);
      if (end >= 0) {
        t = t.substring(0, end + chatClose.length);
      }
    }
    return t;
  }

  /// Trim, strip Markdown ``` fences, then scan from first `{` (if any).
  static String preprocessForFieldScan(String raw) {
    var t = raw.trim();
    if (t.startsWith('```')) {
      final fenceIndex = t.indexOf('\n');
      if (fenceIndex >= 0) {
        t = t.substring(fenceIndex + 1);
      }
      if (t.endsWith('```')) {
        t = t.substring(0, t.length - 3);
      }
      t = t.trim();
    }
    final start = t.indexOf('{');
    if (start >= 0) {
      t = t.substring(start);
    }
    return t;
  }

  /// Well-formed XML director output → `{ "turns": [ { action, user, character } ] }`.
  static Map<String, dynamic>? tryParseStrictXmlDirector(String raw) {
    final preprocessed = preprocessForXmlParse(raw);
    if (preprocessed.isEmpty) return null;
    try {
      final doc = XmlDocument.parse(preprocessed);
      final chat = doc.rootElement;
      if (chat.name.local != 'chat') return null;

      final turns = <Map<String, dynamic>>[];
      for (final child in chat.childElements) {
        if (child.name.local != 'turn') continue;
        final action = _directChildText(child, 'action');
        final user = _directChildText(child, 'user');
        final character = _directChildText(child, 'character');
        if (action == null || user == null || character == null) return null;
        turns.add({
          'action': action,
          'user': user,
          'character': character,
        });
      }
      if (turns.isEmpty) return null;
      return {'turns': turns};
    } catch (_) {
      return null;
    }
  }

  /// Well-formed XML role/continue output → `{ "action", "character" }`.
  static Map<String, dynamic>? tryParseStrictXmlRoleOrContinue(String raw) {
    final preprocessed = preprocessForXmlParse(raw);
    if (preprocessed.isEmpty) return null;
    try {
      final doc = XmlDocument.parse(preprocessed);
      final chat = doc.rootElement;
      if (chat.name.local != 'chat') return null;

      final action = _directChildText(chat, 'action');
      final character = _directChildText(chat, 'character');
      if (action == null || character == null) return null;
      return {
        'action': action,
        'character': character,
      };
    } catch (_) {
      return null;
    }
  }

  static String? _directChildText(XmlElement parent, String name) {
    for (final child in parent.childElements) {
      if (child.name.local == name) return child.innerText;
    }
    return null;
  }

  /// Ordered [ChatMockupAiFieldEvent] for director-style XML (`user` included).
  static List<ChatMockupAiFieldEvent> scanDirectorFieldsXml(
    String raw, {
    bool forStreamPreview = false,
  }) {
    final p = preprocessForXmlParse(raw);
    if (p.isEmpty || !p.contains('<turn')) return [];

    final out = <ChatMockupAiFieldEvent>[];
    var i = 0;
    while (i < p.length) {
      final turnStart = p.indexOf('<turn', i);
      if (turnStart < 0) break;

      final openEnd = p.indexOf('>', turnStart);
      if (openEnd < 0) {
        if (forStreamPreview) {
          _scanXmlFieldsInRange(
            p,
            turnStart,
            p.length,
            out,
            includeUser: true,
            forStreamPreview: true,
          );
        }
        break;
      }

      if (_isSelfClosingTagAt(p, turnStart, openEnd)) {
        i = openEnd + 1;
        continue;
      }

      const closeTag = '</turn>';
      final closeStart = p.indexOf(closeTag, openEnd + 1);
      final turnEnd = closeStart >= 0 ? closeStart : p.length;

      _scanXmlFieldsInRange(
        p,
        openEnd + 1,
        turnEnd,
        out,
        includeUser: true,
        forStreamPreview: forStreamPreview,
      );

      if (closeStart < 0) break;
      i = closeStart + closeTag.length;
    }

    return out;
  }

  /// Ordered events for role / continue XML (`<user>` recognized but not emitted).
  static List<ChatMockupAiFieldEvent> scanRoleOrContinueFieldsXml(
    String raw, {
    bool forStreamPreview = false,
  }) {
    final p = preprocessForXmlParse(raw);
    if (p.isEmpty || !p.contains('<chat')) return [];

    final chatStart = p.indexOf('<chat');
    if (chatStart < 0) return [];

    final chatOpenEnd = p.indexOf('>', chatStart);
    if (chatOpenEnd < 0) {
      if (forStreamPreview) {
        final out = <ChatMockupAiFieldEvent>[];
        _scanXmlFieldsInRange(
          p,
          chatStart,
          p.length,
          out,
          includeUser: false,
          forStreamPreview: true,
        );
        return out;
      }
      return [];
    }

    if (_isSelfClosingTagAt(p, chatStart, chatOpenEnd)) return [];

    const chatClose = '</chat>';
    final closeStart = p.indexOf(chatClose, chatOpenEnd + 1);
    final chatEnd = closeStart >= 0 ? closeStart : p.length;

    final out = <ChatMockupAiFieldEvent>[];
    _scanXmlFieldsInRange(
      p,
      chatOpenEnd + 1,
      chatEnd,
      out,
      includeUser: false,
      forStreamPreview: forStreamPreview,
    );
    return out;
  }

  /// Ordered [ChatMockupAiFieldEvent] for director-style output (`user` included).
  ///
  /// XML field scan first; falls back to legacy JSON key scan when XML yields nothing.
  ///
  /// [forStreamPreview]: when `true`, unterminated tag bodies still emit a prefix
  /// (streaming UI); finalize paths should use default `false`.
  static List<ChatMockupAiFieldEvent> scanDirectorFields(
    String raw, {
    bool forStreamPreview = false,
  }) {
    final xml = scanDirectorFieldsXml(
      raw,
      forStreamPreview: forStreamPreview,
    );
    if (xml.isNotEmpty) return xml;
    return _scanDirectorFieldsJson(
      raw,
      forStreamPreview: forStreamPreview,
    );
  }

  /// Ordered events for role / continue modes (XML first, then legacy JSON).
  static List<ChatMockupAiFieldEvent> scanRoleOrContinueFields(
    String raw, {
    bool forStreamPreview = false,
  }) {
    final xml = scanRoleOrContinueFieldsXml(
      raw,
      forStreamPreview: forStreamPreview,
    );
    if (xml.isNotEmpty) return xml;
    return _scanRoleOrContinueFieldsJson(
      raw,
      forStreamPreview: forStreamPreview,
    );
  }

  static List<ChatMockupAiFieldEvent> _scanDirectorFieldsJson(
    String raw, {
    bool forStreamPreview = false,
  }) {
    final p = preprocessForFieldScan(raw);
    return _scanMergedStrictAndLoose(
      p,
      includeUser: true,
      allowUnclosedQuotedValueAsPrefix: forStreamPreview,
    );
  }

  static List<ChatMockupAiFieldEvent> _scanRoleOrContinueFieldsJson(
    String raw, {
    bool forStreamPreview = false,
  }) {
    final p = preprocessForFieldScan(raw);
    return _scanMergedStrictAndLoose(
      p,
      includeUser: false,
      allowUnclosedQuotedValueAsPrefix: forStreamPreview,
    );
  }

  static const List<_XmlTagSpec> _directorXmlTags = [
    _XmlTagSpec('action', ChatMockupAiFieldKind.action),
    _XmlTagSpec('user', ChatMockupAiFieldKind.user),
    _XmlTagSpec('character', ChatMockupAiFieldKind.character),
  ];

  static const List<_XmlTagSpec> _roleXmlTags = [
    _XmlTagSpec('action', ChatMockupAiFieldKind.action),
    _XmlTagSpec('user', ChatMockupAiFieldKind.user),
    _XmlTagSpec('character', ChatMockupAiFieldKind.character),
  ];

  static void _scanXmlFieldsInRange(
    String s,
    int start,
    int end,
    List<ChatMockupAiFieldEvent> out, {
    required bool includeUser,
    required bool forStreamPreview,
  }) {
    final specs = includeUser ? _directorXmlTags : _roleXmlTags;
    var i = start;
    while (i < end) {
      int? nearestPos;
      ChatMockupAiFieldKind? nearestKind;
      String? nearestTag;

      for (final spec in specs) {
        if (!includeUser && spec.kind == ChatMockupAiFieldKind.user) {
          continue;
        }
        final tagOpen = '<${spec.tagName}';
        final pos = s.indexOf(tagOpen, i);
        if (pos < 0 || pos >= end) continue;
        if (nearestPos == null || pos < nearestPos) {
          nearestPos = pos;
          nearestKind = spec.kind;
          nearestTag = spec.tagName;
        }
      }

      if (nearestPos == null || nearestKind == null || nearestTag == null) {
        break;
      }

      final extracted = _extractXmlTagContent(
        s,
        nearestPos,
        end,
        nearestTag,
        forStreamPreview: forStreamPreview,
      );
      if (extracted == null) {
        i = nearestPos + 1;
        continue;
      }
      out.add(
          ChatMockupAiFieldEvent(kind: nearestKind, rawValue: extracted.$1));
      i = extracted.$2;
    }
  }

  /// Strict leaf-tag scan from [start] to [end]. Stops at the first incomplete tag
  /// (cursor stays at that tag's open) so streaming callers can resume on later feeds.
  static (List<ChatMockupAiFieldEvent>, int) scanXmlFieldsStrictFromPosition(
    String s,
    int start,
    int end, {
    required bool emitUser,
  }) {
    final out = <ChatMockupAiFieldEvent>[];
    var i = start;
    while (i < end) {
      int? nearestPos;
      ChatMockupAiFieldKind? nearestKind;
      String? nearestTag;

      for (final spec in _directorXmlTags) {
        final tagOpen = '<${spec.tagName}';
        final pos = s.indexOf(tagOpen, i);
        if (pos < 0 || pos >= end) continue;
        if (nearestPos == null || pos < nearestPos) {
          nearestPos = pos;
          nearestKind = spec.kind;
          nearestTag = spec.tagName;
        }
      }

      if (nearestPos == null || nearestKind == null || nearestTag == null) {
        break;
      }

      final extracted = _extractXmlTagContent(
        s,
        nearestPos,
        end,
        nearestTag,
        forStreamPreview: false,
      );
      if (extracted == null) {
        break;
      }

      if (nearestKind == ChatMockupAiFieldKind.user && !emitUser) {
        i = extracted.$2;
        continue;
      }

      out.add(
        ChatMockupAiFieldEvent(kind: nearestKind, rawValue: extracted.$1),
      );
      i = extracted.$2;
    }
    return (out, i);
  }

  static bool _isSelfClosingTagAt(String s, int tagStart, int gtIndex) {
    var j = gtIndex - 1;
    while (j > tagStart && _isWs(s.codeUnitAt(j))) {
      j--;
    }
    return j >= tagStart && s.codeUnitAt(j) == 47;
  }

  static bool _isWs(int c) => c == 32 || c == 9 || c == 10 || c == 13;

  /// Returns decoded body and index after the tag (or range end for stream prefix).
  static (String, int)? _extractXmlTagContent(
    String s,
    int tagStart,
    int rangeEnd,
    String tagName, {
    required bool forStreamPreview,
  }) {
    final openPrefix = '<$tagName';
    if (!s.startsWith(openPrefix, tagStart)) return null;

    var j = tagStart + openPrefix.length;
    while (j < rangeEnd && j < s.length && s.codeUnitAt(j) != 62) {
      j++;
    }
    if (j >= s.length || j >= rangeEnd) {
      if (forStreamPreview) return ('', rangeEnd);
      return null;
    }

    if (_isSelfClosingTagAt(s, tagStart, j)) {
      return ('', j + 1);
    }

    j++;

    const cdataStart = '<![CDATA[';
    if (s.startsWith(cdataStart, j)) {
      const cdataEnd = ']]>';
      final contentStart = j + cdataStart.length;
      final endIdx = s.indexOf(cdataEnd, contentStart);
      if (endIdx >= 0 && endIdx < rangeEnd) {
        final afterCdata = endIdx + cdataEnd.length;
        final closeTag = '</$tagName>';
        final closeIdx = s.indexOf(closeTag, afterCdata);
        if (closeIdx >= 0 && closeIdx < rangeEnd) {
          return (s.substring(contentStart, endIdx), closeIdx + closeTag.length);
        }
        return null;
      }
      if (forStreamPreview) {
        final contentEnd = rangeEnd < s.length ? rangeEnd : s.length;
        return (s.substring(contentStart, contentEnd), contentEnd);
      }
      return null;
    }

    final closeTag = '</$tagName>';
    final closeIdx = s.indexOf(closeTag, j);
    if (closeIdx >= 0 && closeIdx < rangeEnd) {
      return (
        _decodeXmlTextEntities(s.substring(j, closeIdx)),
        closeIdx + closeTag.length,
      );
    }

    if (forStreamPreview) {
      final contentEnd = rangeEnd < s.length ? rangeEnd : s.length;
      return (
        _decodeXmlTextEntities(s.substring(j, contentEnd)),
        contentEnd,
      );
    }
    return null;
  }

  /// Decodes standard XML entities in plain (non-CDATA) tag text.
  static String _decodeXmlTextEntities(String text) {
    if (!text.contains('&')) return text;
    final buf = StringBuffer();
    var i = 0;
    while (i < text.length) {
      if (text.codeUnitAt(i) == 38) {
        final semi = text.indexOf(';', i + 1);
        if (semi > i) {
          final entity = text.substring(i, semi + 1);
          final decoded = _decodeSingleXmlEntity(entity);
          if (decoded != null) {
            buf.write(decoded);
            i = semi + 1;
            continue;
          }
        }
      }
      buf.writeCharCode(text.codeUnitAt(i));
      i++;
    }
    return buf.toString();
  }

  static String? _decodeSingleXmlEntity(String entity) {
    switch (entity) {
      case '&lt;':
        return '<';
      case '&gt;':
        return '>';
      case '&amp;':
        return '&';
      case '&quot;':
        return '"';
      case '&apos;':
        return "'";
      default:
        if (entity.startsWith('&#x') && entity.endsWith(';')) {
          final hex = entity.substring(3, entity.length - 1);
          final code = int.tryParse(hex, radix: 16);
          if (code != null) return String.fromCharCode(code);
        } else if (entity.startsWith('&#') && entity.endsWith(';')) {
          final digits = entity.substring(2, entity.length - 1);
          final code = int.tryParse(digits);
          if (code != null) return String.fromCharCode(code);
        }
        return null;
    }
  }

  /// Longer keys first so `"character"` does not lose to a shorter prefix.
  static const List<_KeySpec> _keySpecsDirector = [
    _KeySpec('character', ChatMockupAiFieldKind.character),
    _KeySpec('assistant', ChatMockupAiFieldKind.character),
    _KeySpec('action', ChatMockupAiFieldKind.action),
    _KeySpec('user', ChatMockupAiFieldKind.user),
    _KeySpec('用户', ChatMockupAiFieldKind.user),
    _KeySpec('left', ChatMockupAiFieldKind.character),
    _KeySpec('消息左', ChatMockupAiFieldKind.character),
    _KeySpec('动作', ChatMockupAiFieldKind.action),
  ];

  static const List<_KeySpec> _keySpecsRole = [
    _KeySpec('character', ChatMockupAiFieldKind.character),
    _KeySpec('assistant', ChatMockupAiFieldKind.character),
    _KeySpec('action', ChatMockupAiFieldKind.action),
    _KeySpec('user', ChatMockupAiFieldKind.user),
    _KeySpec('用户', ChatMockupAiFieldKind.user),
    _KeySpec('left', ChatMockupAiFieldKind.character),
    _KeySpec('消息左', ChatMockupAiFieldKind.character),
    _KeySpec('动作', ChatMockupAiFieldKind.action),
  ];

  /// One pass: outside JSON-ish strings, try strict `"key":"value"` then loose
  /// key forms at the same cursor so formats can mix in one buffer.
  static List<ChatMockupAiFieldEvent> _scanMergedStrictAndLoose(
    String s, {
    required bool includeUser,
    required bool allowUnclosedQuotedValueAsPrefix,
  }) {
    final specs = includeUser ? _keySpecsDirector : _keySpecsRole;
    final out = <ChatMockupAiFieldEvent>[];
    var i = 0;
    var inString = false;
    var escape = false;

    while (i < s.length) {
      final c = s.codeUnitAt(i);

      if (inString) {
        if (escape) {
          escape = false;
          i++;
          continue;
        }
        if (c == 92) {
          escape = true;
          i++;
          continue;
        }
        if (c == 34) {
          inString = false;
        }
        i++;
        continue;
      }

      final j = _skipWs(s, i);
      if (j > i) {
        i = j;
        continue;
      }

      if (s.codeUnitAt(i) == 34) {
        final strictRes = _tryStrictQuotedKeyValue(
          s,
          i,
          specs,
          allowUnclosedQuotedValueAsPrefix,
        );
        if (strictRes != null) {
          out.add(strictRes.$1);
          i = strictRes.$2;
          continue;
        }
        final looseAtQuote = _tryLooseKeyValueAt(
          s,
          i,
          specs,
          allowUnclosedQuotedValueAsPrefix,
        );
        if (looseAtQuote != null) {
          out.add(looseAtQuote.$1);
          i = looseAtQuote.$2;
          continue;
        }
        inString = true;
        i++;
        continue;
      }

      final looseRes = _tryLooseKeyValueAt(
        s,
        i,
        specs,
        allowUnclosedQuotedValueAsPrefix,
      );
      if (looseRes != null) {
        out.add(looseRes.$1);
        i = looseRes.$2;
        continue;
      }

      i++;
    }

    return out;
  }

  static (ChatMockupAiFieldEvent, int)? _tryStrictQuotedKeyValue(
    String s,
    int openQuote,
    List<_KeySpec> specs,
    bool allowUnclosedQuotedValueAsPrefix,
  ) {
    final match = _matchKeyAt(s, openQuote, specs);
    if (match == null) return null;
    final kind = match.kind;
    var j = match.indexAfterKeyQuote;
    j = _skipWs(s, j);
    if (j >= s.length || s.codeUnitAt(j) != 58) return null;
    j++;
    j = _skipWs(s, j);
    if (j >= s.length || s.codeUnitAt(j) != 34) return null;
    j++;
    final parsed = _parseJsonStringValue(
      s,
      j,
      allowUnclosedPrefix: allowUnclosedQuotedValueAsPrefix,
    );
    if (parsed == null) return null;
    return (
      ChatMockupAiFieldEvent(kind: kind, rawValue: parsed.$1),
      parsed.$2,
    );
  }

  static (ChatMockupAiFieldEvent, int)? _tryLooseKeyValueAt(
    String s,
    int i,
    List<_KeySpec> specs,
    bool allowUnclosedQuotedValueAsPrefix,
  ) {
    final m = _tryLooseMatchKey(s, i, specs);
    if (m == null) return null;
    final kind = m.$1;
    var j = _skipWs(s, m.$2);
    if (j >= s.length || s.codeUnitAt(j) != 58) return null;
    j++;
    j = _skipWs(s, j);
    final parsed = _parseLooseValue(
      s,
      j,
      allowUnclosedQuotedValueAsPrefix: allowUnclosedQuotedValueAsPrefix,
    );
    if (parsed == null) return null;
    return (
      ChatMockupAiFieldEvent(kind: kind, rawValue: parsed.$1),
      parsed.$2,
    );
  }

  /// Returns `(kind, indexAfterKeyToken)` where next non-ws should be `:`.
  static (ChatMockupAiFieldKind, int)? _tryLooseMatchKey(
    String s,
    int i,
    List<_KeySpec> specs,
  ) {
    for (final spec in specs) {
      final key = spec.key;
      final kind = spec.kind;

      if (s.codeUnitAt(i) == 39 &&
          i + 1 + key.length + 1 <= s.length &&
          s.startsWith(key, i + 1) &&
          s.codeUnitAt(i + 1 + key.length) == 39) {
        return (kind, i + 1 + key.length + 1);
      }

      if (s.codeUnitAt(i) == 34 &&
          i + 1 + key.length + 1 <= s.length &&
          s.startsWith(key, i + 1) &&
          s.codeUnitAt(i + 1 + key.length) == 34) {
        return (kind, i + 1 + key.length + 1);
      }

      if (i + key.length <= s.length &&
          s.startsWith(key, i) &&
          _looseKeyLeftBoundaryOk(s, i) &&
          _looseKeyRightBoundaryOk(s, i + key.length)) {
        return (kind, i + key.length);
      }
    }
    return null;
  }

  static bool _looseKeyLeftBoundaryOk(String s, int i) {
    if (i == 0) return true;
    return !_isAsciiIdUnit(s.codeUnitAt(i - 1));
  }

  static bool _looseKeyRightBoundaryOk(String s, int afterKey) {
    if (afterKey >= s.length) return false;
    final c = s.codeUnitAt(afterKey);
    return c == 58 || c == 32 || c == 9 || c == 10 || c == 13;
  }

  static bool _isAsciiIdUnit(int c) {
    return (c >= 0x41 && c <= 0x5a) ||
        (c >= 0x61 && c <= 0x7a) ||
        (c >= 0x30 && c <= 0x39) ||
        c == 0x5f;
  }

  static (String, int)? _parseLooseValue(
    String s,
    int start, {
    required bool allowUnclosedQuotedValueAsPrefix,
  }) {
    if (start >= s.length) return null;
    final c0 = s.codeUnitAt(start);
    if (c0 == 34) {
      return _parseJsonStringValue(
        s,
        start + 1,
        allowUnclosedPrefix: allowUnclosedQuotedValueAsPrefix,
      );
    }
    if (c0 == 39) {
      return _parseSingleQuotedStringValue(
        s,
        start + 1,
        allowUnclosedPrefix: allowUnclosedQuotedValueAsPrefix,
      );
    }
    return _parseBareLooseValue(s, start);
  }

  /// Single-quoted JSON-ish string; `\'` and `\\` supported.
  static (String, int)? _parseSingleQuotedStringValue(
    String s,
    int start, {
    required bool allowUnclosedPrefix,
  }) {
    final buf = StringBuffer();
    var i = start;
    var escape = false;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (escape) {
        if (c == 39) {
          buf.writeCharCode(39);
        } else if (c == 92) {
          buf.writeCharCode(92);
        } else {
          buf.writeCharCode(c);
        }
        escape = false;
        i++;
        continue;
      }
      if (c == 92) {
        escape = true;
        i++;
        continue;
      }
      if (c == 39) {
        return (buf.toString(), i + 1);
      }
      buf.writeCharCode(c);
      i++;
    }
    if (allowUnclosedPrefix) {
      return (buf.toString(), s.length);
    }
    return null;
  }

  /// Unquoted value until newline, `,`, `}`, or `]` (trimmed).
  static (String, int)? _parseBareLooseValue(String s, int start) {
    var i = start;
    final buf = StringBuffer();
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 10 || c == 13) {
        break;
      }
      if (c == 44 || c == 125 || c == 93) {
        break;
      }
      buf.writeCharCode(c);
      i++;
    }
    final text = buf.toString().trim();
    if (text.isEmpty) return null;
    return (text, i);
  }

  static _KeyMatch? _matchKeyAt(String s, int openQuote, List<_KeySpec> specs) {
    for (final spec in specs) {
      final key = spec.key;
      final need = 1 + key.length + 1;
      if (openQuote + need > s.length) continue;
      if (!s.startsWith(key, openQuote + 1)) continue;
      if (s.codeUnitAt(openQuote + 1 + key.length) != 34) continue;
      return _KeyMatch(spec.kind, openQuote + need);
    }
    return null;
  }

  static int _skipWs(String s, int from) {
    var pos = from;
    while (pos < s.length) {
      final u = s.codeUnitAt(pos);
      if (u == 32 || u == 9 || u == 10 || u == 13) {
        pos++;
      } else {
        break;
      }
    }
    return pos;
  }

  /// [start] = first code unit inside the string (after opening `"`).
  ///
  /// When [allowUnclosedPrefix] is `false` (finalize / strict scan), returns
  /// `null` if the closing `"` is missing. When `true` (streaming preview), returns
  /// the decoded prefix and [s.length] as end index so the UI can update before the
  /// value is complete.
  static (String, int)? _parseJsonStringValue(
    String s,
    int start, {
    bool allowUnclosedPrefix = false,
  }) {
    final buf = StringBuffer();
    var i = start;
    var escape = false;
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (escape) {
        if (c == 34) {
          buf.writeCharCode(34);
        } else if (c == 92) {
          buf.writeCharCode(92);
        } else if (c == 47) {
          buf.writeCharCode(47);
        } else if (c == 98) {
          buf.writeCharCode(8);
        } else if (c == 102) {
          buf.writeCharCode(12);
        } else if (c == 110) {
          buf.writeCharCode(10);
        } else if (c == 114) {
          buf.writeCharCode(13);
        } else if (c == 116) {
          buf.writeCharCode(9);
        } else if (c == 117) {
          if (i + 4 >= s.length) {
            if (allowUnclosedPrefix) {
              return (buf.toString(), s.length);
            }
            return null;
          }
          final hex = s.substring(i + 1, i + 5);
          final code = int.tryParse(hex, radix: 16);
          if (code == null) {
            if (allowUnclosedPrefix) {
              return (buf.toString(), s.length);
            }
            return null;
          }
          buf.writeCharCode(code);
          i += 4;
        } else {
          buf.writeCharCode(c);
        }
        escape = false;
        i++;
        continue;
      }
      if (c == 92) {
        escape = true;
        i++;
        continue;
      }
      if (c == 34) {
        return (buf.toString(), i + 1);
      }
      buf.writeCharCode(c);
      i++;
    }
    if (allowUnclosedPrefix) {
      return (buf.toString(), s.length);
    }
    return null;
  }

  static String _repairJsonTailForPreview(String raw) {
    var t = raw;
    if (t.startsWith('```')) {
      final fenceEnd = t.indexOf('\n');
      if (fenceEnd >= 0) {
        t = t.substring(fenceEnd + 1);
      }
    }
    if (t.endsWith('```')) {
      t = t.substring(0, t.length - 3).trimRight();
    }
    final start = t.indexOf('{');
    if (start < 0) {
      return t.trim();
    }
    t = t.substring(start);
    return _normalizeBracketPreview(t);
  }

  /// Single pass: copy output, skip excess `}`/`]`, strip `,` before closes,
  /// append missing closers.
  static String _normalizeBracketPreview(String insideFromBrace) {
    final stack = <int>[];
    final out = <int>[];
    var inString = false;
    var escape = false;

    void stripStructuralTrailingCommaWs() {
      while (out.isNotEmpty) {
        final c = out.last;
        if (c == 32 || c == 9 || c == 10 || c == 13) {
          out.removeLast();
        } else if (c == 44) {
          out.removeLast();
          while (out.isNotEmpty) {
            final c2 = out.last;
            if (c2 == 32 || c2 == 9 || c2 == 10 || c2 == 13) {
              out.removeLast();
            } else {
              break;
            }
          }
          break;
        } else {
          break;
        }
      }
    }

    for (var i = 0; i < insideFromBrace.length; i++) {
      final c = insideFromBrace.codeUnitAt(i);
      if (escape) {
        out.add(c);
        escape = false;
        continue;
      }
      if (c == 92 && inString) {
        out.add(c);
        escape = true;
        continue;
      }
      if (c == 34) {
        out.add(c);
        inString = !inString;
        continue;
      }
      if (inString) {
        out.add(c);
        continue;
      }

      if (c == 123) {
        stack.add(123);
        out.add(c);
      } else if (c == 91) {
        stack.add(91);
        out.add(c);
      } else if (c == 125) {
        if (stack.isNotEmpty && stack.last == 123) {
          stripStructuralTrailingCommaWs();
          stack.removeLast();
          out.add(c);
        }
        // excess `}` — omit
      } else if (c == 93) {
        if (stack.isNotEmpty && stack.last == 91) {
          stripStructuralTrailingCommaWs();
          stack.removeLast();
          out.add(c);
        }
        // excess `]` — omit
      } else {
        out.add(c);
      }
    }

    while (stack.isNotEmpty) {
      stripStructuralTrailingCommaWs();
      final open = stack.removeLast();
      out.add(open == 123 ? 125 : 93);
    }
    return String.fromCharCodes(out);
  }
}

/// Incremental strict XML field parser for live AI streaming (closed leaf tags only).
///
/// [feed] returns only newly completed `action` / `user` / `character` events since the
/// previous call. Director mode emits [ChatMockupAiFieldKind.user]; role/continue
/// still scans past closed `<user>` tags without emitting them.
class ChatMockupAiXmlStreamFieldParser {
  ChatMockupAiXmlStreamFieldParser({required this.directorMode});

  final bool directorMode;
  int _scanCursor = 0;
  String? _lastPreprocessed;

  List<ChatMockupAiFieldEvent> feed(String accumulatedRaw) {
    final p = ChatMockupAiStreamPreview.preprocessForXmlParse(accumulatedRaw);
    if (_lastPreprocessed != null) {
      if (p.length < _scanCursor) {
        _scanCursor = 0;
      } else if (_scanCursor > 0) {
        final prior = _lastPreprocessed!;
        final compareLen = _scanCursor.clamp(0, prior.length).clamp(0, p.length);
        if (compareLen > 0 && p.substring(0, compareLen) != prior.substring(0, compareLen)) {
          _scanCursor = 0;
        }
      }
    }
    _lastPreprocessed = p;
    if (p.isEmpty || _scanCursor >= p.length) {
      return const [];
    }

    final (events, newCursor) = ChatMockupAiStreamPreview.scanXmlFieldsStrictFromPosition(
      p,
      _scanCursor,
      p.length,
      emitUser: directorMode,
    );
    _scanCursor = newCursor;
    return events;
  }
}

/// Placement for a streamed chat row (canvas maps to [ChatMockupItemSide]).
enum ChatMockupAiStreamItemSide {
  left,
  right,
  center,
}

/// One chat row to append during XML streaming (maps to [ChatMockupItem] in canvas).
class ChatMockupAiStreamItemDescriptor {
  const ChatMockupAiStreamItemDescriptor({
    required this.lineKey,
    required this.isAction,
    required this.side,
    required this.text,
  });

  final String lineKey;
  final bool isAction;
  final ChatMockupAiStreamItemSide side;
  final String text;
}

/// Maps field events to appendable stream rows (40 total cap; continue: 5 left lines).
List<ChatMockupAiStreamItemDescriptor> streamItemDescriptorsFromFieldEvents(
  List<ChatMockupAiFieldEvent> events, {
  required int startFieldIndex,
  required bool directorMode,
  bool continueMode = false,
  int totalItemQuotaRemaining = 40,
  int? continueLeftQuotaRemaining,
}) {
  final lines = <ChatMockupAiStreamItemDescriptor>[];
  var leftLinesUsed = 0;
  final capLeft = continueMode
      ? (continueLeftQuotaRemaining ?? 5)
      : null;
  for (var ei = 0; ei < events.length; ei++) {
    final fieldIndex = startFieldIndex + ei;
    final e = events[ei];
    switch (e.kind) {
      case ChatMockupAiFieldKind.action:
        var j = 0;
        for (final line in _splitStreamMessageLines(e.rawValue)) {
          if (lines.length >= totalItemQuotaRemaining) return lines;
          lines.add(
            ChatMockupAiStreamItemDescriptor(
              lineKey: 'f${fieldIndex}_a$j',
              isAction: true,
              side: ChatMockupAiStreamItemSide.center,
              text: line,
            ),
          );
          j++;
        }
      case ChatMockupAiFieldKind.user:
        if (!directorMode) {
          break;
        }
        var j = 0;
        for (final line in _splitStreamMessageLines(e.rawValue)) {
          if (lines.length >= totalItemQuotaRemaining) return lines;
          lines.add(
            ChatMockupAiStreamItemDescriptor(
              lineKey: 'f${fieldIndex}_u$j',
              isAction: false,
              side: ChatMockupAiStreamItemSide.right,
              text: line,
            ),
          );
          j++;
        }
      case ChatMockupAiFieldKind.character:
        var j = 0;
        for (final line in _splitStreamMessageLines(e.rawValue)) {
          if (lines.length >= totalItemQuotaRemaining) return lines;
          if (capLeft != null && leftLinesUsed >= capLeft) {
            return lines;
          }
          lines.add(
            ChatMockupAiStreamItemDescriptor(
              lineKey: 'f${fieldIndex}_c$j',
              isAction: false,
              side: ChatMockupAiStreamItemSide.left,
              text: line,
            ),
          );
          j++;
          if (capLeft != null) {
            leftLinesUsed++;
          }
        }
    }
  }
  return lines;
}

List<String> _splitStreamMessageLines(String value) {
  return value
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

class _KeySpec {
  const _KeySpec(this.key, this.kind);

  final String key;
  final ChatMockupAiFieldKind kind;
}

class _KeyMatch {
  const _KeyMatch(this.kind, this.indexAfterKeyQuote);

  final ChatMockupAiFieldKind kind;
  final int indexAfterKeyQuote;
}

class _XmlTagSpec {
  const _XmlTagSpec(this.tagName, this.kind);

  final String tagName;
  final ChatMockupAiFieldKind kind;
}
