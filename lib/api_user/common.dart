part of 'api_user.dart';

var canRequest = true;

final dio = Dio(BaseOptions(
  responseType: ResponseType.json,
  headers: {'accept': 'application/json'},
  baseUrl: 'https://api.github.com',
))
  ..interceptors.addAll([
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (canRequest) {
          logger.d('Request: ${options.uri}\nData: ${options.data}');
          return handler.next(options);
        } else {
          return handler.reject(DioException.requestCancelled(
              requestOptions: options, reason: 'RATE_LIMITED'));
        }
      },
      onResponse: (response, handler) async {
        // logger.d(
        //     'Response: ${response.requestOptions.uri}\nResponse: ${response.data}');
        // ignore: avoid_dynamic_calls
        if (response.data?['errors']?[0]?['type'] == 'RATE_LIMITED') {
          showDialog(
            context: Get.context!,
            builder: (context) {
              return AlertDialog(
                title: Text('Error: API rate limit reached'.tr),
                content: SelectableText('Please try again later'.tr),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('OK'.tr),
                  ),
                ],
              );
            },
          );
          canRequest = false;
          Future.delayed(60.s).then((_) => canRequest = true);
          return handler.reject(
            DioException.requestCancelled(
              requestOptions: response.requestOptions,
              reason: 'RATE_LIMITED',
            ),
          );
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        logger.e(
          'Error: ${error.requestOptions.uri}\nResponse: ${error.response?.data}',
          error: error,
          stackTrace: error.stackTrace,
        );
        // final msg =
        //     'Error: ${error.requestOptions.uri}\n\nResponse:\n${error.response?.data}\n\nError Object:\n$error\n\nStack Trace:\n${error.stackTrace}';
        // showDialog(
        //   context: Get.context!,
        //   builder: (context) {
        //     return AlertDialog(
        //       title: Text('Error: ${error.requestOptions.uri}'),
        //       content: SelectableText(msg),
        //       actions: [
        //         FeedbackBtn(msg),
        //         TextButton(
        //           onPressed: () => Get.back(),
        //           child: Text('OK'.tr),
        //         ),
        //       ],
        //     );
        //   },
        // );
        return handler.next(error);
      },
    ),
  ]);

class DeviceLogin {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;
  final DateTime expiresAt;

  Stream<int> getExpiresIn() {
    final expiresAt = this.expiresAt;
    return Stream.periodic(1.s).map((_) {
      final now = DateTime.now();
      final diff = expiresAt.difference(now);
      return diff.inSeconds.clamp(0, expiresIn);
    });
  }

  DeviceLogin.fromJson(Map<String, dynamic> json)
      : deviceCode = json['device_code'],
        userCode = json['user_code'],
        verificationUri = json['verification_uri'],
        expiresIn = json['expires_in'],
        interval = json['interval'],
        expiresAt = DateTime.now().add(Duration(seconds: json['expires_in']));
}

Future<DeviceLogin> getDeviceLogin() async {
  final r = await dio.post<Map<String, dynamic>>(
      'https://github.com/login/device/code',
      queryParameters: {'client_id': clientId});
  if (r.data == null) throw Exception('Failed to get device code');
  return DeviceLogin.fromJson(r.data!);
}

enum DeviceLoginStatus {
  authorizationPending,
  expiredToken,
  accessDenied,
  finished,
}

Future<Response<T>> request<T>(
  String url, {
  Object? data,
  Map<String, dynamic>? queryParameters,
  Options? options,
}) async {
  options ??= Options();
  options.headers ??= {};
  var delay = 1.s;
  while (true) {
    options.headers!['Authorization'] = 'Bearer ${c.getToken()}';
    try {
      if (!c.getToken().startsWith('ghu_')) {
        throw DioException(
          requestOptions: RequestOptions(),
          error: 'NOT_LOGGED_IN',
        );
      }
      return await dio.request<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.error == 'NOT_LOGGED_IN') {
        await Future(() => Get.to(() => const LoginPage()));
      }
      if (e.response?.statusCode == 401) {
        try {
          if (!await refreshToken()) {
            await Future(() => Get.to(() => const LoginPage()));
          }
        } catch (e, s) {
          logger.e('Failed to refresh token', error: e, stackTrace: s);
          await Future(() => Get.to(() => const LoginPage()));
        }
      }
    }
    await Future.delayed(delay);
    delay += 1.s;
  }
}

Future<Response<Map<String, dynamic>>> graphql(String data) async =>
    request('/graphql',
        data: jsonEncode({'query': data}), options: Options(method: 'POST'));
