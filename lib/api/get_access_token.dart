part of 'api_root.dart';

Future<String>? promise;
Future<String> getAccessToken() async {
  if (promise != null) return promise!;
  final comp = Completer<String>();
  promise = comp.future.whenComplete(() => promise = null);
  try {
    final token = await genToken();
    var res = await dio.get<Map<String, dynamic>>(
      '/repos/$owner/$repo/installation',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        extra: {'isAccessToken': true},
      ),
    );
    if (res.data?['access_tokens_url'] is! String) {
      comp.completeError(
          (message: 'Invalid access_tokens_url', rawResponse: res));
      return promise!;
    }
    res = await dio.post<Map<String, dynamic>>(
      res.data!['access_tokens_url'] as String,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        extra: {'isAccessToken': true},
      ),
    );
    if (res.data?['token'] is String) {
      comp.complete(res.data?['token'] as String);
    } else {
      comp.completeError((message: 'Invalid token', rawResponse: res));
    }
  } catch (e, s) {
    comp.completeError(e, s);
  }
  return promise!;
}
