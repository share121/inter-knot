import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/snack.dart';

Future<bool> copyText(String text, {String? msg, String? title}) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    showSnack(msg ?? 'Copied'.tr, title: title);
    return true;
  } catch (e, s) {
    logger.e('Copy failed', stackTrace: s, error: e);
    showSnack('Copy failed'.tr);
    return false;
  }
}
