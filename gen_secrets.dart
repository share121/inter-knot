import 'dart:io';

void main() {
  final clientId = Platform.environment['CLIENT_ID'];
  if (clientId == null || clientId.isEmpty) {
    return;
  }
  File('lib/secret.dart').writeAsString(
    "import 'dart:convert';\nfinal clientId = String.fromCharCodes(base64Decode('$clientId'));\n",
  );
}
