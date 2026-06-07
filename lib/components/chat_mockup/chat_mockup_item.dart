import 'package:flutter/material.dart';
import 'package:inter_knot/helpers/chat_mockup_audio_url_validator.dart';
import 'package:inter_knot/helpers/chat_mockup_iframe_music_input_parser.dart';
import 'package:inter_knot/helpers/chat_mockup_iframe_music_policy.dart';

enum ChatMockupItemType {
  message,
  emoji,
  sticker,
  customImage,
  action,
  replyOptions,
  commission,
}

enum ChatMockupItemSide {
  left,
  right,
  center,
}

enum ChatMockupImageSourceType {
  asset,
  network,
}

enum ChatMockupWaitMode {
  auto,
  manual,
}

enum ChatMockupMusicAction {
  /// Start or switch playback from [ChatMockupMusicDirective.url].
  play,

  /// Stop background audio (resets position). Not pause.
  stop,
}

/// Source for [ChatMockupMusicAction.play]: direct audio file vs iframe embed page.
enum ChatMockupMusicSourceKind {
  /// HTTPS / localhost URL with an audio file extension ([ChatMockupAudioUrlValidator]).
  audioUrl,

  /// HTTPS iframe embed URL vetted by [assertChatMockupMusicIframeEmbedAllowed]
  /// after [extractChatMockupIframeMusicEmbedUrl] (stored normalized: `//…` → `https:…`).
  iframe,
}

/// Background music cue when a [ChatMockupItemType.message] row becomes visible
/// during preview / tape playback (not a separate bubble type).
class ChatMockupMusicDirective {
  const ChatMockupMusicDirective({
    required this.action,
    this.kind = ChatMockupMusicSourceKind.audioUrl,
    this.url,
    this.loop = false,
  });

  final ChatMockupMusicAction action;

  /// For [ChatMockupMusicAction.play], how [url] is interpreted. Omitted in legacy JSON
  /// → [ChatMockupMusicSourceKind.audioUrl].
  final ChatMockupMusicSourceKind kind;

  final String? url;

  /// When [action] is [ChatMockupMusicAction.play], whether to loop the track
  /// until the next music cue (`true`) or play once / until next cue (`false`).
  /// For [kind] [ChatMockupMusicSourceKind.iframe], embeds may ignore this unless the
  /// saved URL includes site-specific loop parameters (see iframe policy comments).
  /// Ignored for [ChatMockupMusicAction.stop].
  final bool loop;

  /// HTTPS / localhost + known audio extension ([ChatMockupAudioUrlValidator]).
  factory ChatMockupMusicDirective.playAudioUrl(
    String raw, {
    bool loop = false,
  }) {
    final normalized = raw.trim();
    ChatMockupAudioUrlValidator.assertPlayableUrlShape(normalized);
    return ChatMockupMusicDirective(
      action: ChatMockupMusicAction.play,
      url: normalized,
      loop: loop,
    );
  }

  /// HTTPS iframe embed URL for chat-mockup music; [raw] may be a plain embed URL or
  /// full vendor `<iframe …>` HTML ([extractChatMockupIframeMusicEmbedUrl]).
  factory ChatMockupMusicDirective.playIframe(
    String raw, {
    bool loop = false,
  }) {
    final extracted = extractChatMockupIframeMusicEmbedUrl(raw);
    assertChatMockupMusicIframeEmbedAllowed(extracted);
    final normalized = normalizeChatMockupMusicIframeInput(extracted);
    return ChatMockupMusicDirective(
      action: ChatMockupMusicAction.play,
      kind: ChatMockupMusicSourceKind.iframe,
      url: normalized,
      loop: loop,
    );
  }

  /// Same as [playAudioUrl] (legacy name).
  factory ChatMockupMusicDirective.playUrl(
    String raw, {
    bool loop = false,
  }) =>
      ChatMockupMusicDirective.playAudioUrl(raw, loop: loop);

