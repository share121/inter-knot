part of 'api_user.dart';

Future<({DeviceLoginStatus status, String? accessToken, String? refreshToken})>
    getAccessToken(DeviceLogin deviceLogin) async {
  final res = await dio.post<Map<String, dynamic>>(
      'https://github.com/login/oauth/access_token',
      queryParameters: {
        'client_id': clientId,
        'device_code': deviceLogin.deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      });
  if (res.data == null) throw Exception('Failed to get access token');
  if (res.data!['error'] == 'authorization_pending') {
    return (
      status: DeviceLoginStatus.authorizationPending,
      accessToken: null,
      refreshToken: null,
    );
  }
  if (res.data!['error'] == 'expired_token') {
    return (
      status: DeviceLoginStatus.expiredToken,
      accessToken: null,
      refreshToken: null,
    );
  }
  if (res.data!['error'] == 'access_denied') {
    return (
      status: DeviceLoginStatus.accessDenied,
      accessToken: null,
      refreshToken: null,
    );
  }
  if (res.data
      case {
        'access_token': String accessToken,
        'refresh_token': String refreshToken
      }) {
    return (
      status: DeviceLoginStatus.finished,
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
  throw Exception('Invalid response: $res');
}
