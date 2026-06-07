import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:inter_knot/helpers/chat_mockup_audio_url_validator.dart';
import 'package:inter_knot/helpers/chat_mockup_file_image.dart' as file_img;
import 'package:inter_knot/helpers/chat_mockup_resource_blob.dart' as blob;
import 'package:inter_knot/helpers/chat_mockup_resource_fetch.dart';
import 'package:inter_knot/helpers/chat_mockup_resource_native.dart' as native_cache;

enum ResourceLocalState {
  pending,
  downloading,
  ready,
  failed,
}

class ChatMockupPrefetchResult {
  const ChatMockupPrefetchResult({
    required this.total,
    required this.readyCount,
    required this.failedUrls,
    this.failureDetails = const {},
  });

  final int total;
  final int readyCount;
  final List<String> failedUrls;

  /// URL → short error text from the last fetch/write attempt.
  final Map<String, String> failureDetails;

  bool get allSucceeded => failedUrls.isEmpty;
}

class _Entry {
  _Entry({
    required this.state,
    this.nativePath,
    this.webObjectUrl,
    this.error,
  });

  ResourceLocalState state;
  String? nativePath;
  String? webObjectUrl;
  Object? error;
}

/// Session-scoped URL → local file (IO) or blob URL (web). Not serialized to JSON.
class ChatMockupResourceCache {
  ChatMockupResourceCache();

  static const maxBytesPerResource = 50 * 1024 * 1024;
  static const downloadTimeout = Duration(seconds: 60);

  final Map<String, _Entry> _entries = {};
  int generation = 0;

  void bumpGeneration() {
    generation++;
  }

  bool isStale(int gen) => gen != generation;

  void clear() {
    for (final e in _entries.values) {
      blob.revokeResourceBlobUrl(e.webObjectUrl);
    }
    _entries.clear();
  }

  ResourceLocalState? stateOf(String url) {
    return _entries[url.trim()]?.state;
  }

  ImageProvider? tryCachedImageProvider(String url) {
    final e = _entries[url.trim()];
    if (e == null || e.state != ResourceLocalState.ready) return null;
    if (kIsWeb) {
      final b = e.webObjectUrl;
      if (b == null || b.isEmpty) return null;
      return NetworkImage(b);
    }
    final p = e.nativePath;
    if (p == null || p.isEmpty) return null;
    return file_img.chatMockupFileImage(p);
  }

  /// Returns native absolute path for [AudioPlayer.setFilePath], or blob URL
  /// for [AudioPlayer.setUrl] on web. Null if not ready.
  String? audioPlaybackHandle(String remoteUrl) {
    final e = _entries[remoteUrl.trim()];
    if (e == null || e.state != ResourceLocalState.ready) return null;
    if (kIsWeb) {
      return e.webObjectUrl;
    }
    return e.nativePath;
  }

  Future<ChatMockupPrefetchResult> prefetchUrls(
    List<String> urls, {
    required int gen,
    void Function(int done, int total)? onProgress,
  }) async {
    final unique = urls.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    final total = unique.length;
    if (total == 0) {
      onProgress?.call(0, 0);
      return const ChatMockupPrefetchResult(
        total: 0,
        readyCount: 0,
        failedUrls: [],
      );
    }
    var completed = 0;
    void report() {
      onProgress?.call(completed, total);
    }

    for (var i = 0; i < unique.length; i += 4) {
      if (isStale(gen)) break;
      final end = (i + 4) > unique.length ? unique.length : i + 4;
      final batch = unique.sublist(i, end);
      await Future.wait(batch.map((u) => _downloadOne(u, gen)));
      completed += batch.length;
      report();
    }

    final failed = <String>[];
    final failureDetails = <String, String>{};
    var ready = 0;
    for (final u in unique) {
      final s = _entries[u]?.state;
      if (s == ResourceLocalState.ready) {
        ready++;
      } else {
        failed.add(u);
        final err = _entries[u]?.error;
        failureDetails[u] =
            err != null ? describePrefetchFetchError(err) : '未知错误';
      }
    }
    return ChatMockupPrefetchResult(
      total: total,
      readyCount: ready,
      failedUrls: failed,
      failureDetails: failureDetails,
    );
  }

