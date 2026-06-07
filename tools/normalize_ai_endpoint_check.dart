import 'package:inter_knot/api/chat_mockup_ai_api.dart';

void main() {
  const api = ChatMockupAiApi();
  final cases = <String, String>{
    'https://example.com/v2': 'https://example.com/v2/chat/completions',
    'https://example.com/v3': 'https://example.com/v3/chat/completions',
    'https://example.com/v4': 'https://example.com/v4/chat/completions',
    'https://example.com/v4/': 'https://example.com/v4/chat/completions',
    'https://example.com/v5': 'https://example.com/v5/chat/completions',
    'https://example.com/v5/': 'https://example.com/v5/chat/completions',
    'https://example.com/v5/chat/completions/':
        'https://example.com/v5/chat/completions',
    'https://example.com/v4/chat/completions':
        'https://example.com/v4/chat/completions',
    'https://api.openai.com/v1': 'https://api.openai.com/v1/chat/completions',
    'https://example.com/api/v3': 'https://example.com/api/v3/chat/completions',
    'example.com/v4': 'https://example.com/v4/chat/completions',
  };

  for (final entry in cases.entries) {
    final actual = api.debugNormalizeEndpoint(entry.key).toString();
    if (actual != entry.value) {
      throw StateError(
        'normalize mismatch for ${entry.key}\n'
        'expected: ${entry.value}\n'
        'actual:   $actual',
      );
    }
    // ignore: avoid_print
    print('OK ${entry.key} -> $actual');
  }
}
