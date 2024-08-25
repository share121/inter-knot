import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide Response;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:html/parser.dart';

import 'data.dart';

final c = Get.find<Controller>();

final Dio dio = Dio(BaseOptions(
  responseType: ResponseType.json,
  headers: {'accept': 'application/json'},
  baseUrl: 'https://api.github.com',
))
  ..interceptors.addAll([
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // ignore: avoid_print
        print(options.uri);
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
    ),
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!options.headers.containsKey('Authorization')) {
          options.headers['Authorization'] = 'Bearer ${c.getToken()}';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        final response = error.response;
        if (response == null) return handler.next(error);
        if (response.statusCode == 401) {
          if (response.requestOptions.extra['isRefreshToken'] == true) {
            return handler.reject(DioException(
              requestOptions: response.requestOptions,
              message: 'Unauthorized, url: ${response.requestOptions.uri}',
              response: response,
              type: DioExceptionType.unknown,
            ));
          } else {
            while (true) {
              final token = await getAccessToken();
              if (token != null) {
                await c.setToken(token);
                final res = await dio.requestUri<Map<String, dynamic>>(
                  response.requestOptions.uri,
                  data: response.requestOptions.data,
                  cancelToken: response.requestOptions.cancelToken,
                  onReceiveProgress: response.requestOptions.onReceiveProgress,
                  onSendProgress: response.requestOptions.onSendProgress,
                  options: Options(
                    contentType: response.requestOptions.contentType,
                    headers: {
                      ...response.requestOptions.headers,
                      'Authorization': 'Bearer $token'
                    },
                    validateStatus: response.requestOptions.validateStatus,
                    extra: response.requestOptions.extra,
                    followRedirects: response.requestOptions.followRedirects,
                    maxRedirects: response.requestOptions.maxRedirects,
                    sendTimeout: response.requestOptions.sendTimeout,
                    receiveTimeout: response.requestOptions.receiveTimeout,
                    requestEncoder: response.requestOptions.requestEncoder,
                    responseDecoder: response.requestOptions.responseDecoder,
                    listFormat: response.requestOptions.listFormat,
                    receiveDataWhenStatusError:
                        response.requestOptions.receiveDataWhenStatusError,
                    method: response.requestOptions.method,
                    persistentConnection:
                        response.requestOptions.persistentConnection,
                    preserveHeaderCase:
                        response.requestOptions.preserveHeaderCase,
                    responseType: response.requestOptions.responseType,
                  ),
                );
                return handler.resolve(res);
              }
            }
          }
        }
        return handler.next(error);
      },
    ),
  ]);

final pem = rootBundle.loadString('assets/private_key.pem');
Future<String> genToken() async {
  final time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final jwt = JWT({'iat': time, 'exp': time + 600, 'iss': clientId});
  final token =
      jwt.sign(RSAPrivateKey(await pem), algorithm: JWTAlgorithm.RS256);
  return token;
}

Future<String?>? promise;
Future<String?> getAccessToken() async {
  if (promise != null) return promise;
  final comp = Completer<String?>();
  promise = comp.future.whenComplete(() => promise = null);
  try {
    final token = await genToken();
    var res = await dio.get<Map<String, dynamic>>(
      '/repos/$owner/$repo/installation',
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        extra: {'isRefreshToken': true},
      ),
    );
    if (res.data?['access_tokens_url'] is! String) return null;
    res = await dio.post<Map<String, dynamic>>(
      res.data?['access_tokens_url'] as String,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
        extra: {'isRefreshToken': true},
      ),
    );
    comp.complete(res.data?['token'] as String?);
  } catch (e) {
    comp.complete(null);
  }
  return promise;
}

String encode(String text) => text
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll('\r', '\\r')
    .replaceAll('\n', '\\n');

Future<Response<Map<String, dynamic>>> graphql(String data) async =>
    dio.post('/graphql', data: jsonEncode({'query': data}));

