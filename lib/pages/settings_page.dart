import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../api_user/api_user.dart';
import '../data.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
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
                future: getNewVersion(),
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
              // Obx(() {
              //   return RadioListTile(
              //     value: true,
              //     groupValue: c.isLogin(),
              //     title: Text('User Api'.tr),
              //     onChanged: c.isLogin.call,
              //   );
              // }),
              // Obx(() {
              //   return RadioListTile(
              //     value: false,
              //     groupValue: c.isLogin(),
              //     title: Text('Common Api'.tr),
              //     onChanged: c.isLogin.call,
              //   );
              // }),
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
