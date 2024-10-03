import 'dart:io';

void main() {
  final pem = Platform.environment['PEM'];
  final clientId = Platform.environment['CLIENT_ID'];
  final clientSecret = Platform.environment['CLIENT_SECRET'];
  File('lib/secret.dart').writeAsString(
    "import 'dart:convert';\nfinal pem = String.fromCharCodes(base64Decode('$pem'));\nfinal clientId = String.fromCharCodes(base64Decode('$clientId'));\nfinal clientSecret = String.fromCharCodes(base64Decode('$clientSecret'));",
  );
}