Future<Nodes<Article>> getDiscussions(String? after) async {
  if ((await graphql(
              '{ repository(owner: "$owner", name: "$repo") { discussions(first: 10, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { number author { avatarUrl(size: 50) login } createdAt lastEditedAt bodyHTML id bodyText title comments { totalCount } } } } } }'))
          .data
      case {
        'data': {
          'repository': {
            'discussions': {
              'nodes': final List<dynamic> nodes,
              'pageInfo': {
                'hasNextPage': final bool hasNextPage,
                'endCursor': final String endCursor
              },
            },
          },
        }
      }) {
    return (
      res: nodes
          .map((e) {
            if (e
                case {
                  'author': {
                    'avatarUrl': final String avatar,
                    'login': final String name,
                  },
                  'id': final String id,
                  'bodyHTML': final String bodyHTML,
                  'bodyText': final String bodyText,
                  'title': final String title,
                  'number': final int number,
                  'createdAt': final String createdAt,
                  'lastEditedAt': final String? lastEditedAt,
                  'comments': {
                    'totalCount': final int commentsCount,
                  },
                }) {
              final (:html, :cover) = parseHtml(bodyHTML);
              return Article(
                title: title,
                bodyHTML: html,
                bodyText: bodyText,
                author: Author(avatar: avatar, name: name),
                cover: cover,
                number: number,
                id: id,
                createdAt: DateTime.parse(createdAt),
                lastEditedAt: lastEditedAt == null
                    ? null
                    : DateTime.tryParse(lastEditedAt),
                commentsCount: commentsCount,
              );
            }
          })
          .whereType<Article>()
          .toList(),
      hasNextPage: hasNextPage,
      endCursor: endCursor
    );
  }
  return (res: <Article>[], hasNextPage: false, endCursor: null);
}

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

Future<Response<Map<String, dynamic>>> getDiscussionId(int number) => graphql(
    '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { id } } }');

Future<Response<Map<String, dynamic>>> getDiscussion(int number) => graphql(
    '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { number author { avatarUrl(size: 50) login } createdAt lastEditedAt bodyHTML id bodyText title comments { totalCount } } } }');

Future<
    Response<
        Map<String, dynamic>>> getPinnedDiscussions(String? after) => graphql(
    '{ repository(owner: "$owner", name: "$repo") { pinnedDiscussions(first: 10, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { discussion { number author { avatarUrl(size: 50) login } createdAt lastEditedAt bodyHTML id bodyText title comments { totalCount } } } } } } }');

Future<Nodes<Comment>> getComments(int number, String? after) async {
  if ((await graphql(
              '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 10, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { author { avatarUrl(size: 50) login } id bodyHTML createdAt lastEditedAt replies(first: 100) { nodes { author { avatarUrl(size: 50) login } bodyHTML createdAt lastEditedAt } } } } } } } }'))
          .data
      case {
        'data': {
          'repository': {
            'discussion': {
              'comments': {
                'nodes': final List<dynamic> nodes,
                'pageInfo': {
                  'hasNextPage': final bool hasNextPage,
                  'endCursor': final String endCursor
                },
              },
            },
          },
        },
      }) {
    return (
      res: nodes
          .map((e) {
            if (e
                case {
                  'author': {
                    'avatarUrl': final String avatar,
                    'login': final String name,
                  },
                  'bodyHTML': final String bodyHTML,
                  'createdAt': final String createdAt,
                  'lastEditedAt': final String? lastEditedAt,
                  'id': final String id,
                  'replies': {
                    'nodes': final List<dynamic> replies,
                  },
                }) {
              final (:html, cover: _) = parseHtml(bodyHTML, true);
              return Comment(
                author: Author(avatar: avatar, name: name),
                bodyHTML: html,
                createdAt: DateTime.parse(createdAt),
                lastEditedAt: lastEditedAt == null
                    ? null
                    : DateTime.tryParse(lastEditedAt),
                id: id,
                replies: replies
                    .map((e) {
                      if (e
                          case {
                            'author': {
                              'avatarUrl': final String avatar,
                              'login': final String name,
                            },
                            'bodyHTML': final String bodyHTML,
                            'createdAt': final String createdAt,
                            'lastEditedAt': final String? lastEditedAt,
                          }) {
                        final (:html, cover: _) = parseHtml(bodyHTML, true);
                        return Reply(
                          author: Author(avatar: avatar, name: name),
                          bodyHTML: html,
                          createdAt: DateTime.parse(createdAt),
                          lastEditedAt: lastEditedAt == null
                              ? null
                              : DateTime.tryParse(lastEditedAt),
                        );
                      }
                    })
                    .whereType<Reply>()
                    .toList(),
              );
            }
          })
          .whereType<Comment>()
          .toList(),
      hasNextPage: hasNextPage,
      endCursor: endCursor,
    );
  }
  return (res: <Comment>[], hasNextPage: false, endCursor: null);
}

