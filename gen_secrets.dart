import 'dart:io';

void main() {
  final pwd = Platform.environment['PWD'];
  final pem = Platform.environment['PEM'];
  final clientId = Platform.environment['CLIENT_ID'];
  final clientSecret = Platform.environment['CLIENT_SECRET'];
  File('lib/secret.dart').writeAsString(
      "const pem = '''$pem'''; const clientId = '$clientId'; const clientSecret = '$clientSecret';");
  File('android/key.properties').writeAsString(
      'storePassword=$pwd\nkeyPassword=$pwd\nkeyAlias=upload\nstoreFile=../../upload-keystore.jks');
}
