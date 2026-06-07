import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/models/discussion.dart';

const _videoPayloadType = 'inter-knot-video';
const _videoPayloadVersion = 1;
const _videoPayloadEncodedPrefix = 'IKV1:gzip+b64:';
const maxInlinePayloadChars = 60000;

typedef VideoPayloadEncodeResult = ({
  String encoded,
  int jsonChars,
  int compressedBytes,
  int base64Chars,
});

String encodeVideoPayload(Map<String, dynamic> payload) {
  return encodeVideoPayloadWithStats(payload).encoded;
}

VideoPayloadEncodeResult encodeVideoPayloadWithStats(
  Map<String, dynamic> payload,
) {
  final jsonText = jsonEncode(payload);
  final jsonBytes = utf8.encode(jsonText);
  final compressed = const GZipEncoder().encode(jsonBytes);
  final base64Text = base64Encode(compressed);
  return (
    encoded: '$_videoPayloadEncodedPrefix$base64Text',
    jsonChars: jsonText.length,
    compressedBytes: compressed.length,
    base64Chars: base64Text.length,
  );
}

String wrapEncodedPayload(String encoded) => '{$encoded}';

Map<String, dynamic> decodeVideoPayload(String encoded) {
  final decoded = jsonDecode(_decodeVideoPayloadJsonText(encoded));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('影片 payload 不是 JSON 对象');
  }
  _validateVideoPayload(decoded);
  return decoded;
}

String _decodeVideoPayloadJsonText(String encoded) {
  final normalized = encoded.trim();
  if (normalized.startsWith(_videoPayloadEncodedPrefix)) {
    final payloadBase64 =
        normalized.substring(_videoPayloadEncodedPrefix.length);
    final compressedBytes = base64Decode(payloadBase64);
    final uncompressedBytes = const GZipDecoder().decodeBytes(compressedBytes);
    return utf8.decode(uncompressedBytes);
  }
  final first = utf8.decode(base64Decode(normalized));
  final second = utf8.decode(base64Decode(first));
  return utf8.decode(base64Decode(second));
}

typedef GistRawUrlNormalizeResult = ({
  String? rawUrl,
  String? error,
});

({
  String description,
  String? encodedPayload,
  String? gistRawUrl,
  String? gistUrlError
}) extractVideoBodyParts(
  String bodyText,
) {
  final match = RegExp(r'\{([^{}\s]+)\}\s*$').firstMatch(bodyText);
  if (match != null) {
    final encoded = match.group(1)?.trim();
    final description = bodyText.substring(0, match.start).trim();
    return (
      description: description,
      encodedPayload: encoded,
      gistRawUrl: null,
      gistUrlError: null,
    );
  }
  final trailingLink = _extractTrailingLinkToken(bodyText);
  if (trailingLink == null) {
    return (
      description: bodyText.trim(),
      encodedPayload: null,
      gistRawUrl: null,
      gistUrlError: null,
    );
  }
  final normalized = normalizeVideoPayloadGistRawUrlDetailed(trailingLink.url);
  if (normalized.rawUrl == null) {
    if (!_looksLikeGistLink(trailingLink.url)) {
      return (
        description: bodyText.trim(),
        encodedPayload: null,
        gistRawUrl: null,
        gistUrlError: null,
      );
    }
    return (
      description: bodyText.substring(0, trailingLink.start).trim(),
      encodedPayload: null,
      gistRawUrl: null,
      gistUrlError: normalized.error,
    );
  }
  final description = bodyText.substring(0, trailingLink.start).trim();
  return (
    description: description,
    encodedPayload: null,
    gistRawUrl: normalized.rawUrl,
    gistUrlError: null,
  );
}

String? normalizeVideoPayloadGistRawUrl(String? urlText) {
  return normalizeVideoPayloadGistRawUrlDetailed(urlText).rawUrl;
}

