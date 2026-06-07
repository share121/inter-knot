enum IframeLoadPolicy {
  denyAll,
  allowBilibiliStrict,
  allowAllRisky,
}

enum IframeLoadDecision {
  loadDirectly,
  maskWithManualLoad,
  maskWithoutManualLoad,
}

const _allowedBilibiliQueryKeys = <String>{
  'isOutside',
  'aid',
  'bvid',
  'cid',
  'p',
};
const _requiredBilibiliQueryKeys = <String>{
  'isOutside',
  'cid',
  'p',
};

bool isSupportedIframeUri(Uri uri) =>
    (uri.scheme == 'https' || uri.scheme.isEmpty) &&
    uri.host.trim().isNotEmpty &&
    uri.fragment.trim().isEmpty;

/// Trusted iframe host rules used by `allowAllRisky`.
///
/// Keep this list intentionally scoped to known official embed endpoints:
/// - bilibili player
/// - YouTube / youtu.be and youtube-nocookie
/// - X/Twitter publishing embeds
///
/// New official subdomains can be added here after verification.
const _trustedIframeHostRules = <String>{
  'player.bilibili.com',
  '.youtube.com',
  '.youtube-nocookie.com',
  'youtu.be',
  '.youtu.be',
  '.twitter.com',
  '.x.com',
  'x.com',
};

bool isTrustedIframeHost(Uri uri) {
  final host = uri.host.toLowerCase();
  for (final rule in _trustedIframeHostRules) {
    if (rule.startsWith('.')) {
      final suffix = rule.substring(1);
      if (host == suffix || host.endsWith('.$suffix')) return true;
      continue;
    }
    if (host == rule) return true;
  }
  return false;
}

IframeLoadDecision decideIframeLoad(
  String rawUrl, {
  required IframeLoadPolicy policy,
}) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || !isSupportedIframeUri(uri)) {
    return IframeLoadDecision.maskWithoutManualLoad;
  }
  return switch (policy) {
    IframeLoadPolicy.denyAll => IframeLoadDecision.maskWithoutManualLoad,
    IframeLoadPolicy.allowBilibiliStrict =>
      isStrictBilibiliPlayerEmbed(uri)
          ? IframeLoadDecision.loadDirectly
          : IframeLoadDecision.maskWithoutManualLoad,
    IframeLoadPolicy.allowAllRisky =>
      uri.scheme == 'https' && isTrustedIframeHost(uri)
          ? IframeLoadDecision.loadDirectly
          : uri.scheme == 'https'
              ? IframeLoadDecision.maskWithManualLoad
              : IframeLoadDecision.maskWithoutManualLoad,
  };
}

/// Strict bilibili player policy:
/// - HTTPS + player.bilibili.com/player.html
/// - only allowed keys: isOutside/cid/p/aid/bvid
/// - required keys: isOutside/cid/p
/// - each key must appear exactly once
/// - aid or bvid must exist (either or both)
bool isStrictBilibiliPlayerEmbed(Uri uri) {
  if (uri.scheme != 'https') return false;
  if (uri.host != 'player.bilibili.com') return false;
  if (uri.path != '/player.html') return false;

  if (uri.queryParametersAll.isEmpty) return false;
  for (final key in uri.queryParametersAll.keys) {
    if (!_allowedBilibiliQueryKeys.contains(key)) return false;
    final values = uri.queryParametersAll[key];
    if (values == null || values.length != 1) return false;
    if (values.first.trim().isEmpty) return false;
  }
  for (final requiredKey in _requiredBilibiliQueryKeys) {
    if (!uri.queryParametersAll.containsKey(requiredKey)) {
      return false;
    }
  }

  final isOutside = uri.queryParameters['isOutside'];
  final cid = uri.queryParameters['cid'];
  final p = uri.queryParameters['p'];
  final aid = uri.queryParameters['aid'];
  final bvid = uri.queryParameters['bvid'];

  if (isOutside != 'true') return false;
  if (cid == null || int.tryParse(cid) == null || int.parse(cid) <= 0) {
    return false;
  }
  if (p == null || int.tryParse(p) == null || int.parse(p) <= 0) {
    return false;
  }
  if (aid == null && bvid == null) return false;
  if (aid != null && (int.tryParse(aid) == null || int.parse(aid) <= 0)) {
    return false;
  }
  if (bvid != null &&
      !RegExp(r'^BV[0-9A-Za-z]{10}$', caseSensitive: false).hasMatch(bvid)) {
    return false;
  }
  return true;
}
