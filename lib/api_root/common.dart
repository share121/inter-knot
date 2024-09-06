part of 'api_root.dart';

var canRequest = true;
var count = 0;

final dio = Dio(BaseOptions(
  responseType: ResponseType.json,
  headers: {'accept': 'application/json'},
  baseUrl: 'https://api.github.com',
))
  ..interceptors.addAll([
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (canRequest) {
          logger.d(
              'count: ${++count}\nRequest: ${options.uri}\nData: ${options.data}');
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
          await Future.delayed(60.s);
          canRequest = true;
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

Future<Response<T>> request<T>(
  String url, {
  Object? data,
  Map<String, dynamic>? queryParameters,
  Options? options,
}) async {
  options ??= Options();
  options.headers ??= {};
  var delay = 0.5.s;
  while (true) {
    options.headers!['Authorization'] = 'Bearer ${c.getRootToken()}';
    try {
      return await dio.request<T>(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        try {
          final accessToken = await getAccessToken();
          await c.setRootToken(accessToken);
          continue;
        } catch (e, s) {
          logger.e('Failed to get access token', error: e, stackTrace: s);
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
