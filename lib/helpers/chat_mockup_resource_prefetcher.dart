import 'package:inter_knot/components/chat_mockup/chat_mockup_item.dart';

/// Collects unique network URLs from [items] for session prefetch.
class ChatMockupResourcePrefetcher {
  ChatMockupResourcePrefetcher._();

  static List<String> collectNetworkUrls(List<ChatMockupItem> items) {
    final out = <String>{};
    for (final item in items) {
      final music = item.music;
      if (music != null &&
          music.action == ChatMockupMusicAction.play &&
          music.kind == ChatMockupMusicSourceKind.audioUrl &&
          (music.url ?? '').isNotEmpty) {
        out.add(music.url!);
      }
      final img = item.imageSource;
      if (img != null && img.type == ChatMockupImageSourceType.network) {
        out.add(img.value);
      }
      final av = item.avatarSource;
      if (av != null && av.type == ChatMockupImageSourceType.network) {
        out.add(av.value);
      }
    }
    return out.toList();
  }
}