  static const ChatMockupMusicDirective stop = ChatMockupMusicDirective(
    action: ChatMockupMusicAction.stop,
  );

  Map<String, dynamic> toJson() {
    return {
      'action': action.name,
      if (url != null) 'url': url,
      if (action == ChatMockupMusicAction.play) 'kind': kind.name,
      if (action == ChatMockupMusicAction.play) 'loop': loop,
    };
  }

  factory ChatMockupMusicDirective.fromJson(Map<String, dynamic> json) {
    final actionName = json['action'];
    if (actionName is! String) {
      throw const FormatException('Invalid music directive.');
    }
    final action = ChatMockupMusicAction.values.firstWhere(
      (e) => e.name == actionName.trim(),
      orElse: () => throw const FormatException('Unsupported music action.'),
    );
    final urlRaw = json['url'];
    final url = urlRaw is String ? urlRaw.trim() : null;
    final loop = json['loop'] == true;
    final ChatMockupMusicSourceKind kind;
    if (!json.containsKey('kind') || json['kind'] == null) {
      kind = ChatMockupMusicSourceKind.audioUrl;
    } else {
      final kindRaw = json['kind'];
      if (kindRaw is! String) {
        throw FormatException(
          'Music kind must be a string; received ${kindRaw.runtimeType}.',
        );
      }
      final trimmedKind = kindRaw.trim();
      if (trimmedKind.isEmpty) {
        throw FormatException(
          'Unknown music kind: empty string. '
          'Expected one of: '
          '${ChatMockupMusicSourceKind.values.map((e) => e.name).join(", ")}.',
        );
      }
      ChatMockupMusicSourceKind? parsed;
      for (final e in ChatMockupMusicSourceKind.values) {
        if (e.name == trimmedKind) {
          parsed = e;
          break;
        }
      }
      if (parsed == null) {
        throw FormatException(
          'Unknown music kind: "$trimmedKind". '
          'Expected one of: '
          '${ChatMockupMusicSourceKind.values.map((e) => e.name).join(", ")}.',
        );
      }
      kind = parsed;
    }
    switch (action) {
      case ChatMockupMusicAction.play:
        if (url == null || url.isEmpty) {
          throw const FormatException('music.play requires url.');
        }
        switch (kind) {
          case ChatMockupMusicSourceKind.audioUrl:
            return ChatMockupMusicDirective.playAudioUrl(url, loop: loop);
          case ChatMockupMusicSourceKind.iframe:
            return ChatMockupMusicDirective.playIframe(url, loop: loop);
        }
      case ChatMockupMusicAction.stop:
        return ChatMockupMusicDirective.stop;
    }
  }
}

class ChatMockupImageSource {
  const ChatMockupImageSource({
    required this.type,
    required this.value,
  });

  final ChatMockupImageSourceType type;
  final String value;

  factory ChatMockupImageSource.network(String url) {
    final normalized = url.trim();
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      throw const FormatException('Invalid image URL.');
    }
    if (uri.scheme == 'https') {
      // ok
    } else if (uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      // allow localhost in development
    } else {
      throw const FormatException('Only https image URL is supported.');
    }
    if (uri.host.trim().isEmpty) {
      throw const FormatException('Invalid image URL host.');
    }
    if (uri.path.trim().isEmpty) {
      throw const FormatException('Invalid image URL path.');
    }
    return ChatMockupImageSource(
      type: ChatMockupImageSourceType.network,
      value: normalized,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'value': value,
    };
  }

  factory ChatMockupImageSource.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'];
    final value = json['value'];
    if (typeName is! String || value is! String || value.isEmpty) {
      throw const FormatException('Invalid image source.');
    }
    if (typeName.trim() == 'memory') {
      throw const FormatException('旧版内嵌图片不再支持，请改用图片 URL。');
    }
    if (typeName.trim() == ChatMockupImageSourceType.asset.name) {
      return ChatMockupImageSource(
        type: ChatMockupImageSourceType.asset,
        value: value,
      );
    }
    if (typeName.trim() == ChatMockupImageSourceType.network.name) {
      return ChatMockupImageSource.network(value);
    }
    throw const FormatException('Unsupported image source type.');
  }

  ImageProvider toImageProvider() {
    switch (type) {
      case ChatMockupImageSourceType.asset:
        return AssetImage(value);
      case ChatMockupImageSourceType.network:
        return NetworkImage(value);
    }
  }
}