  /// Human-readable for prefetch failure UI (no `dart:io` import — works on web).
  static String describePrefetchFetchError(Object e) {
    if (e is FormatException) {
      final m = e.message;
      if (m.isNotEmpty) return m;
    }
    return e.toString();
  }

  Future<void> _downloadOne(String url, int gen) async {
    final key = url.trim();
    final existing = _entries[key];
    if (existing?.state == ResourceLocalState.ready) return;
    if (isStale(gen)) return;

    // Native: reuse on-disk file from a prior session before any network I/O.
    if (!kIsWeb) {
      try {
        final dir = await native_cache.ensureChatMockupNativeCacheDir();
        if (isStale(gen)) return;
        final name =
            '${sha256.convert(utf8.encode(key))}${_extFromUrl(key)}';
        final diskHit =
            await native_cache.pathIfChatMockupCacheFileReady(dir, name);
        if (diskHit != null) {
          if (!isStale(gen)) {
            _entries[key] = _Entry(
              state: ResourceLocalState.ready,
              nativePath: diskHit,
            );
          }
          return;
        }
      } catch (e) {
        if (!isStale(gen)) {
          _entries[key] = _Entry(
            state: ResourceLocalState.failed,
            error: e,
          );
        }
        return;
      }
    }

    _entries[key] = _Entry(state: ResourceLocalState.downloading);

    try {
      final resp = await fetchChatMockupResource(
        key,
        downloadTimeout,
        maxBytesPerResource,
      );
      if (isStale(gen)) {
        _entries.remove(key);
        return;
      }
      // Full GET should usually be 200; some CDNs respond 206 (e.g. Range
      // semantics). Reject other codes (incl. redirect bodies if not followed).
      if (resp.statusCode != 200 && resp.statusCode != 206) {
        throw FormatException('HTTP ${resp.statusCode}');
      }
      if (resp.bodyBytes.isEmpty) {
        throw const FormatException('empty body');
      }

      if (kIsWeb) {
        final mime = _guessMime(key, resp.contentType);
        final objectUrl = blob.createResourceBlobUrl(resp.bodyBytes, mime);
        if (isStale(gen)) {
          blob.revokeResourceBlobUrl(objectUrl);
          _entries.remove(key);
          return;
        }
        _entries[key] = _Entry(
          state: ResourceLocalState.ready,
          webObjectUrl: objectUrl,
        );
      } else {
        final dir = await native_cache.ensureChatMockupNativeCacheDir();
        if (isStale(gen)) {
          _entries.remove(key);
          return;
        }
        final name =
            '${sha256.convert(utf8.encode(key))}${_extFromUrl(key)}';
        final path = await native_cache.writeChatMockupCacheFile(
          dir,
          name,
          resp.bodyBytes,
        );
        if (isStale(gen)) {
          _entries.remove(key);
          return;
        }
        _entries[key] = _Entry(
          state: ResourceLocalState.ready,
          nativePath: path,
        );
      }
    } catch (e) {
      if (!isStale(gen)) {
        _entries[key] = _Entry(
          state: ResourceLocalState.failed,
          error: e,
        );
      } else {
        _entries.remove(key);
      }
    }
  }

  static String _extFromUrl(String url) {
    final lower = url.toLowerCase();
    final q = lower.split('?').first;
    if (q.endsWith('.png')) return '.png';
    if (q.endsWith('.jpg') || q.endsWith('.jpeg')) return '.jpg';
    if (q.endsWith('.webp')) return '.webp';
    if (q.endsWith('.gif')) return '.gif';
    for (final ext in ChatMockupAudioUrlValidator.allowedAudioPathSuffixes) {
      if (q.endsWith(ext)) return ext;
    }
    return '.bin';
  }

  static String _guessMime(String url, String? contentType) {
    final ct = contentType?.split(';').first.trim();
    if (ct != null && ct.isNotEmpty) return ct;
    final ext = _extFromUrl(url);
    switch (ext) {
      case '.mp3':
        return 'audio/mpeg';
      case '.m4a':
        return 'audio/mp4';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.opus':
        return 'audio/opus';
      case '.wav':
        return 'audio/wav';
      case '.flac':
        return 'audio/flac';
      case '.webm':
        return 'audio/webm';
      case '.png':
        return 'image/png';
      case '.jpg':
        return 'image/jpeg';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }
}
