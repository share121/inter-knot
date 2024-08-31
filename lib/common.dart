import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'data.dart';

final logger = Logger();
final c = Get.find<Controller>();
final isDesktop = !kIsWeb && GetPlatform.isDesktop;

extension Use<V> on V? {
  T? use<T>(T Function(V value) fn) => this == null ? null : fn(this as V);
}

extension True on bool {
  T? isTrue<T>(T Function() fn) => this ? fn() : null;
  T? isFalse<T>(T Function() fn) => !this ? fn() : null;
}

extension Num2Duration on num {
  Duration get microseconds => Duration(microseconds: toInt());
  Duration get ms => (this * 1000).microseconds;
  Duration get s => (this * 1000).ms;
  Duration get min => (this * 60).s;
  Duration get hour => (this * 60).min;
  Duration get day => (this * 24).hour;
  Duration get week => (this * 7).day;
}

extension DurationFomater on Duration {
  /// MM:SS
  String get format =>
      '${inMinutes.toString().padLeft(2, '0')}:${inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

Future<bool> copyText(String text, {String? msg, String? title}) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    Get.rawSnackbar(title: title, message: msg ?? 'Copied'.tr);
    return true;
  } catch (e, s) {
    logger.e('Copy failed', stackTrace: s, error: e);
    Get.rawSnackbar(message: 'Copy failed'.tr);
    return false;
  }
}
