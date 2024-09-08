part of 'api_root.dart';

String genToken() {
  final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final jwt = JWT({'iat': time, 'exp': time + 60, 'iss': clientId});
  final token = jwt.sign(RSAPrivateKey(pem), algorithm: JWTAlgorithm.RS256);
  return token;
}
