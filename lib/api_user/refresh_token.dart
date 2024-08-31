part of 'api_user.dart';

Future<bool>? promise;
Future<bool> refreshToken() async {
  if (promise != null) return promise!;
  final comp = Completer<bool>();
  promise = comp.future.whenComplete(() => promise = null);
  try {
    final refreshToken = c.getRefreshToken();
    if (!refreshToken.startsWith('ghr_')) {
      comp.complete(false);
      return promise!;
    }
    final r = await dio.post<Map<String, dynamic>>(
        'https://github.com/login/oauth/access_token',
        queryParameters: {
          'client_id': clientId,
          'grant_type	': 'refresh_token',
          'refresh_token': c.getRefreshToken(),
        });
    if (r.data
        case {
          'access_token': final String accessToken,
          'refresh_token': final String refreshToken
        }
        when accessToken.startsWith('ghu_') &&
            refreshToken.startsWith('ghr_')) {
      await c.setToken(accessToken);
      await c.setRefreshToken(refreshToken);
      comp.complete(true);
    } else {
      comp.complete(false);
    }
  } catch (e, s) {
    comp.completeError(e, s);
  }
  return promise!;
}
