import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/helpers/video_player_session_store.dart';

Map<String, dynamic> _sampleChatMockup({int itemCount = 3}) {
  return <String, dynamic>{
    'version': 1,
    'chatTitle': 'test',
    'items': List<Map<String, dynamic>>.generate(
      itemCount,
      (i) => <String, dynamic>{
        'id': 'item_$i',
        'type': 'text',
        'side': 'left',
        'text': 'msg $i',
      },
    ),
  };
}

void main() {
  group('VideoPlayerSessionRecord', () {
    VideoPlayerSessionRecord sampleV2Record({
      int visibleItemCount = 2,
      bool playbackComplete = false,
    }) {
      return VideoPlayerSessionRecord(
        version: 2,
        discussionNumber: 42,
        updatedAtMs: 1700000000000,
        chatMockup: _sampleChatMockup(),
        sourceHash: 'abc123',
        visibleItemCount: visibleItemCount,
        playbackComplete: playbackComplete,
      );
    }

    test('v2 toJson roundtrips through tryParse with progress fields', () {
      final original = sampleV2Record();
      final parsed = VideoPlayerSessionRecord.tryParse(original.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.version, 2);
      expect(parsed.discussionNumber, 42);
      expect(parsed.visibleItemCount, 2);
      expect(parsed.playbackComplete, isFalse);
      expect(parsed.chatMockup['chatTitle'], 'test');
      expect(parsed.sourceHash, 'abc123');
    });

    test('v1 record parses with null progress fields', () {
      final raw = <String, dynamic>{
        'version': 1,
        'discussionNumber': 7,
        'updatedAtMs': 100,
        'chatMockup': _sampleChatMockup(itemCount: 1),
        'sourceHash': 'hash',
      };
      final parsed = VideoPlayerSessionRecord.tryParse(raw);
      expect(parsed, isNotNull);
      expect(parsed!.version, 1);
      expect(parsed.visibleItemCount, isNull);
      expect(parsed.playbackComplete, isNull);
    });

    test('unsupported version returns null', () {
      final raw = sampleV2Record().toJson()..['version'] = 99;
      expect(VideoPlayerSessionRecord.tryParse(raw), isNull);
    });

    test('invalid chatMockup returns null without throwing', () {
      final raw = sampleV2Record().toJson()..['chatMockup'] = 'not-a-map';
      expect(VideoPlayerSessionRecord.tryParse(raw), isNull);
    });

    test('negative visibleItemCount in v2 returns null', () {
      final raw = sampleV2Record().toJson()..['visibleItemCount'] = -1;
      expect(VideoPlayerSessionRecord.tryParse(raw), isNull);
    });

    test('missing playbackComplete in v2 returns null', () {
      final raw = sampleV2Record().toJson()..remove('playbackComplete');
      expect(VideoPlayerSessionRecord.tryParse(raw), isNull);
    });
  });

  group('normalizeBrowsePlaybackState', () {
    test('empty items: count 0 and complete', () {
      final result = normalizeBrowsePlaybackState(
        visibleItemCount: 5,
        itemLength: 0,
        playbackComplete: false,
      );
      expect(result.visibleItemCount, 0);
      expect(result.playbackComplete, isTrue);
    });

    test('all visible but incomplete becomes complete', () {
      final result = normalizeBrowsePlaybackState(
        visibleItemCount: 10,
        itemLength: 10,
        playbackComplete: false,
      );
      expect(result.visibleItemCount, 10);
      expect(result.playbackComplete, isTrue);
    });

    test('count 0 with items starts at 1', () {
      final result = normalizeBrowsePlaybackState(
        visibleItemCount: 0,
        itemLength: 5,
        playbackComplete: false,
      );
      expect(result.visibleItemCount, 1);
      expect(result.playbackComplete, isFalse);
    });

    test('middle value unchanged', () {
      final result = normalizeBrowsePlaybackState(
        visibleItemCount: 3,
        itemLength: 10,
        playbackComplete: false,
      );
      expect(result.visibleItemCount, 3);
      expect(result.playbackComplete, isFalse);
    });

    test('complete forces visible count to item length', () {
      final result = normalizeBrowsePlaybackState(
        visibleItemCount: 2,
        itemLength: 10,
        playbackComplete: true,
      );
      expect(result.visibleItemCount, 10);
      expect(result.playbackComplete, isTrue);
    });
  });

  group('extractChatMockupContentForSession', () {
    test('strips playback metadata from snapshot', () {
      final source = <String, dynamic>{
        'version': 1,
        'chatTitle': 'title',
        'items': <Map<String, dynamic>>[],
        'storyPlanner': <String, dynamic>{},
        'templateRevision': 2,
        'visibleItemCount': 5,
        'playbackComplete': false,
        'capturedAtMs': 123,
      };
      final content = extractChatMockupContentForSession(source);
      expect(content.containsKey('visibleItemCount'), isFalse);
      expect(content.containsKey('playbackComplete'), isFalse);
      expect(content.containsKey('capturedAtMs'), isFalse);
      expect(content['chatTitle'], 'title');
      expect(content['templateRevision'], 2);
    });

    test('v2 persist chatMockup excludes playback fields', () {
      final snap = <String, dynamic>{
        'version': 1,
        'chatTitle': 'test',
        'items': _sampleChatMockup()['items'],
        'storyPlanner': <String, dynamic>{},
        'templateRevision': 1,
        'visibleItemCount': 2,
        'playbackComplete': false,
      };
      final normalized = normalizeBrowsePlaybackState(
        visibleItemCount: snap['visibleItemCount'] as int,
        itemLength: (snap['items'] as List).length,
        playbackComplete: snap['playbackComplete'] as bool,
      );
      final record = VideoPlayerSessionRecord(
        version: 2,
        discussionNumber: 1,
        updatedAtMs: 100,
        chatMockup: extractChatMockupContentForSession(snap),
        sourceHash: 'hash',
        visibleItemCount: normalized.visibleItemCount,
        playbackComplete: normalized.playbackComplete,
      );
      expect(record.chatMockup.containsKey('visibleItemCount'), isFalse);
      expect(record.chatMockup.containsKey('playbackComplete'), isFalse);
      expect(record.visibleItemCount, 2);
      expect(record.playbackComplete, isFalse);
    });
  });

  group('clampBrowsePlaybackVisibleCount', () {
    test('clamps to zero for empty items', () {
      expect(clampBrowsePlaybackVisibleCount(5, 0), 0);
      expect(clampBrowsePlaybackVisibleCount(0, 0), 0);
    });

    test('clamps negative to zero', () {
      expect(clampBrowsePlaybackVisibleCount(-3, 10), 0);
    });

    test('preserves valid middle value', () {
      expect(clampBrowsePlaybackVisibleCount(3, 10), 3);
    });

    test('clamps overflow to item length', () {
      expect(clampBrowsePlaybackVisibleCount(15, 10), 10);
    });
  });
}
