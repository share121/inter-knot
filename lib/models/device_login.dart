import 'package:inter_knot/helpers/num2dur.dart';

class DeviceLoginModel {
  String deviceCode;
  String userCode;
  String verificationUri;
  int expiresIn;
  int interval;
  DateTime expiresAt;

  Stream<int> getExpiresIn() => Stream.periodic(1.s).map((_) {
        final now = DateTime.now();
        final diff = expiresAt.difference(now);
        return diff.inSeconds.clamp(0, expiresIn);
      });

  DeviceLoginModel.fromJson(Map<String, dynamic> json)
      : deviceCode = json['device_code'] as String,
        userCode = json['user_code'] as String,
        verificationUri = json['verification_uri'] as String,
        expiresIn = json['expires_in'] as int,
        interval = json['interval'] as int,
        expiresAt = DateTime.now().add((json['expires_in'] as int).s);
}

enum DeviceLoginStatus {
  authorizationPending,
  expiredToken,
  accessDenied,
  finished,
}
