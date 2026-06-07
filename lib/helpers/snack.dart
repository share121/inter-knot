import 'package:flutter/material.dart';
import 'package:get/get.dart';

void showSnack(String message, {String? title}) {
  Get.rawSnackbar(
    titleText: title == null ? null : SelectableText(title),
    messageText: SelectableText(message),
  );
}

void showErrorSnack(Object error, [StackTrace? stackTrace]) {
  final details = stackTrace == null ? error.toString() : '$error\n\n$stackTrace';
  Get.rawSnackbar(
    titleText: SelectableText('Error'.tr),
    messageText: SelectableText(details),
  );
}