GistRawUrlNormalizeResult normalizeVideoPayloadGistRawUrlDetailed(
    String? urlText) {
  final raw = urlText?.trim() ?? '';
  if (raw.isEmpty) {
    return (rawUrl: null, error: '链接为空');
  }
  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return (rawUrl: null, error: '链接格式无效');
  }
  if (uri.scheme.toLowerCase() != 'https') {
    return (rawUrl: null, error: '仅支持 https 链接');
  }
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (host == 'gist.githubusercontent.com') {
    if (segments.length < 2) {
      return (rawUrl: null, error: 'gist raw 链接缺少 owner 或 gist id');
    }
    if (segments.length >= 3 && segments[2] == 'raw') {
      return (
        rawUrl: uri.replace(query: '', fragment: '').toString(),
        error: null,
      );
    }
    final owner = segments[0];
    final gistId = segments[1];
    return (
      rawUrl: Uri.https(
        'gist.githubusercontent.com',
        '/$owner/$gistId/raw',
      ).toString(),
      error: null,
    );
  }
  if (host == 'gist.github.com') {
    if (segments.length < 2) {
      return (rawUrl: null, error: 'gist 页面链接缺少 owner 或 gist id');
    }
    final owner = segments[0];
    final gistId = segments[1];
    return (
      rawUrl: Uri.https(
        'gist.githubusercontent.com',
        '/$owner/$gistId/raw',
      ).toString(),
      error: null,
    );
  }
  return (
    rawUrl: null,
    error: '仅支持 gist.github.com 或 gist.githubusercontent.com'
  );
}

String? extractEncodedPayloadToken(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final wrapped = RegExp(r'^\{([^{}\s]+)\}$').firstMatch(trimmed);
  if (wrapped != null) return wrapped.group(1)?.trim();
  final fromBody = extractVideoBodyParts(trimmed).encodedPayload;
  if (fromBody != null && fromBody.isNotEmpty) return fromBody;
  if (trimmed.contains(RegExp(r'\s'))) return null;
  return trimmed;
}

({String url, int start})? _extractTrailingLinkToken(String bodyText) {
  final markdownLink =
      RegExp(r'\[[^\]]+\]\((https?://[^\s)]+)\)\s*$').firstMatch(bodyText);
  if (markdownLink != null) {
    final url = markdownLink.group(1)?.trim();
    if (url != null && url.isNotEmpty) {
      return (url: url, start: markdownLink.start);
    }
  }
  final autoLink = RegExp(r'<(https?://[^>\s]+)>\s*$').firstMatch(bodyText);
  if (autoLink != null) {
    final url = autoLink.group(1)?.trim();
    if (url != null && url.isNotEmpty) {
      return (url: url, start: autoLink.start);
    }
  }
  final bareLink = RegExp(r'(https?://[^\s]+)\s*$').firstMatch(bodyText);
  if (bareLink != null) {
    final url = bareLink.group(1)?.trim();
    if (url != null && url.isNotEmpty) {
      return (url: url, start: bareLink.start);
    }
  }
  return null;
}

bool _looksLikeGistLink(String urlText) {
  final uri = Uri.tryParse(urlText.trim());
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'gist.github.com' || host == 'gist.githubusercontent.com';
}

bool isVideoDiscussionPayload(Map<String, dynamic> payload) {
  try {
    _validateVideoPayload(payload);
    return true;
  } catch (_) {
    return false;
  }
}

enum _CompactContext { root, chatMockup, item, ai, generic }

bool _isDefaultWaitValue(dynamic value) {
  if (value is! Map) return false;
  final mode = value['mode'];
  final seconds = value['seconds'];
  return mode == 'auto' && (seconds == 0 || seconds == 0.0);
}

bool _isRequiredKey(String key, _CompactContext context) {
  switch (context) {
    case _CompactContext.root:
      return key == 'type' ||
          key == 'version' ||
          key == 'chatMockup' ||
          key == 'ai';
    case _CompactContext.chatMockup:
      return key == 'version' || key == 'items';
    case _CompactContext.item:
      return key == 'type' || key == 'side' || key == 'id';
    case _CompactContext.ai:
      return key == 'rolePrompt' || key == 'userPrompt';
    case _CompactContext.generic:
      return false;
  }
}