class ChatMockupItem {
  static const _noChange = _ChatMockupItemNoChange();

  ChatMockupItem({
    required this.id,
    required this.type,
    required this.side,
    this.text,
    this.emoji,
    this.image,
    this.imageSource,
    this.avatarSource,
    this.title,
    this.subtitle,
    this.firstText,
    this.secondText,
    this.waitMode = ChatMockupWaitMode.auto,
    this.waitSeconds = 0,
    this.music,
  }) : assert(
          _isSideAllowed(type, side),
          'Invalid side $side for type $type',
        );

  final String id;
  final ChatMockupItemType type;
  final ChatMockupItemSide side;
  final String? text;
  final String? emoji;
  final ImageProvider? image;
  final ChatMockupImageSource? imageSource;
  final ChatMockupImageSource? avatarSource;
  final String? title;
  final String? subtitle;
  final String? firstText;
  final String? secondText;
  final ChatMockupWaitMode waitMode;
  final double waitSeconds;
  final ChatMockupMusicDirective? music;

  static bool _isSideAllowed(
    ChatMockupItemType type,
    ChatMockupItemSide side,
  ) {
    switch (type) {
      case ChatMockupItemType.message:
      case ChatMockupItemType.emoji:
      case ChatMockupItemType.sticker:
      case ChatMockupItemType.customImage:
        return side == ChatMockupItemSide.left ||
            side == ChatMockupItemSide.right;
      case ChatMockupItemType.replyOptions:
      case ChatMockupItemType.commission:
        return side == ChatMockupItemSide.right;
      case ChatMockupItemType.action:
        return side == ChatMockupItemSide.center;
    }
  }

  ChatMockupItem copyWith({
    String? id,
    ChatMockupItemType? type,
    ChatMockupItemSide? side,
    Object? text = _noChange,
    String? emoji,
    Object? image = _noChange,
    Object? imageSource = _noChange,
    Object? avatarSource = _noChange,
    Object? title = _noChange,
    Object? subtitle = _noChange,
    Object? firstText = _noChange,
    Object? secondText = _noChange,
    ChatMockupWaitMode? waitMode,
    double? waitSeconds,
    Object? music = _noChange,
  }) {
    String? resolveText(Object? value, String? current) {
      if (value == _noChange) return current;
      return value as String?;
    }

    return ChatMockupItem(
      id: id ?? this.id,
      type: type ?? this.type,
      side: side ?? this.side,
      text: resolveText(text, this.text),
      emoji: emoji ?? this.emoji,
      image: image == _noChange ? this.image : image as ImageProvider?,
      imageSource: imageSource == _noChange
          ? this.imageSource
          : imageSource as ChatMockupImageSource?,
      avatarSource: avatarSource == _noChange
          ? this.avatarSource
          : avatarSource as ChatMockupImageSource?,
      title: resolveText(title, this.title),
      subtitle: resolveText(subtitle, this.subtitle),
      firstText: resolveText(firstText, this.firstText),
      secondText: resolveText(secondText, this.secondText),
      waitMode: waitMode ?? this.waitMode,
      waitSeconds: waitSeconds ?? this.waitSeconds,
      music: music == _noChange
          ? this.music
          : music as ChatMockupMusicDirective?,
    );
  }
}

class _ChatMockupItemNoChange {
  const _ChatMockupItemNoChange();
}