Future<Author?> getUserInfo() async {
  if ((await graphql(
              '{ viewer { avatarUrl(size: 50) login repositories { totalCount } } }'))
          .data
      case {
        'data': {
          'viewer': {
            'login': final String name,
            'avatarUrl': final String avatar,
            'repositories': {
              'totalCount': final int level,
            },
          },
        }
      }) {
    return Author(
      name: name,
      avatar: avatar,
      level: level,
    );
  }
  return null;
}

Future<int?> getRepositoriesCount(String login) async {
  if ((await graphql(
              '{ user(login: "${encode(login)}") { repositories { totalCount } } }'))
          .data
      case {
        'data': {
          'user': {
            'repositories': {
              'totalCount': final int totalCount,
            }
          }
        }
      }) {
    return totalCount;
  }
  return null;
}

Future<Response<Map<String, dynamic>>> addDiscussionComment(
        String discussionId, String body) =>
    graphql(
        'mutation { addDiscussionComment(input: { discussionId: "$discussionId", body: "${encode(body)}" }) { clientMutationId } }');

Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) => graphql(
    'mutation { deleteDiscussion(input: { id: "$id" }) { clientMutationId } }');

Future<List<dynamic>> getAllReports(int number) async {
  final res = <dynamic>[];
  String? after;
  while (true) {
    if ((await graphql(
                '{ repository(owner: "$owner", name: "$repo") { discussion(number: $number) { comments(first: 100, after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { author { login } bodyHTML } } } } }'))
            .data
        case {
          'data': {
            'repository': {
              'discussion': {
                'comments': {
                  'pageInfo': {
                    'hasNextPage': final bool hasNextPage,
                    'endCursor': final String endCursor
                  },
                  'nodes': final List<dynamic> nodes
                }
              }
            }
          }
        }) {
      res.addAll(nodes);
      if (hasNextPage == false) break;
      after = endCursor;
    }
  }
  return res;
}

Future<Nodes<Article>> search(String query, String? after) async {
  if ((await graphql(
              '{ search(first: 10, type: DISCUSSION, query: "repo:$owner/$repo ${encode(query)}", after: ${after == null ? null : '"$after"'}) { pageInfo { endCursor hasNextPage } nodes { ... on Discussion { number author { avatarUrl(size: 50) login } createdAt lastEditedAt bodyHTML id bodyText title comments { totalCount } } } } }'))
          .data
      case {
        'data': {
          'search': {
            'nodes': final List<dynamic> nodes,
            'pageInfo': {
              'hasNextPage': final bool hasNextPage,
              'endCursor': final String endCursor
            },
          },
        }
      }) {
    return (
      res: nodes
          .map((e) {
            if (e
                case {
                  'author': {
                    'avatarUrl': final String avatar,
                    'login': final String name,
                  },
                  'id': final String id,
                  'bodyHTML': final String bodyHTML,
                  'bodyText': final String bodyText,
                  'title': final String title,
                  'number': final int number,
                  'createdAt': final String createdAt,
                  'lastEditedAt': final String? lastEditedAt,
                  'comments': {
                    'totalCount': final int commentsCount,
                  },
                }) {
              final (:html, :cover) = parseHtml(bodyHTML);
              return Article(
                title: title,
                bodyHTML: html,
                bodyText: bodyText,
                author: Author(avatar: avatar, name: name),
                cover: cover,
                number: number,
                id: id,
                createdAt: DateTime.parse(createdAt),
                lastEditedAt: lastEditedAt == null
                    ? null
                    : DateTime.tryParse(lastEditedAt),
                commentsCount: commentsCount,
              );
            }
          })
          .whereType<Article>()
          .toList(),
      hasNextPage: hasNextPage,
      endCursor: endCursor
    );
  }
  return (res: <Article>[], hasNextPage: false, endCursor: null);
}