_CompactContext _childContext(_CompactContext parent, String key) {
  switch (parent) {
    case _CompactContext.root:
      if (key == 'chatMockup') return _CompactContext.chatMockup;
      if (key == 'ai') return _CompactContext.ai;
      return _CompactContext.generic;
    case _CompactContext.chatMockup:
      return _CompactContext.generic;
    case _CompactContext.item:
      return _CompactContext.generic;
    case _CompactContext.ai:
      return _CompactContext.generic;
    case _CompactContext.generic:
      return _CompactContext.generic;
  }
}

dynamic _compactPublishValue(
  dynamic value, {
  required _CompactContext context,
  String? parentKey,
}) {
  if (value == null) return null;

  if (value is String) {
    return value.isEmpty ? null : value;
  }

  if (value is List) {
    if (context == _CompactContext.chatMockup && parentKey == 'items') {
      return value
          .map(
            (element) => _compactPublishValue(
              element,
              context: _CompactContext.item,
            ),
          )
          .toList();
    }
    final compacted = <dynamic>[];
    for (final element in value) {
      final next =
          _compactPublishValue(element, context: _CompactContext.generic);
      if (next != null) {
        compacted.add(next);
      }
    }
    return compacted.isEmpty ? null : compacted;
  }

  if (value is Map) {
    if (parentKey == 'wait' && _isDefaultWaitValue(value)) {
      return null;
    }
    final map = Map<String, dynamic>.from(value);
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final childContext =
          context == _CompactContext.chatMockup && entry.key == 'items'
              ? _CompactContext.chatMockup
              : _childContext(context, entry.key);
      final compacted = _compactPublishValue(
        entry.value,
        context: childContext,
        parentKey: entry.key,
      );
      if (_isRequiredKey(entry.key, context)) {
        if (entry.key == 'id' && compacted == null) {
          result[entry.key] = '';
        } else if (entry.key == 'items' && compacted == null) {
          result[entry.key] = <dynamic>[];
        } else if (context == _CompactContext.ai &&
            (entry.key == 'rolePrompt' || entry.key == 'userPrompt') &&
            compacted == null) {
          result[entry.key] =
              entry.value is String ? entry.value as String : '';
        } else if (entry.key == 'ai' &&
            context == _CompactContext.root &&
            compacted == null) {
          result[entry.key] = <String, dynamic>{
            'rolePrompt': '',
            'userPrompt': '',
          };
        } else {
          result[entry.key] = compacted ?? entry.value;
        }
      } else if (compacted != null) {
        result[entry.key] = compacted;
      }
    }
    return result.isEmpty && context == _CompactContext.generic ? null : result;
  }

  return value;
}

/// Strips null/empty/default fields from a video upload payload (deep copy).
Map<String, dynamic> compactVideoUploadPayload(Map<String, dynamic> payload) {
  final compacted =
      _compactPublishValue(payload, context: _CompactContext.root);
  if (compacted is! Map<String, dynamic>) {
    return Map<String, dynamic>.from(payload);
  }
  return compacted;
}

Map<String, dynamic> buildVideoUploadPayload({
  required Map<String, dynamic> chatMockup,
  required String rolePrompt,
  required String userPrompt,
}) {
  return compactVideoUploadPayload(<String, dynamic>{
    'type': _videoPayloadType,
    'version': _videoPayloadVersion,
    'chatMockup': chatMockup,
    'ai': {
      'rolePrompt': rolePrompt,
      'userPrompt': userPrompt,
    },
  });
}

void ensureIsVideoDiscussion(DiscussionModel discussion) {
  if (discussion.categoryName?.trim() != videoDiscussionCategoryName) {
    throw const FormatException('不是影片分类讨论');
  }
}

void _validateVideoPayload(Map<String, dynamic> payload) {
  if (payload['type'] != _videoPayloadType) {
    throw const FormatException('影片 payload type 不匹配');
  }
  if (payload['version'] != _videoPayloadVersion) {
    throw const FormatException('影片 payload version 不匹配');
  }
  final chatMockup = payload['chatMockup'];
  if (chatMockup is! Map<String, dynamic>) {
    throw const FormatException('chatMockup 缺失');
  }
  final items = chatMockup['items'];
  if (items is! List) {
    throw const FormatException('chatMockup.items 缺失');
  }
}
