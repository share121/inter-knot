import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'history_page.dart';
import 'liked_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.favorite),
            title: Text('Like'.tr),
            onTap: () => Get.to(() => const LikedPage()),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text('History'.tr),
            onTap: () => Get.to(() => const HistoryPage()),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text('Settings'.tr),
            onTap: () => Get.to(() => const SettingsPage()),
          ),
        ],
      ),
    );
  }
}
