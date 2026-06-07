import 'dart:math' as math;

import 'package:inter_knot/helpers/chat_mockup_iframe_music_input_parser.dart';
import 'package:inter_knot/helpers/iframe_policy.dart';

/// Narrow iframe **embed** allowlist for **敲敲预览** background music only.
///
/// User input may be raw HTML: [extractChatMockupIframeMusicEmbedUrl] →
/// [normalizeChatMockupMusicIframeInput] → [assertChatMockupMusicIframeEmbedAllowed].
///
/// This is stricter than [IframeLoadPolicy.allowAllRisky]: we never treat arbitrary
/// HTTPS pages on "trusted" hosts as loadable—only vetted **embed** shapes.
///
/// Reuses [isSupportedIframeUri], [isStrictBilibiliPlayerEmbed], and [isTrustedIframeHost]
/// where appropriate. [decideIframeLoad] is not used directly because chat-mockup music
/// must not follow the "mask with manual load" card UX—URLs are either allowed or rejected.
///
/// **Autoplay / loop (WebView):** [ChatMockupIframeMusicEmbed] sets
/// `mediaPlaybackRequiresUserGesture: false` (see `IframePlayer`). Per-site behavior:
///
/// - **Bilibili** `player.bilibili.com/player.html?...` — player autoplays in-page; add
///   `&autoplay=0` in the site UI if needed. Loop is not controlled by this app; the
///   in-player control applies.
/// - **YouTube** `/embed/VIDEO_ID` — typically needs `?autoplay=1` in the **saved URL**
///   for auto-start; for **loop**, YouTube expects `loop=1` and `playlist=VIDEO_ID` on
///   the same URL (add these in the editor when you need loop). This validator does
///   not inject query parameters.
/// - **Netease** `music.163.com/outchain/player?type=&id=&auto=&height=` — official
///   outchain player only; **`type` / `id` / `auto` / `height` are required** (strict
///   numeric rules, `height` capped, `auto` ∈ {0,1}). **Additional vendor query keys**
///   (e.g. `bcid`, `userId` from the official `<iframe>` snippet) are **allowed** and
///   preserved in the saved URL. The query `height` is the player **content** hint for
///   Netease’s script, not 1:1 our [InAppWebView] box — see
///   [chatMockupNeteaseOutchainEmbedInnerHeight].
///
/// **Limitation:** [ChatMockupMusicDirective.loop] applies to [audioUrl] via
/// `just_audio`; for [iframe] kind, loop is stored for future/editor use but embed
/// players may ignore it unless the URL carries the right query flags.

const kChatMockupNeteaseOutchainWindowsRiskMessage =
    '网易云外链播放器在当前 Windows 环境下存在已知闪退风险，其他环境可能正常。是否继续使用？';

const kChatMockupNeteaseOutchainWindowsRiskShortLabel =
    '网易云外链在当前 Windows 环境下存在已知闪退风险';

/// Protocol-relative `//host/...` → `https://host/...` (same idea as post HTML iframe src).
String normalizeChatMockupMusicIframeInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.startsWith('//')) {
    return 'https:$trimmed';
  }
  return trimmed;
}

const _neteaseOutchainMaxHeightParam = 2048;

/// Extra pixels above Netease’s own `height=` query so controls / chrome are not clipped
/// (official mini embed uses `height=32` with an outer iframe ~52px).
const _neteaseOutchainEmbedChromePx = 20;

/// Floor so very small `height=` values still get a usable tap target (matches ~52 outer).
const _neteaseOutchainEmbedMinInnerHeight = 52.0;

/// Cap for mockup WebView box; URL `height` may still be large for Netease’s API.
const _neteaseOutchainEmbedMaxInnerHeight = 720.0;

bool isChatMockupMusicIframeEmbedAllowed(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (!isSupportedIframeUri(uri)) return false;
  if (isStrictNeteaseOutchainPlayerEmbed(uri)) return true;
  if (isStrictBilibiliPlayerEmbed(uri)) return true;
  return _isYoutubeStyleMusicEmbed(uri);
}

