import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:inter_knot/constants/graphql_query.dart' as graphql_query;
import 'package:inter_knot/helpers/box.dart';
import 'package:inter_knot/helpers/transform_reports.dart';
import 'package:inter_knot/models/author.dart';
import 'package:inter_knot/models/comment.dart';
import 'package:inter_knot/models/device_login.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/models/pagination.dart';
import 'package:inter_knot/models/release.dart';
import 'package:inter_knot/pages/login_page.dart';
import 'package:inter_knot/secret.dart';

class LoginApi extends GetConnect {
  Future<
      ({
        DeviceLoginStatus status,
        String? accessToken,
        String? refreshToken
      })> getAccessToken(DeviceLoginModel deviceLogin) async {
    final res = await post<Map<String, dynamic>>(
      'https://github.com/login/oauth/access_token',
      null,
      query: {
        'client_id': clientId,
        'device_code': deviceLogin.deviceCode,
        'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      },
    );
    if (res.body == null) throw Exception('Failed to get access token');
    if (res.body!['error'] == 'authorization_pending') {
      return (
        status: DeviceLoginStatus.authorizationPending,
        accessToken: null,
        refreshToken: null,
      );
    }
    if (res.body!['error'] == 'expired_token') {
      return (
        status: DeviceLoginStatus.expiredToken,
        accessToken: null,
        refreshToken: null,
      );
    }
    if (res.body!['error'] == 'access_denied') {
      return (
        status: DeviceLoginStatus.accessDenied,
        accessToken: null,
        refreshToken: null,
      );
    }
    if (res.body
        case {
          'access_token': final String accessToken,
          'refresh_token': final String refreshToken
        }) {
      return (
        status: DeviceLoginStatus.finished,
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
    }
    throw Exception('Invalid response: $res');
  }

  Future<bool>? promise;
  Future<bool> refreshToken() async {
    if (promise != null) return promise!;
    final comp = Completer<bool>();
    promise = comp.future.whenComplete(() => promise = null);
    try {
      final refreshToken = box.read<String>('refresh_token') ?? '';
      if (!refreshToken.startsWith('ghr_')) {
        comp.complete(false);
        return promise!;
      }
      final r = await post<Map<String, dynamic>>(
        'https://github.com/login/oauth/access_token',
        null,
        query: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type	': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );
      if (r.body
          case {
            'access_token': final String accessToken,
            'refresh_token': final String refreshToken
          }
          when accessToken.startsWith('ghu_') &&
              refreshToken.startsWith('ghr_')) {
        await box.write('access_token', accessToken);
        await box.write('refresh_token', refreshToken);
        comp.complete(true);
      } else {
        comp.complete(false);
      }
    } catch (_) {
      comp.complete(false);
    }
    return promise!;
  }

  Future<DeviceLoginModel> getDeviceLogin() async {
    final res = await post<Map<String, dynamic>>(
      'https://github.com/login/device/code',
      null,
      query: {'client_id': clientId},
    );
    return DeviceLoginModel.fromJson(res.body!);
  }
}

class BaseConnect extends GetConnect {
  static final loginApi = Get.find<LoginApi>();

  @override
  void onInit() {
    httpClient.baseUrl = 'https://api.github.com';
    httpClient.addAuthenticator<DiscussionModel?>((request) async {
      var token = box.read<String>('access_token') ?? '';
      while (!token.startsWith('ghu_')) {
        if (!await loginApi.refreshToken()) {
          await Future(() => Get.to(() => const LoginPage()));
        }
        token = box.read<String>('access_token') ?? '';
      }
      request.headers['Authorization'] = 'Bearer $token';
      return request;
    });
    httpClient.addResponseModifier((req, rep) {
      if (rep.statusCode == HttpStatus.unauthorized) {
        box.remove('access_token');
      }
    });
    httpClient.maxAuthRetries = 3;
  }

  Future<Response<Map<String, dynamic>>> graphql(String data) =>
      post('/graphql', jsonEncode({'query': data}));
}

class Api extends BaseConnect {
  Future<DiscussionModel> getDiscussion(int number) async {
    final res = await graphql(graphql_query.getDiscussion(number));
    return DiscussionModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['repository']['discussion'] as Map<String, dynamic>,
    );
  }

  Future<PaginationModel<HDataModel>> search(
      String query, String endCur) async {
    final res = await graphql(graphql_query.search(query, endCur));
    return PaginationModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['search'] as Map<String, dynamic>,
      HDataModel.fromJson,
    );
  }

  Future<PaginationModel<CommentModel>> getComments(
      int number, String endCur) async {
    final res = await graphql(graphql_query.getComments(number, endCur));
    return PaginationModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['repository']['discussion']['comments']
          as Map<String, dynamic>,
      CommentModel.fromJson,
    );
  }

