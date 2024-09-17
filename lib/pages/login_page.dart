import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../api_user/api_user.dart';
import '../common.dart';
import '../widget/feedback_btn.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  DeviceLogin? deviceLogin;
  Object? error;
  var count = 0;

  Future<void> poll() async {
    if (deviceLogin == null) return;
    try {
      final r = await getAccessToken(deviceLogin!);
      switch (r.status) {
        case DeviceLoginStatus.expiredToken:
        case DeviceLoginStatus.accessDenied:
          return refresh();
        case DeviceLoginStatus.finished:
          await c.setToken(r.accessToken!);
          await c.setRefreshToken(r.refreshToken!);
          Get.back();
          break;
        case DeviceLoginStatus.authorizationPending:
      }
    } catch (e) {
      showDialog(
        context: Get.context!,
        builder: (context) {
          return AlertDialog(
            title: Text('Error: Failed to get access token'.tr),
            content: Text(e.toString()),
            actions: [
              FeedbackBtn('Error: Failed to get access token\n\n$e'),
              TextButton(
                onPressed: () => Get.back(),
                child: Text('OK'.tr),
              )
            ],
          );
        },
      );
    }
  }

  late final refresh = throttle(() async {
    setState(() {
      error = null;
      deviceLogin = null;
    });
    try {
      final data = await getDeviceLogin();
      if (mounted) {
        Timer.run(() async {
          final inner = count;
          while (true) {
            if (inner != count) return;
            try {
              await poll();
              await Future.delayed(5.s);
            } catch (e, s) {
              logger.e('Poll failed', error: e, stackTrace: s);
            }
          }
        });
        setState(() {
          error = null;
          deviceLogin = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e;
          deviceLogin = null;
        });
      }
    }
  });

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    count++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login'.tr)),
      body: Builder(
        builder: (context) {
          if (deviceLogin != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'User Code'.tr,
                          style: const TextStyle(fontSize: 20),
                        ),
                        SelectableText(
                          deviceLogin!.userCode,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(text: 'Open'.tr),
                            const TextSpan(text: ' '),
                            TextSpan(
                              text: deviceLogin!.verificationUri,
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchUrlString(
                                    deviceLogin!.verificationUri),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            TextSpan(text: ' . Then enter the 「user code」'.tr),
                          ]),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder(
                          stream: deviceLogin!.getExpiresIn(),
                          builder: (context, snapshot) {
                            final v = snapshot.data;
                            if (v == null) return const SizedBox.shrink();
                            if (v == 0) {
                              return Text('User code has expired'.tr);
                            }
                            return Text('@s seconds left'
                                .trParams({'s': v.toString()}));
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            final url = deviceLogin!.verificationUri;
                            Future.delayed(3.s)
                                .then((_) => launchUrlString(url));
                            copyText(
                              deviceLogin!.userCode.toString(),
                              title: 'User code has been copied'.tr,
                              msg:
                                  'Jump to the authorization page after 3 seconds'
                                      .tr,
                            );
                          },
                          child: Text('Copy and open'.tr),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          if (error != null) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SelectableText(error.toString()),
                    if (kIsWeb) ...[
                      const SizedBox(height: 16),
                      Text('You May Need to Allow CORS Extensions'.tr),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: () => launchUrlString(
                                'https://microsoftedge.microsoft.com/addons/detail/allow-cors-accesscontro/bhjepjpgngghppolkjdhckmnfphffdag'),
                            child: Text('Edge Extension'.tr),
                          ),
                          FilledButton(
                            onPressed: () => launchUrlString(
                                'https://chromewebstore.google.com/detail/allow-cors-access-control/lhobafahddgcelffkeicbaginigeejlf'),
                            child: Text('Chrome Extension'.tr),
                          ),
                          FilledButton(
                            onPressed: () => launchUrlString(
                                'https://addons.mozilla.org/en-US/firefox/addon/access-control-allow-origin/'),
                            child: Text('Firefox Extension'.tr),
                          ),
                          FilledButton(
                            onPressed: () => launchUrlString(
                                'https://www.crxsoso.com/webstore/detail/lhobafahddgcelffkeicbaginigeejlf'),
                            child: Text('Crx Soso'.tr),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: refresh,
        tooltip: 'Refresh'.tr,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
