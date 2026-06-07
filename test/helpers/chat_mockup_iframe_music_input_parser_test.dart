import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/helpers/chat_mockup_iframe_music_input_parser.dart';

void main() {
  group('extractChatMockupIframeMusicEmbedUrl', () {
    test('returns trimmed string when not iframe HTML', () {
      expect(
        extractChatMockupIframeMusicEmbedUrl(
          '  https://music.163.com/outchain/player?type=2&id=1&auto=1&height=32  ',
        ),
        'https://music.163.com/outchain/player?type=2&id=1&auto=1&height=32',
      );
    });

    test('extracts src from Netease-style iframe (protocol-relative)', () {
      const html = '''
<iframe frameborder="no" border="0" marginwidth="0" marginheight="0"
  width=330 height=86
  src="//music.163.com/outchain/player?type=2&id=186016&auto=1&height=32&bcid=1938030040&userId=1">
</iframe>''';
      expect(
        extractChatMockupIframeMusicEmbedUrl(html),
        '//music.163.com/outchain/player?type=2&id=186016&auto=1&height=32&bcid=1938030040&userId=1',
      );
    });

    test('prefers src over data-src', () {
      const html =
          '<iframe data-src="//ignored" src="https://example.com/x"></iframe>';
      expect(extractChatMockupIframeMusicEmbedUrl(html), 'https://example.com/x');
    });

    test('uses data-src when src missing', () {
      const html = '<iframe data-src="//music.163.com/outchain/player?type=2&id=1&auto=1&height=32"></iframe>';
      expect(
        extractChatMockupIframeMusicEmbedUrl(html),
        '//music.163.com/outchain/player?type=2&id=1&auto=1&height=32',
      );
    });

    test('throws when iframe has no src or data-src', () {
      expect(
        () => extractChatMockupIframeMusicEmbedUrl('<iframe></iframe>'),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('无法解析 iframe 地址'),
        )),
      );
    });
  });
}
