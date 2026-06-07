import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/api/api.dart';
import 'package:inter_knot/components/feedback_btn.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/copy_text.dart';
import 'package:inter_knot/helpers/logger.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/helpers/web_url.dart';
import 'package:inter_knot/models/device_login.dart';
import 'package:inter_knot/secret.dart';
import 'package:url_launcher/url_launcher_string.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final loginApi = Get.find<LoginApi>();

  DeviceLoginModel? deviceLogin;
  Object? error;
  bool isWebAuthLoading = false;
  Timer? _pollTimer;

  String get _redirectUri {
    final base = Uri.base;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
    ).toString();
  }

  String _randomUrlSafe(int length) {
    final rand = Random.secure();
    final bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  Future<void> _startWebOAuth() async {
    setState(() {
      error = null;
      isWebAuthLoading = true;
    });
    final verifier = _randomUrlSafe(64);
    final state = _randomUrlSafe(24);
    await box.write('oauth_state', state);
    await box.write('oauth_code_verifier', verifier);
    final challenge = _codeChallenge(verifier);
    final url = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': clientId,
      'redirect_uri': _redirectUri,
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    }).toString();
    await launchUrlString(url);
  }

  Future<void> _handleWebOAuthRedirect() async {
    final params = Uri.base.queryParameters;
    if (!params.containsKey('code') && !params.containsKey('error')) {
      return;
    }
    replaceUrl(_redirectUri);
    setState(() {
      isWebAuthLoading = true;
      error = null;
    });
    final errorParam = params['error'];
    if (errorParam != null) {
      setState(() {
        isWebAuthLoading = false;
        error = params['error_description'] ?? errorParam;
      });
      return;
    }
    final code = params['code'];
    final state = params['state'];
    final savedState = box.read('oauth_state') as String?;
    final verifier = box.read('oauth_code_verifier') as String?;
    if (code == null || state == null || savedState != state || verifier == null) {
      await box.remove('oauth_state');
      await box.remove('oauth_code_verifier');
      setState(() {
        isWebAuthLoading = false;
        error = 'Invalid OAuth state. Please retry.'.tr;
      });
      return;
    }
    try {
      final token = await loginApi.getAccessTokenByCode(
        code: code,
        redirectUri: _redirectUri,
        codeVerifier: verifier,
      );
      await box.remove('oauth_state');
      await box.remove('oauth_code_verifier');
      await box.write('access_token', token);
      if (Get.isRegistered<Controller>()) {
        final c = Get.find<Controller>();
        c.isLogin(true);
        c.fetchPinnedDiscussions();
        c.refreshSearchData();
        if (Get.isRegistered<Api>()) {
          Get.find<Api>().getSelfUserInfo().then<void>(
            c.user.call,
            onError: (Object e, StackTrace s) {
              logger.e(e, stackTrace: s);
            },
          );
        }
      }
      if (mounted) Get.back();
    } catch (e) {
      if (mounted) {
        await box.remove('oauth_state');
        await box.remove('oauth_code_verifier');
        setState(() {
          isWebAuthLoading = false;
          error = e;
        });
      }
    }
  }

  Future<void> poll() async {
    if (deviceLogin == null) return;
    try {
      final r = await loginApi.getAccessToken(deviceLogin!);
      switch (r.status) {
        case DeviceLoginStatus.expiredToken:
        case DeviceLoginStatus.accessDenied:
          return refresh();
        case DeviceLoginStatus.finished:
          await box.write('access_token', r.accessToken);
          if (Get.isRegistered<Controller>()) {
            final c = Get.find<Controller>();
            c.isLogin(true);
            await c.handleLoginSuccess();
          }
          Get.back();
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
              ),
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
    _pollTimer?.cancel();
    try {
      final data = await loginApi.getDeviceLogin();
      if (mounted) {
        _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          try {
            await poll();
          } catch (e, s) {
            logger.e('Poll failed', error: e, stackTrace: s);
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
    if (kIsWeb) {
      _handleWebOAuthRedirect();
    } else {
      refresh();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Login'.tr)),
      body: Builder(
        builder: (context) {
          if (kIsWeb) {
            if (isWebAuthLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (error != null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(error.toString()),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _startWebOAuth,
                        child: Text('Login with GitHub'.tr),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(
              child: FilledButton(
                onPressed: _startWebOAuth,
                child: Text('Login with GitHub'.tr),
              ),
            );
          }
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
                          TextSpan(
                            children: [
                              TextSpan(text: 'Open'.tr),
                              const TextSpan(text: ' '),
                              TextSpan(
                                text: deviceLogin!.verificationUri,
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () => launchUrlString(
                                        deviceLogin!.verificationUri,
                                      ),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              TextSpan(
                                text: ' . Then enter the 「user code」'.tr,
                              ),
                            ],
                          ),
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
                            return Text(
                              '@s seconds left'.trParams({'s': v.toString()}),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {
                            final url = deviceLogin!.verificationUri;
                            Future.delayed(3.s)
                                .then((_) => launchUrlString(url));
                            copyText(
                              deviceLogin!.userCode,
                              title: 'User code has been copied'.tr,
                              msg:
                                  'Jump to the authorization page after 3 seconds'
                                      .tr,
                            );
                          },
                          child: Text('Copy and open'.tr),
                        ),
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
                  ],
                ),
              ),
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: kIsWeb ? _startWebOAuth : refresh,
        tooltip: 'Refresh'.tr,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
