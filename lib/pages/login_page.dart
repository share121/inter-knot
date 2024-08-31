import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:schedulers/schedulers.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

import '../api_user/api_user.dart' as api_user;
import '../common.dart';
import '../widget/discord_button.dart';
import '../widget/doc_button.dart';
import '../widget/feedback_btn.dart';
import '../widget/github_button.dart';
import '../widget/window_buttons.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  api_user.DeviceLogin? deviceLogin;
  Object? error;
  final getDeviceSch = LazyScheduler(latency: 5.s);
  var count = 0;

  Future<void> poll() async {
    if (deviceLogin == null) return;
    try {
      final r = await api_user.getAccessToken(deviceLogin!);
      switch (r.status) {
        case api_user.DeviceLoginStatus.expiredToken:
        case api_user.DeviceLoginStatus.accessDenied:
          return refresh();
        case api_user.DeviceLoginStatus.finished:
          await c.setToken(r.accessToken!);
          await c.setRefreshToken(r.refreshToken!);
          Get.back();
        case api_user.DeviceLoginStatus.authorizationPending:
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

  void refresh([bool isFirst = false]) {
    count++;
    setState(() {
      error = null;
      deviceLogin = null;
    });
    Future<void> fn() async {
      try {
        final data = await api_user.getDeviceLogin();
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
    }

    if (isFirst) {
      fn();
    } else {
      getDeviceSch.run(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    refresh(true);
  }

  @override
  void dispose() {
    count++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: DragToMoveArea(child: Text('Login'.tr)),
        flexibleSpace: const DragToMoveArea(child: SizedBox.expand()),
        actions: [
          if (MediaQuery.sizeOf(context).width > 410 - (isDesktop ? 0 : 138))
            const DocButton(),
          if (MediaQuery.sizeOf(context).width > 370 - (isDesktop ? 0 : 138))
            const DiscordButton(),
          if (MediaQuery.sizeOf(context).width > 330 - (isDesktop ? 0 : 138))
            const GithubButton(),
          if (MediaQuery.sizeOf(context).width > 322 - (isDesktop ? 0 : 138))
            const SizedBox(width: 8),
          if (isDesktop) const WindowButtons(),
        ],
        elevation: 4,
      ),
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
                child: SelectableText(error.toString()),
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
