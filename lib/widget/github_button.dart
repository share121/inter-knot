import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data.dart';

const githubLink = 'https://github.com/$owner/$repo';

class GithubButton extends StatelessWidget {
  const GithubButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () async {
        await Clipboard.setData(const ClipboardData(text: githubLink));
        Get.rawSnackbar(
          title: 'Copied'.tr,
          message: githubLink,
        );
        await launchUrlString(githubLink);
      },
      child: const Text('Github'),
    );
  }
}
