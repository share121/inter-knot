import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:inter_knot/helpers/box.dart';

const int kVideoPlayerSessionRecordVersion = 2;

String videoPlayerSessionStorageKey(int discussionNumber) =>
    'video_player_session_$discussionNumber';

/// Fingerprint of the work's published [chatMockup] + [ai] so we don't resume after an author update.
String computeVideoPayloadSourceHash(Map<String, dynamic> decodedPayload) {
  final chat = decodedPayload['chatMockup'];
  final ai = decodedPayload['ai'];
  final canonical = jsonEncode(<String, dynamic>{
    'ai': ai,
    'chatMockup': chat,
  });
  return sha256.convert(utf8.encode(canonical)).toString();
}

int clampBrowsePlaybackVisibleCount(int count, int itemLength) =>
    count.clamp(0, itemLength);

class BrowsePlaybackNormalizedState {
  const BrowsePlaybackNormalizedState({
    required this.visibleItemCount,
    required this.playbackComplete,
  });

  final int visibleItemCount;
  final bool playbackComplete;
}

BrowsePlaybackNormalizedState normalizeBrowsePlaybackState({
  required int visibleItemCount,
  required int itemLength,
  required bool playbackComplete,
}) {
  if (itemLength == 0) {
    return const BrowsePlaybackNormalizedState(
      visibleItemCount: 0,
      playbackComplete: true,
    );
  }
  if (playbackComplete) {
    return BrowsePlaybackNormalizedState(
      visibleItemCount: itemLength,
      playbackComplete: true,
    );
  }
  if (visibleItemCount <= 0) {
    return const BrowsePlaybackNormalizedState(
      visibleItemCount: 1,
      playbackComplete: false,
    );
  }
  if (visibleItemCount >= itemLength) {
    return BrowsePlaybackNormalizedState(
      visibleItemCount: itemLength,
      playbackComplete: true,
    );
  }
  return BrowsePlaybackNormalizedState(
    visibleItemCount: visibleItemCount,
    playbackComplete: false,
  );
}

const _chatMockupContentKeys = <String>[
  'version',
  'chatTitle',
  'items',
  'storyPlanner',
  'templateRevision',
];

/// Chat content fields only — excludes browse playback metadata.
Map<String, dynamic> extractChatMockupContentForSession(
  Map<String, dynamic> source,
) {
  final result = <String, dynamic>{};
  for (final key in _chatMockupContentKeys) {
    if (source.containsKey(key)) {
      result[key] = source[key];
    }
  }
  return result;
}

class VideoPlayerSessionRecord {
  const VideoPlayerSessionRecord({
    required this.version,
    required this.discussionNumber,
    required this.updatedAtMs,
    required this.chatMockup,
    required this.sourceHash,
    this.visibleItemCount,
    this.playbackComplete,
  });

  final int version;
  final int discussionNumber;
  final int updatedAtMs;
  final Map<String, dynamic> chatMockup;
  final String sourceHash;
  final int? visibleItemCount;
  final bool? playbackComplete;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'discussionNumber': discussionNumber,
        'updatedAtMs': updatedAtMs,
        'chatMockup': chatMockup,
        'sourceHash': sourceHash,
        if (visibleItemCount != null) 'visibleItemCount': visibleItemCount,
        if (playbackComplete != null) 'playbackComplete': playbackComplete,
      };

  static VideoPlayerSessionRecord? tryParse(dynamic raw) {
    if (raw == null) {
      return null;
    }
    Map<String, dynamic>? map;
    if (raw is String) {
      if (raw.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          map = decoded;
        }
      } catch (_) {
        return null;
      }
    } else if (raw is Map<String, dynamic>) {
      map = raw;
    }
    if (map == null) {
      return null;
    }
    final version = map['version'];
    final discussionNumber = map['discussionNumber'];
    final updatedAtMs = map['updatedAtMs'];
    final chatMockup = map['chatMockup'];
    final sourceHash = map['sourceHash'];
    if (version is! int ||
        discussionNumber is! int ||
        updatedAtMs is! int ||
        chatMockup is! Map ||
        sourceHash is! String) {
      return null;
    }
    if (version != 1 && version != 2) {
      return null;
    }

    int? visibleItemCount;
    bool? playbackComplete;
    if (version == 2) {
      final rawCount = map['visibleItemCount'];
      final rawComplete = map['playbackComplete'];
      if (rawCount is! int || rawCount < 0) {
        return null;
      }
      if (rawComplete is! bool) {
        return null;
      }
      visibleItemCount = rawCount;
      playbackComplete = rawComplete;
    }

    return VideoPlayerSessionRecord(
      version: version,
      discussionNumber: discussionNumber,
      updatedAtMs: updatedAtMs,
      chatMockup: Map<String, dynamic>.from(chatMockup),
      sourceHash: sourceHash,
      visibleItemCount: visibleItemCount,
      playbackComplete: playbackComplete,
    );
  }
}

VideoPlayerSessionRecord? readVideoPlayerSession(int discussionNumber) {
  final key = videoPlayerSessionStorageKey(discussionNumber);
  return VideoPlayerSessionRecord.tryParse(box.read(key));
}

Future<void> writeVideoPlayerSession(VideoPlayerSessionRecord record) async {
  final key = videoPlayerSessionStorageKey(record.discussionNumber);
  await box.write(key, jsonEncode(record.toJson()));
}

Future<void> clearVideoPlayerSession(int discussionNumber) async {
  await box.remove(videoPlayerSessionStorageKey(discussionNumber));
}
