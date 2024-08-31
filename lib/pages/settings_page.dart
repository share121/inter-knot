import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../api/api_root.dart' as api_root;
import '../common.dart';
import '../data.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Settings'.tr))],
        floatHeaderSlivers: true,
        body: SingleChildScrollView(
          child: Column(
            children: [
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
                      onTap: () => copyText(snapshot.error.toString()),
                      title: Text('Current version'.tr),
                      subtitle: Text(snapshot.error.toString()),
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
                future: api_root.getNewVersion(),
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
              ListTile(
                onTap: () async {
                  await c.pref.remove('root_token');
                  await c.pref.remove('access_token');
                  await c.pref.remove('refresh_token');
                  Get.rawSnackbar(message: 'Login out successfully'.tr);
                },
                title: Text('Login out'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
