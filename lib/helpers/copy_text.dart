import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:inter_knot/helpers/logger.dart';

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
