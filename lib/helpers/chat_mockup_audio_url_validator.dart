/// Validates knock-knock preview music URLs: HTTPS / localhost shape and a
/// known **audio file extension** on the path. Reachability and bytes are
/// verified at **prefetch download** in the resource cache (not here).
class ChatMockupAudioUrlValidator {
  ChatMockupAudioUrlValidator._();

  /// Longer suffixes first (e.g. `.m4a` before any hypothetical `.m`).
  static const List<String> allowedAudioPathSuffixes = [
    '.m4a',
    '.mp3',
    '.opus',
    '.flac',
    '.webm',
    '.ogg',
    '.aac',
    '.wav',
  ];

  /// Whether [pathLower] (already lowercased path, query stripped upstream)
  /// ends with one of [allowedAudioPathSuffixes].
  static bool pathHasAllowedAudioSuffix(String pathLower) {
    for (final ext in allowedAudioPathSuffixes) {
      if (pathLower.endsWith(ext)) return true;
    }
    return false;
  }

  /// HTTPS / localhost rules plus a supported audio extension on the path
  /// (query allowed).
  static void assertPlayableUrlShape(String normalizedUrl) {
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) {
      throw const FormatException('Invalid music URL.');
    }
    if (uri.scheme == 'https') {
      // ok
    } else if (uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      // allow localhost in development
    } else {
      throw const FormatException('Only https music URL is supported.');
    }
    if (uri.host.trim().isEmpty) {
      throw const FormatException('Invalid music URL host.');
    }
    if (uri.path.trim().isEmpty) {
      throw const FormatException('Invalid music URL path.');
    }
    final pathLower = uri.path.toLowerCase();
    if (!pathHasAllowedAudioSuffix(pathLower)) {
      throw FormatException(
        '音乐 URL 路径须以支持的音频扩展名结尾（如 '
        '${allowedAudioPathSuffixes.take(4).join('、')} 等；可带查询参数）。',
      );
    }
  }

  /// Shape-only check for save/import (no network I/O).
  static Future<void> validateForSaveOrImport(String url) async {
    assertPlayableUrlShape(url.trim());
  }
}
