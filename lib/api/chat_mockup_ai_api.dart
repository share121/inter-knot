import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ChatMockupAiApi {
  const ChatMockupAiApi();

  Uri debugNormalizeEndpoint(String endpoint) => _normalizeEndpoint(endpoint);

  Uri _normalizeEndpoint(String endpoint) {
    var raw = endpoint.trim();
    if (raw.isEmpty) {
      throw const FormatException('接口地址为空');
    }
    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'https://$raw';
    }
    final uri = Uri.parse(raw);
    final path = uri.path;
    final normalizedPath =
        path.endsWith('/') ? path.substring(0, path.length - 1) : path;
    if (normalizedPath.endsWith('/chat/completions')) {
      return uri.replace(path: normalizedPath);
    }
    return uri.replace(path: '$normalizedPath/chat/completions');
  }

  Future<String> createChatCompletion({
    required String endpoint,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.8,
  }) async {
    final uri = _normalizeEndpoint(endpoint);
    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'content-type': 'application/json',
              if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'temperature': temperature,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const FormatException('请求超时（60s）');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
          '请求失败: HTTP ${response.statusCode} ${response.body}');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('响应不是 JSON 对象');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('响应缺少 choices');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('响应 choices[0] 非对象');
    }
    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('响应缺少 message');
    }
    final content = message['content'];
    if (content is! String) {
      throw const FormatException('响应缺少 content');
    }
    return content;
  }

  /// Yields incremental assistant text from OpenAI-compatible streaming APIs.
  ///
  /// Timeouts: [connectionTimeout] for TCP/TLS + headers; [idleTimeout] between
  /// chunks; [maxDuration] hard cap for the whole stream.
  ///
  /// When [httpClient] is provided, this method does **not** close it; the caller
  /// should close it (e.g. on widget dispose) to abort an in-flight stream.
  Stream<String> createChatCompletionStream({
    required String endpoint,
    required String apiKey,
    required String model,
    required List<Map<String, String>> messages,
    double temperature = 0.8,
    Duration connectionTimeout = const Duration(seconds: 20),
    Duration idleTimeout = const Duration(seconds: 30),
    Duration maxDuration = const Duration(seconds: 180),
    http.Client? httpClient,
  }) async* {
    final uri = _normalizeEndpoint(endpoint);
    final client = httpClient ?? http.Client();
    final ownsClient = httpClient == null;
    final request = http.Request('POST', uri)
      ..headers['content-type'] = 'application/json'
      ..headers['accept'] = 'text/event-stream'
      ..body = jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'stream': true,
      });
    if (apiKey.isNotEmpty) {
      request.headers['authorization'] = 'Bearer $apiKey';
    }

    late final http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(connectionTimeout);
    } on TimeoutException {
      if (ownsClient) client.close();
      throw const FormatException('连接超时（20s）');
    } catch (e) {
      if (ownsClient) client.close();
      throw FormatException('连接失败: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      try {
        final errBody = await response.stream.toBytes().timeout(
              connectionTimeout,
            );
        if (ownsClient) client.close();
        throw FormatException(
          '请求失败: HTTP ${response.statusCode} ${utf8.decode(errBody)}',
        );
      } on TimeoutException {
        if (ownsClient) client.close();
        throw FormatException(
          '请求失败: HTTP ${response.statusCode}（读取错误体超时）',
        );
      }
    }

    final totalSw = Stopwatch()..start();
    final pendingLine = StringBuffer();
    final sseEventLines = <String>[];

    Iterable<String> flushSseEvent() sync* {
      if (sseEventLines.isEmpty) return;
      final lines = List<String>.from(sseEventLines);
      sseEventLines.clear();
      final dataParts = <String>[];
      for (final line in lines) {
        final t = line.trimLeft();
        if (t.startsWith('data:')) {
          dataParts.add(t.substring(5).trimLeft());
        }
      }
      if (dataParts.isNotEmpty) {
        final merged = dataParts.join('\n');
        if (merged.trim() == '[DONE]') return;
        final delta = _extractDeltaContentFromChunkJson(merged);
        if (delta != null && delta.isNotEmpty) yield delta;
        return;
      }
      for (final line in lines) {
        final t = line.trimLeft();
        if (t.startsWith('{')) {
          final delta = _extractDeltaContentFromChunkJson(t);
          if (delta != null && delta.isNotEmpty) yield delta;
        }
      }
    }

    Iterable<String> handleSseLine(String raw) sync* {
      final trimmed = raw.trimLeft();
      if (trimmed.isEmpty) {
        yield* flushSseEvent();
        return;
      }
      final t = trimmed;
      if (t.startsWith('data:')) {
        sseEventLines.add(raw);
        return;
      }
      if (sseEventLines.isNotEmpty) {
        sseEventLines.add(raw);
        return;
      }
      if (t.startsWith('{')) {
        final delta = _extractDeltaContentFromChunkJson(t);
        if (delta != null && delta.isNotEmpty) yield delta;
        return;
      }
      sseEventLines.add(raw);
    }

    Stream<List<int>> timedByteStream() async* {
      await for (final chunk in response.stream.timeout(
        idleTimeout,
        onTimeout: (sink) {
          sink.addError(
            TimeoutException('流空闲超时（${idleTimeout.inSeconds}s）'),
          );
        },
      )) {
        if (totalSw.elapsed > maxDuration) {
          throw FormatException('流总时长超时（${maxDuration.inSeconds}s）');
        }
        yield chunk;
      }
    }

    try {
      await for (final textPiece in utf8.decoder.bind(timedByteStream())) {
        if (totalSw.elapsed > maxDuration) {
          throw FormatException('流总时长超时（${maxDuration.inSeconds}s）');
        }
        pendingLine.write(textPiece);
        var buf = pendingLine.toString();
        pendingLine.clear();
        while (true) {
          final nl = buf.indexOf('\n');
          if (nl < 0) {
            pendingLine.write(buf);
            break;
          }
          final raw = buf.substring(0, nl).trimRight();
          buf = buf.substring(nl + 1);
          for (final delta in handleSseLine(raw)) {
            yield delta;
          }
        }
      }

      var rest = pendingLine.toString();
      pendingLine.clear();
      while (true) {
        final nl = rest.indexOf('\n');
        if (nl < 0) {
          if (rest.isNotEmpty) {
            for (final delta in handleSseLine(rest)) {
              yield delta;
            }
          }
          break;
        }
        final raw = rest.substring(0, nl).trimRight();
        rest = rest.substring(nl + 1);
        for (final delta in handleSseLine(raw)) {
          yield delta;
        }
      }
      for (final delta in flushSseEvent()) {
        yield delta;
      }
    } on TimeoutException catch (e) {
      throw FormatException(e.message ?? '流超时');
    } finally {
      if (ownsClient) client.close();
    }
  }

  static String? _extractDeltaContentFromChunkJson(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      return _deltaFromChoicesMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static String? _deltaFromChoicesMap(Map<String, dynamic> obj) {
    final choices = obj['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map<String, dynamic>) return null;

    final delta = first['delta'];
    if (delta is Map<String, dynamic>) {
      final fromContent = _stringFromDeltaContent(delta['content']);
      if (fromContent != null) return fromContent;
      final reasoning = delta['reasoning_content'];
      if (reasoning is String && reasoning.isNotEmpty) return reasoning;
      final fromRc = _stringFromDeltaContent(reasoning);
      if (fromRc != null) return fromRc;
    }

    final message = first['message'];
    if (message is Map<String, dynamic>) {
      final fromContent = _stringFromDeltaContent(message['content']);
      if (fromContent != null) return fromContent;
    }

    final text = first['text'];
    if (text is String && text.isNotEmpty) return text;

    return null;
  }

  /// OpenAI-compatible providers may send `content` as a String or as a list of
  /// parts (e.g. `{ "type": "text", "text": "..." }`).
  static String? _stringFromDeltaContent(dynamic content) {
    if (content is String) {
      return content.isEmpty ? null : content;
    }
    if (content is List) {
      final buf = StringBuffer();
      for (final item in content) {
        if (item is String && item.isNotEmpty) {
          buf.write(item);
          continue;
        }
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final type = m['type'];
          final text = m['text'];
          if (text is String && text.isNotEmpty) {
            if (type == null || type == 'text') {
              buf.write(text);
            }
          }
        }
      }
      final s = buf.toString();
      return s.isEmpty ? null : s;
    }
    return null;
  }
}
