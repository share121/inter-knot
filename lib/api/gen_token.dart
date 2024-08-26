import 'dart:async';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter/services.dart';

import '../data.dart';

final pem = rootBundle.loadString('assets/private_key.pem');
Future<String> genToken() async {
  final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final jwt = JWT({'iat': time, 'exp': time + 60, 'iss': clientId});
  final token =
      jwt.sign(RSAPrivateKey(await pem), algorithm: JWTAlgorithm.RS256);
  return token;
}
