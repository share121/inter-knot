import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data.dart';

class FeedbackBtn extends StatelessWidget {
  const FeedbackBtn(this.error, {super.key});

  final String error;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        Future.delayed(3.s).then((_) => launchUrlString(issuesLink));
        await copyText(
          error,
          title: 'The error message has been copied.'.tr,
          msg: 'The GitHub Issues page automatically opens after 3 seconds'.tr,
        );
      },
      child: Text('Feedback'.tr),
    );
  }
}
