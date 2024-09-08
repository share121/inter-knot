import 'dart:io';

void main() {
  final pem = Platform.environment['PEM'];
  final clientId = Platform.environment['CLIENT_ID'];
  final clientSecret = Platform.environment['CLIENT_SECRET'];
  File('lib/secret.dart').writeAsString(
      "import 'dart:convert'; final pem = String.fromCharCodes(base64Decode('$pem')); final clientId = String.fromCharCodes(base64Decode('$clientId')); final clientSecret = String.fromCharCodes(base64Decode('$clientSecret'));");
}
