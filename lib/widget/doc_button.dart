import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../data.dart';

class DocButton extends StatelessWidget {
  const DocButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => launchUrlString(docLink),
      tooltip: 'Documentation'.tr,
      icon: const Icon(Icons.book_outlined),
    );
  }
}
