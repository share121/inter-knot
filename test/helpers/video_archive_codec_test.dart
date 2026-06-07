import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/helpers/video_archive_codec.dart';

void main() {
  group('compactVideoUploadPayload', () {
    Map<String, dynamic> sampleItem({
      String id = 'item_1',
      String type = 'text',
      String side = 'left',
      String? text,
      Map<String, dynamic>? wait,
      Map<String, dynamic>? music,
      String? emoji,
    }) {
      return {
        'id': id,
        'type': type,
        'side': side,
        'text': text,
        'emoji': emoji,
        'image': null,
        'avatar': null,
        'title': null,
        'subtitle': null,
        'firstText': null,
        'secondText': null,
        'wait': wait ?? {'mode': 'auto', 'seconds': 0},
        if (music != null) 'music': music,
      };
    }

    Map<String, dynamic> samplePayload({
      List<Map<String, dynamic>>? items,
      String chatTitle = '',
      String rolePrompt = '',
      String userPrompt = '',
    }) {
      return {
        'type': 'inter-knot-video',
        'version': 1,
        'chatMockup': {
          'version': 1,
          'chatTitle': chatTitle,
          'items': items ?? [sampleItem(text: 'hello')],
        },
        'ai': {
          'rolePrompt': rolePrompt,
          'userPrompt': userPrompt,
        },
      };
    }

    Map<String, dynamic> chatMockupFrom(Map<String, dynamic> payload) {
      return payload['chatMockup'] as Map<String, dynamic>;
    }

    Map<String, dynamic> firstItemFrom(Map<String, dynamic> payload) {
      final items = chatMockupFrom(payload)['items'] as List<dynamic>;
      return items.single as Map<String, dynamic>;
    }

    test('removes null, empty string, empty array, and empty object', () {
      final payload = samplePayload(
        items: [
          sampleItem(text: 'hello', emoji: ''),
        ],
      );
      final chatMockupInput = payload['chatMockup'] as Map<String, dynamic>;
      chatMockupInput['storyPlanner'] = <String, dynamic>{};
      chatMockupInput['emptyList'] = <dynamic>[];

      final compacted = compactVideoUploadPayload(payload);

      expect(compacted.containsKey('type'), isTrue);
      expect(compacted.containsKey('version'), isTrue);
      expect(compacted.containsKey('chatMockup'), isTrue);
      expect(compacted.containsKey('ai'), isTrue);
      final ai = compacted['ai'] as Map<String, dynamic>;
      expect(ai['rolePrompt'], '');
      expect(ai['userPrompt'], '');

      final chatMockup = compacted['chatMockup'] as Map<String, dynamic>;
      expect(chatMockup.containsKey('chatTitle'), isFalse);
      expect(chatMockup.containsKey('storyPlanner'), isFalse);
      expect(chatMockup.containsKey('emptyList'), isFalse);

      final item = (chatMockup['items'] as List).single as Map<String, dynamic>;
      expect(item.containsKey('text'), isTrue);
      expect(item.containsKey('emoji'), isFalse);
      expect(item.containsKey('image'), isFalse);
      expect(item.containsKey('wait'), isFalse);
    });

    test('survives encodeVideoPayload -> decodeVideoPayload roundtrip', () {
      final payload = samplePayload(
        items: [
          sampleItem(text: 'hello'),
          sampleItem(
            id: 'item_2',
            type: 'music',
            side: 'center',
            music: {
              'action': 'play',
              'kind': 'audioUrl',
              'url': 'https://example.com/a.mp3',
              'loop': false,
            },
          ),
        ],
      );
      final compacted = compactVideoUploadPayload(payload);
      final decoded = decodeVideoPayload(encodeVideoPayload(compacted));
      expect(decoded, compacted);
    });

    test('preserves false and zero values', () {
      final payload = samplePayload(
        items: [
          sampleItem(
            type: 'music',
            side: 'center',
            wait: {'mode': 'manual', 'seconds': 0},
            music: {
              'action': 'play',
              'kind': 'audioUrl',
              'url': 'https://example.com/a.mp3',
              'loop': false,
            },
          ),
        ],
      );

      final compacted = compactVideoUploadPayload(payload);
      final item = firstItemFrom(compacted);

      expect(item['wait'], {'mode': 'manual', 'seconds': 0});
      expect((item['music'] as Map)['loop'], isFalse);
    });

    test('removes default wait but keeps non-default wait', () {
      final autoPayload = samplePayload(
        items: [
          sampleItem(text: 'a', wait: {'mode': 'auto', 'seconds': 0})
        ],
      );
      final autoItem = firstItemFrom(compactVideoUploadPayload(autoPayload));
      expect(autoItem.containsKey('wait'), isFalse);

      final autoFloatPayload = samplePayload(
        items: [
          sampleItem(text: 'a', wait: {'mode': 'auto', 'seconds': 0.0}),
        ],
      );
      final autoFloatItem =
          firstItemFrom(compactVideoUploadPayload(autoFloatPayload));
      expect(autoFloatItem.containsKey('wait'), isFalse);

      final manualPayload = samplePayload(
        items: [
          sampleItem(text: 'a', wait: {'mode': 'manual', 'seconds': 2}),
        ],
      );
      final manualItem =
          firstItemFrom(compactVideoUploadPayload(manualPayload));
      expect(manualItem['wait'], {'mode': 'manual', 'seconds': 2});
    });

    test('preserves required keys even when empty', () {
      final emptyItemsPayload = {
        'type': 'inter-knot-video',
        'version': 1,
        'chatMockup': {
          'version': 1,
          'chatTitle': '',
          'items': <dynamic>[],
        },
        'ai': {'rolePrompt': '', 'userPrompt': ''},
      };

      final emptyItems = compactVideoUploadPayload(emptyItemsPayload);
      expect(emptyItems['type'], 'inter-knot-video');
      expect(emptyItems['version'], 1);
      final emptyChat = emptyItems['chatMockup'] as Map<String, dynamic>;
      expect(emptyChat['version'], 1);
      expect(emptyChat.containsKey('items'), isTrue);
      expect(emptyChat['items'], isEmpty);
      expect(emptyItems.containsKey('ai'), isTrue);
      final emptyAi = emptyItems['ai'] as Map<String, dynamic>;
      expect(emptyAi['rolePrompt'], '');
      expect(emptyAi['userPrompt'], '');

      final payloadWithEmptyId = {
        'type': 'inter-knot-video',
        'version': 1,
        'chatMockup': {
          'version': 1,
          'items': [
            {
              'id': '',
              'type': 'text',
              'side': 'left',
              'text': null,
              'wait': {'mode': 'auto', 'seconds': 0},
            },
          ],
        },
      };
      final itemMap = firstItemFrom(
        compactVideoUploadPayload(payloadWithEmptyId),
      );
      expect(itemMap.containsKey('id'), isTrue);
      expect(itemMap['id'], '');
      expect(itemMap.containsKey('type'), isTrue);
      expect(itemMap.containsKey('side'), isTrue);
      expect(itemMap.containsKey('text'), isFalse);
    });

    test('does not mutate input', () {
      final payload = samplePayload(
        items: [sampleItem(text: 'hello', emoji: '')],
      );
      final chatMockup = payload['chatMockup'] as Map<String, dynamic>;
      final items = chatMockup['items'] as List<dynamic>;

      compactVideoUploadPayload(payload);

      expect(chatMockup['chatTitle'], '');
      final item = items.single as Map<String, dynamic>;
      expect(item.containsKey('emoji'), isTrue);
      expect(item.containsKey('wait'), isTrue);
    });

    test('isVideoDiscussionPayload returns true for compacted payload', () {
      final compacted = compactVideoUploadPayload(samplePayload());
      expect(isVideoDiscussionPayload(compacted), isTrue);
    });
  });

  group('buildVideoUploadPayload', () {
    test('returns compact payload with required structure', () {
      final chatMockup = {
        'version': 1,
        'chatTitle': '',
        'items': [
          {
            'id': 'item_1',
            'type': 'text',
            'side': 'left',
            'text': 'hi',
            'emoji': null,
            'wait': {'mode': 'auto', 'seconds': 0},
          },
        ],
      };

      final payload = buildVideoUploadPayload(
        chatMockup: chatMockup,
        rolePrompt: 'role',
        userPrompt: 'user',
      );

      expect(payload['type'], 'inter-knot-video');
      expect(payload['version'], 1);
      expect(payload['ai'], {
        'rolePrompt': 'role',
        'userPrompt': 'user',
      });

      final chat = payload['chatMockup'] as Map<String, dynamic>;
      expect(chat.containsKey('chatTitle'), isFalse);
      final item = (chat['items'] as List).single as Map<String, dynamic>;
      expect(item['text'], 'hi');
      expect(item.containsKey('wait'), isFalse);
      expect(isVideoDiscussionPayload(payload), isTrue);
    });

    test('preserves empty ai prompts in compact payload', () {
      final payload = buildVideoUploadPayload(
        chatMockup: {
          'version': 1,
          'chatTitle': '',
          'items': [
            {
              'id': 'item_1',
              'type': 'text',
              'side': 'left',
              'text': 'hello',
              'wait': {'mode': 'auto', 'seconds': 0},
            },
          ],
        },
        rolePrompt: '',
        userPrompt: '',
      );

      expect(payload.containsKey('ai'), isTrue);
      expect(payload['ai'], {
        'rolePrompt': '',
        'userPrompt': '',
      });
    });

    test('empty ai prompts survive encode/decode roundtrip', () {
      final payload = buildVideoUploadPayload(
        chatMockup: {
          'version': 1,
          'items': [
            {
              'id': 'item_1',
              'type': 'text',
              'side': 'left',
              'text': 'hello',
            },
          ],
        },
        rolePrompt: '',
        userPrompt: '',
      );

      final decoded = decodeVideoPayload(encodeVideoPayload(payload));
      expect(decoded['ai'], {
        'rolePrompt': '',
        'userPrompt': '',
      });
    });
  });
}
