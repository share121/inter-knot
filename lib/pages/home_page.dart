import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api_user/api_user.dart' as api_user;
import 'package:inter_knot/pages/history_page.dart';
import 'package:inter_knot/pages/liked_page.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Obx(
            () => ListTile(
              leading: const Icon(Icons.favorite),
              title: Text('Like'.tr),
              onTap: () => Get.to(() => const LikedPage()),
              subtitle: Text(
                'A total of @count items'
                    .trParams({'count': c.bookmarks.length.toString()}),
              ),
            ),
          ),
          Obx(
            () => ListTile(
              leading: const Icon(Icons.history),
              title: Text('History'.tr),
              onTap: () => Get.to(() => const HistoryPage()),
              subtitle: Text(
                'A total of @count items'
                    .trParams({'count': c.history.length.toString()}),
              ),
            ),
          ),
          FutureBuilder(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final fullVer =
                    'v${snapshot.data!.version}+${snapshot.data!.buildNumber}';
                return ListTile(
                  onTap: () => copyText(fullVer),
                  title: Text('Current version'.tr),
                  subtitle: Text(fullVer),
                );
              }
              if (snapshot.hasError) {
                return ListTile(
                  title: Text('Current version'.tr),
                  subtitle: SelectableText(snapshot.error.toString()),
                );
              }
              return ListTile(
                onTap: () {},
                title: Text('Current version'.tr),
                subtitle: const LinearProgressIndicator(),
              );
            },
          ),
          FutureBuilder(
            future: c.isLogin()
                ? api_user.getNewVersion()
                : api_root.getNewVersion(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final fullVer = 'v${snapshot.data!.version}';
                return ListTile(
                  onTap: () => launchUrlString(releasesLink),
                  title: Text('Latest version'.tr),
                  subtitle: Text(fullVer),
                );
              }
              if (snapshot.hasError) {
                return ListTile(
                  title: Text('Latest version'.tr),
                  onTap: () => launchUrlString(releasesLink),
                  subtitle: Text(snapshot.error.toString()),
                );
              }
              return ListTile(
                onTap: () => launchUrlString(releasesLink),
                title: Text('Latest version'.tr),
                subtitle: const LinearProgressIndicator(),
              );
            },
          ),
          Obx(() {
            return RadioListTile(
              value: true,
              groupValue: c.isLogin(),
              title: Text('User Api'.tr),
              onChanged: c.isLogin.call,
            );
          }),
          Obx(() {
            return RadioListTile(
              value: false,
              groupValue: c.isLogin(),
              title: Text('Common Api'.tr),
              onChanged: c.isLogin.call,
            );
          }),
          ListTile(
            onTap: () async {
              await c.pref.remove('root_token');
              await c.pref.remove('access_token');
              await c.pref.remove('refresh_token');
              Get.rawSnackbar(message: 'Login out successfully'.tr);
            },
            title: Text('Login out'.tr),
          ),
          ListTile(
            leading: Icon(MdiIcons.github),
            title: const Text('Github'),
            onTap: () => launchUrlString(githubLink),
            subtitle: const Text(githubLink),
          ),
          ListTile(
            leading: const Icon(Icons.discord),
            title: const Text('Discord'),
            onTap: () => launchUrlString(discordLink),
            subtitle: const Text(discordLink),
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: Text('Documentation'.tr),
            onTap: () => launchUrlString(docLink),
            subtitle: const Text(docLink),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: Text('Advanced Search Tips'.tr),
            onTap: () => launchUrlString(advancedSearchTipsLink),
            subtitle: const Text(advancedSearchTipsLink),
          ),
        ],
      ),
    );
  }
}