/// 网易云 music.163.com/outchain/player 严格嵌入形态（与保存校验一致）。
bool isStrictNeteaseOutchainPlayerEmbed(Uri uri) {
  if (uri.host.toLowerCase() != 'music.163.com') return false;
  if (uri.path != '/outchain/player') return false;
  const requiredKeys = {'type', 'id', 'auto', 'height'};
  if (uri.queryParametersAll.isEmpty) return false;
  for (final key in requiredKeys) {
    final values = uri.queryParametersAll[key];
    if (values == null || values.length != 1) return false;
    if (values.first.trim().isEmpty) return false;
  }
  final type = uri.queryParameters['type']!;
  final id = uri.queryParameters['id']!;
  final auto = uri.queryParameters['auto']!;
  final height = uri.queryParameters['height']!;
  final typeInt = int.tryParse(type);
  final idInt = int.tryParse(id);
  final heightInt = int.tryParse(height);
  if (typeInt == null || typeInt <= 0) return false;
  if (idInt == null || idInt <= 0) return false;
  if (heightInt == null ||
      heightInt <= 0 ||
      heightInt > _neteaseOutchainMaxHeightParam) {
    return false;
  }
  if (auto != '0' && auto != '1') return false;
  return true;
}

/// 已规范化的 HTTPS 嵌入地址是否为网易云外链播放器（严格参数）。
bool isNeteaseOutchainMusicIframeEmbedUrl(String normalizedHttpsUrl) {
  final uri = Uri.tryParse(normalizedHttpsUrl);
  return uri != null && isStrictNeteaseOutchainPlayerEmbed(uri);
}

/// `www.youtube.com/embed/...` or `www.youtube-nocookie.com/embed/...` (trusted host + path).
bool _isYoutubeStyleMusicEmbed(Uri uri) {
  if (!isTrustedIframeHost(uri)) return false;
  final host = uri.host.toLowerCase();
  if (!host.endsWith('youtube.com') && !host.endsWith('youtube-nocookie.com')) {
    return false;
  }
  final segments = uri.pathSegments;
  if (segments.length < 2) return false;
  if (segments[0] != 'embed') return false;
  final id = segments[1];
  if (id.isEmpty) return false;
  return RegExp(r'^[\w-]{11}$').hasMatch(id);
}

/// Validates a **resolved embed URL** (not full `<iframe>` HTML — use
/// [extractChatMockupIframeMusicEmbedUrl] first).
///
/// Throws [FormatException] with distinct messages for **format** vs **allowlist**.
void assertChatMockupMusicIframeEmbedAllowed(String resolvedEmbedUrl) {
  final normalized = normalizeChatMockupMusicIframeInput(resolvedEmbedUrl);
  if (normalized.isEmpty) {
    throw const FormatException('iframe 播放需要非空 embed 地址。');
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) {
    throw const FormatException(
      '嵌入地址格式无效：无法解析为带主机名的有效网址。',
    );
  }
  if (uri.scheme != 'https') {
    throw const FormatException(
      '嵌入地址格式无效：须为 https 链接（可将 // 开头的地址粘贴后自动补全）。',
    );
  }
  if (!isSupportedIframeUri(uri)) {
    throw const FormatException(
      '嵌入地址格式无效：结构不符合要求（例如不得包含 fragment）。',
    );
  }
  if (!isChatMockupMusicIframeEmbedAllowed(uri)) {
    throw const FormatException(
      '该嵌入来源不在当前支持列表。仅支持：网易云 music.163.com/outchain/player、B 站 player.bilibili.com/player.html（严格参数）、YouTube / YouTube-nocookie 的 /embed/ 页面。',
    );
  }
}

/// Import/save shape check (no network I/O): [extractChatMockupIframeMusicEmbedUrl]
/// then [assertChatMockupMusicIframeEmbedAllowed].
Future<void> validateChatMockupMusicIframeForSaveOrImport(String raw) async {
  final extracted = extractChatMockupIframeMusicEmbedUrl(raw);
  assertChatMockupMusicIframeEmbedAllowed(extracted);
}

/// Netease outchain: maps URL `height` query (player content hint) to our **visible**
/// [InAppWebView] inner height so the in-page player is not cropped (≠ raw `height`).
double chatMockupNeteaseOutchainEmbedInnerHeight(int queryHeight) {
  final q = queryHeight.clamp(1, _neteaseOutchainMaxHeightParam);
  final withChrome = q + _neteaseOutchainEmbedChromePx;
  return math.min(
    math.max(withChrome.toDouble(), _neteaseOutchainEmbedMinInnerHeight),
    _neteaseOutchainEmbedMaxInnerHeight,
  );
}

/// Resolved inner content height for the visible mockup embed (pixels), after policy checks.
double chatMockupIframeMusicEmbedInnerHeight(String normalizedHttpsUrl) {
  final uri = Uri.tryParse(normalizedHttpsUrl);
  if (uri != null && isStrictNeteaseOutchainPlayerEmbed(uri)) {
    final h = int.tryParse(uri.queryParameters['height'] ?? '');
    if (h != null && h > 0) {
      return chatMockupNeteaseOutchainEmbedInnerHeight(h);
    }
  }
  return 210 * 9 / 16;
}
