// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void replaceUrl(String url) {
  html.window.history.replaceState(null, '', url);
}
