import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';

final dio = Dio(BaseOptions(
  responseType: ResponseType.json,
  headers: {'accept': 'application/json'},
  baseUrl: 'https://api.github.com',
))
  ..interceptors.addAll([
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // ignore: avoid_print
        print('Request');
        // ignore: avoid_print
        print(options.uri);
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // ignore: avoid_print
        print('Response');
        // ignore: avoid_print
        print(response.requestOptions.uri);
        // ignore: avoid_print
        // print(response.data);
        return handler.next(response);
      },
      onError: (error, handler) {
        // ignore: avoid_print
        print('Error');
        // ignore: avoid_print
        print(error.requestOptions.uri);
        // ignore: avoid_print
        print(error.response?.data);
        return handler.next(error);
      },
    ),
  ]);

Future<Response<Map<String, dynamic>>> graphql(String data) async =>
    dio.post('/graphql', data: jsonEncode({'query': data}));

String encode(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\r', '\\r')
    .replaceAll('\n', '\\n');

typedef Nodes<T> = ({List<T> res, bool hasNextPage, String? endCursor});

({String html, String? cover}) parseHtml(String html,
    [bool isComment = false]) {
  final document = parseFragment(html);
  if (isComment == false) {
    final img = document.querySelector('img');
    final cover = img?.attributes['src'];
    img?.remove();
    var parent = img?.parent;
    while (parent != null && parent.nodes.isEmpty) {
      parent.remove();
      parent = parent.parent;
    }
    return (html: document.outerHtml, cover: cover);
  }
  return (html: document.outerHtml, cover: null);
}
