part of 'api_user.dart';

final pem = rootBundle.loadString(Assets.privateKey);
Future<String> genToken() async {
  final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final jwt = JWT({'iat': time, 'exp': time + 60, 'iss': clientId});
  final token =
      jwt.sign(RSAPrivateKey(await pem), algorithm: JWTAlgorithm.RS256);
  return token;
}