  Future<Response<Map<String, dynamic>>> addDiscussionComment(
    String discussionId,
    String body,
  ) =>
      graphql(graphql_query.addDiscussionComment(discussionId, body));

  Future<Response<Map<String, dynamic>>> deleteDiscussion(String id) =>
      graphql(graphql_query.deleteDiscussion(id));

  Future<PaginationModel<HDataModel>> getPinnedDiscussions(
      String? endCur) async {
    final res = await graphql(graphql_query.getPinnedDiscussions(endCur));
    return PaginationModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['repository']['pinnedDiscussions']
          as Map<String, dynamic>,
      HDataModel.fromPinnedJson,
    );
  }

  Future<AuthorModel> getSelfUserInfo(String login) async {
    final res = await graphql(graphql_query.getSelfUserInfo());
    // ignore: avoid_dynamic_calls
    return AuthorModel.fromJson(
        res.body!['data']['viewer'] as Map<String, dynamic>);
  }

  Future<AuthorModel> getUserInfo(String login) async {
    final res = await graphql(graphql_query.getUserInfo(login));
    // ignore: avoid_dynamic_calls
    return AuthorModel.fromJson(
        res.body!['data']['user'] as Map<String, dynamic>);
  }

  Future<ReleaseModel> getNewVersion(String login) async {
    final res = await graphql(graphql_query.getNewVersion());
    return ReleaseModel.fromJson(
      // ignore: avoid_dynamic_calls
      res.body!['data']['repository']['releases']['nodes'][0]
          as Map<String, dynamic>,
    );
  }

  Future<Report> getAllReports(int number) async {
    final res = <({String login, Set<int> numbers, String bodyHTML})>[];
    String? after;
    while (true) {
      final data = await graphql(graphql_query.getAllReports(number, after));
      if (data.body
          case {
            'data': {
              'repository': {
                'discussion': {
                  'comments': {
                    'pageInfo': {
                      'hasNextPage': final bool hasNextPage,
                      'endCursor': final String? endCursor
                    },
                    'nodes': final List nodes
                  }
                }
              }
            }
          }) {
        res.addAll(
          nodes
              .map((e) {
                if (e
                    case {
                      'author': {
                        'login': final String login,
                      },
                      'body': final String body,
                      'bodyHTML': final String bodyHTML,
                    }) {
                  return (login: login, bodyHTML: bodyHTML, body: body);
                }
                return null;
              })
              .whereType<({String login, String bodyHTML, String body})>()
              .map((e) {
                if (!e.body.contains('原因')) return null;
                final numbers = RegExp(r'#(\d+)')
                    .allMatches(e.body)
                    .map((e) => e.group(1))
                    .whereType<String>()
                    .map((e) => int.parse(e))
                    .toSet();
                if (numbers.isEmpty) return null;
                return (
                  login: e.login,
                  bodyHTML: e.bodyHTML,
                  numbers: numbers,
                );
              })
              .whereType<({String login, Set<int> numbers, String bodyHTML})>(),
        );
        if (!hasNextPage) break;
        after = endCursor;
      }
    }
    return transformReports(res);
  }
}
