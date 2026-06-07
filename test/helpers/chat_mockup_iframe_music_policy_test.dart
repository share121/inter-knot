import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';
import 'package:inter_knot/helpers/chat_mockup_iframe_music_policy.dart';

void main() {
  group('validateChatMockupMusicIframeForSaveOrImport', () {
    test('accepts full iframe HTML wrapping allowed Netease URL', () {
      const html =
          '<iframe src="//music.163.com/outchain/player?type=2&id=1&auto=1&height=32"></iframe>';
      expect(validateChatMockupMusicIframeForSaveOrImport(html), completes);
    });

    test('accepts official Netease iframe src with extra vendor query (bcid, userId)', () {
      const html = '''
<iframe src="//music.163.com/outchain/player?type=2&id=186016&auto=1&height=32&bcid=1938030040&userId=1">
</iframe>''';
      expect(validateChatMockupMusicIframeForSaveOrImport(html), completes);
    });

    test('rejects iframe when src host not in allowlist', () {
      const html = '<iframe src="https://example.com/embed"></iframe>';
      expect(
        validateChatMockupMusicIframeForSaveOrImport(html),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('不在当前支持列表'),
          ),
        ),
      );
    });

    test('rejects URL with fragment after extract (format vs allowlist)', () {
      const html =
          '<iframe src="https://music.163.com/outchain/player?type=2&id=1&auto=1&height=32#x"></iframe>';
      expect(
        validateChatMockupMusicIframeForSaveOrImport(html),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('格式无效'),
          ),
        ),
      );
    });
  });

  group('ChatMockupMusicDirective.playIframe', () {
    test('preserves vendor query params after extract + normalize', () {
      const html =
          '<iframe src="//music.163.com/outchain/player?type=2&id=186016&auto=1&height=32&bcid=1938030040&userId=1"></iframe>';
      final d = ChatMockupMusicDirective.playIframe(html);
      expect(d.url, startsWith('https://music.163.com/outchain/player'));
      expect(d.url, contains('bcid=1938030040'));
      expect(d.url, contains('userId=1'));
      expect(d.url, contains('height=32'));
    });
  });

  group('chatMockupNeteaseOutchainEmbedInnerHeight', () {
    test('official-style height=32 maps to ~52 outer (chrome, not raw 32)', () {
      expect(chatMockupNeteaseOutchainEmbedInnerHeight(32), 52);
    });

    test('small query height is floored for usable controls', () {
      expect(chatMockupNeteaseOutchainEmbedInnerHeight(10), 52);
    });

    test('large query height is capped for mockup layout', () {
      expect(chatMockupNeteaseOutchainEmbedInnerHeight(2000), 720);
    });
  });

  group('chatMockupIframeMusicEmbedInnerHeight', () {
    test('parses Netease outchain URL height through mapping', () {
      const url =
          'https://music.163.com/outchain/player?type=2&id=1&auto=1&height=32';
      expect(chatMockupIframeMusicEmbedInnerHeight(url), 52);
    });
  });
}
