import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'pages/login_page.dart';
import 'widget/feedback_btn.dart';
import 'api_user/api_user.dart' as api_user;

final logger = Logger();

final isDesktop = !kIsWeb && GetPlatform.isDesktop;

const reportDiscussionNumber = 1685;
const owner = 'share121';
const repo = 'inter-knot';
const clientId = 'Iv23li8gf1MxGAgvw5lU';
const clientSecret = '3ea999c0e2d7283f602ab4994cc684ada2eeec2b';
const collaborators = ['VacuolePaoo'];
const githubLink = 'https://github.com/$owner/$repo';
const discordLink = 'https://disboard.org/zh-cn/server/1273078781241987134';
const docLink = 'https://docs.xn--5o0anh.top/';
const issuesLink = '$githubLink/issues';
const releasesLink = '$githubLink/releases';

Future<bool> copyText(String text, {String? msg, String? title}) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    Get.rawSnackbar(title: title, message: msg ?? 'Copied'.tr);
    return true;
  } catch (e, s) {
    logger.e('Copy failed', stackTrace: s, error: e);
    Get.rawSnackbar(message: 'Copy failed'.tr);
    return false;
  }
}

class Controller extends GetxController {
  late final SharedPreferencesWithCache pref;

  final searchQuery = ''.obs;
  final searchResult = <Article>{}.obs;
  String? searchEndCur;
  final searchHasNextPage = true.obs;

  String getRootToken() => pref.getString('root_token') ?? '';
  Future<void> setRootToken(String v) => pref.setString('root_token', v);

  String getToken() => pref.getString('access_token') ?? '';
  Future<void> setToken(String v) => pref.setString('access_token', v);
  String getRefreshToken() => pref.getString('refresh_token') ?? '';
  Future<void> setRefreshToken(String v) => pref.setString('refresh_token', v);

  Future<Set<Article>> getBookmarks() async {
    final discussionNumber = pref.getStringList('bookmarks') ?? [];
    final futures = discussionNumber
        .map((e) => api_user.getDiscussion(int.parse(e)))
        .toList();
    return (await Future.wait(futures)).whereType<Article>().toSet();
  }

  final isLogin = false.obs;

  final user = Rx<Author?>(null);

  final report = <int, Set<api_user.ReportComment>>{}.obs;

  final bookmarks = <Article>{}.obs;

  Future<Set<Article>> getHistory() async {
    final discussionNumber = pref.getStringList('history') ?? [];
    final futures = discussionNumber
        .map((e) => api_user.getDiscussion(int.parse(e)))
        .toList();
    return (await Future.wait(futures)).whereType<Article>().toSet();
  }

  final history = <Article>{}.obs;

  late final info = PackageInfo.fromPlatform();

  bool canVisit(Article article) =>
      report[article.number] == null ||
      [owner, ...collaborators].contains(article.author.login) ||
      article.isPin ||
      report[article.number]!.length < 6;

  @override
  Future<void> onInit() async {
    super.onInit();
    pref = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    ever(isLogin, (v) async {
      if (v) {
        if (!getToken().startsWith('ghu_')) {
          await Get.to(() => const LoginPage());
        }
      }
    });
    if (isLogin()) {
      // getUserInfo(login);
    }
    debounce(searchQuery, (query) {
      searchController.text = query;
      searchResult.clear();
      searchEndCur = null;
      searchHasNextPage.value = true;
      searchCache.clear();
      searchData();
    }, time: 500.ms);
    fetchData().then((_) => searchResult.addAll(data));
    getBookmarks().then(bookmarks.call);
    getHistory().then(history.call);
    ever(bookmarks, (v) {
      pref.setStringList(
          'bookmarks', v.map((e) => e.number.toString()).toList());
    });
    ever(history, (v) {
      if (v.length > 20) {
        history(history.take(20).toSet());
      } else {
        pref.setStringList(
            'history', v.map((e) => e.number.toString()).toList());
      }
    });
    api_user.getAllReports(reportDiscussionNumber).then(report.call);
    api_user.getNewVersion().then((release) async {
      if (release == null) {
        showDialog(
          context: Get.context!,
          builder: (context) {
            return AlertDialog(
              title: Text('Error: Unable to detect the latest version'.tr),
              content: SelectableText(
                  'Unable to detect the latest version, please go to @releasesLink to update manually.'
                      .trParams({'releasesLink': releasesLink})),
              actions: [
                FeedbackBtn('Error: Unable to detect the latest version'.tr),
                TextButton(
                  onPressed: () => launchUrlString(releasesLink),
                  child: Text('Open'.tr),
                ),
                TextButton(
                  onPressed: () => Get.back(),
                  child: Text('OK'.tr),
                ),
              ],
            );
          },
        );
      } else {
        try {
          final info = await PackageInfo.fromPlatform();
          final newVersion = Version.parse(release.version);
          final curVersion =
              Version.parse('${info.version}+${info.buildNumber}');
          if (newVersion > curVersion) {
            final newFullVer = 'v${release.version}';
            final curFullVer = 'v${info.version}+${info.buildNumber}';
            final descriptionHTML = release.descriptionHTML ?? '';
            showDialog(
              context: Get.context!,
              builder: (context) {
                return AlertDialog(
                  title: Text('New version available'.tr),
                  scrollable: true,
                  content: Column(
                    children: [
                      ListTile(
                        onTap: () => copyText(curFullVer),
                        title: Text('Current version'.tr),
                        subtitle: Text(curFullVer),
                      ),
                      ListTile(
                        onTap: () => copyText(newFullVer),
                        title: Text('Latest version'.tr),
                        subtitle: Text(newFullVer),
                      ),
                      ListTile(
                        onTap: () {},
                        title: Text('Update content'.tr),
                        subtitle: descriptionHTML.trim().isEmpty
                            ? Text('Empty'.tr)
                            : HtmlWidget(descriptionHTML),
                      ),
                      const Divider(),
                      for (final item in release.releaseAssets)
                        ListTile(
                          title: Text(item.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Last edited on: '.tr +
                                  item.updatedAt.toLocal().toString()),
                              Text('Size: @size bytes'
                                  .trParams({'size': item.size.toString()})),
                              Text('Download count: '.tr +
                                  item.downloadCount.toString()),
                            ],
                          ),
                          onTap: () async {
                            launchUrlString(item.downloadUrl);
                          },
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: Text('OK'.tr),
                    ),
                  ],
                );
              },
            );
          }
        } catch (e, s) {
          logger.e(e, stackTrace: s);
        }
      }
    });
  }

  final selectedIndex = 0.obs;
  final pageController = PageController();

  Future<void> animateToPage(int index) {
    selectedIndex.value = index;
    return pageController.animateToPage(
      index,
      duration: 0.5.s,
      curve: Curves.ease,
    );
  }

  final data = <Article>{}.obs;
  String? endCur;
  final hasNextPage = true.obs;
  var isFetchPinDiscussions = true;
  final searchController = SearchController();

  final cache = <String?>{};
  Future<void> fetchData() async {
    if (this.hasNextPage.isFalse || cache.contains(endCur)) return;
    cache.add(endCur);
    late final api_user.Nodes<Article> res;
    if (isFetchPinDiscussions) {
      res = await api_user.getPinnedDiscussions(endCur);
    } else {
      res = await api_user.getDiscussions(endCur);
    }
    final (:endCursor, :hasNextPage, res: articles) = res;
    endCur = endCursor;
    if (isFetchPinDiscussions && !hasNextPage) {
      isFetchPinDiscussions = false;
      endCur = null;
      cache.clear();
    } else {
      this.hasNextPage.value = hasNextPage;
    }
    data.addAll(res.res);
  }

  Future<void> refreshData() async {
    api_user.getAllReports(reportDiscussionNumber).then(report.call);
    isFetchPinDiscussions = true;
    hasNextPage.value = true;
    endCur = null;
    cache.clear();
    data.clear();
    await fetchData();
  }

  Future<void> refreshSearchData() async {
    api_user.getAllReports(reportDiscussionNumber).then(report.call);
    searchHasNextPage.value = true;
    searchEndCur = null;
    searchCache.clear();
    searchResult.clear();
    await searchData();
  }

  final searchCache = <String?>{};
  Future<void> searchData() async {
    if (searchQuery.isEmpty) {
      await fetchData();
      searchResult.clear();
      searchResult.addAll(data);
      return;
    }
    if (searchHasNextPage.isFalse || searchCache.contains(searchEndCur)) return;
    searchCache.add(searchEndCur);
    final (:endCursor, :hasNextPage, :res) =
        await api_user.search(searchQuery(), searchEndCur);
    searchEndCur = endCursor;
    searchHasNextPage.value = hasNextPage;
    searchResult.addAll(res);
  }
}

class Article extends GetxController {
  final String title;
  final String bodyHTML;
  final String rawBodyText;
  final Author author;
  final String? cover;
  final int number;
  late final url = 'https://github.com/$owner/$repo/discussions/$number';
  final String id;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final int commentsCount;
  final comments = <Comment>{}.obs;
  var hasNextPage = true.obs;
  String? endCursor;
  final bool isPin;
  final String partition;
  late final bodyText = rawBodyText
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceFirst(RegExp(r'^分区.+?封面.+?内容'), '')
      .replaceAll('No response', '')
      .trim();

  final cache = <String?>{};
  Future<void> fetchComments() async {
    if (hasNextPage.isFalse || cache.contains(endCursor)) {
      return;
    }
    final (:res, hasNextPage: newHasNextPage, endCursor: newEndCursor) =
        await api_user.getComments(number, endCursor);
    comments.addAll(res);
    hasNextPage.value = newHasNextPage;
    endCursor = newEndCursor;
  }

  Article({
    required this.title,
    required this.bodyHTML,
    required this.rawBodyText,
    required this.author,
    this.cover,
    required this.number,
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    this.lastEditedAt,
    required this.isPin,
    required this.partition,
  });

  @override
  operator ==(Object other) => other is Article && other.number == number;

  @override
  int get hashCode => number;
}

class Comment extends GetxController {
  final Author author;
  final String bodyHTML;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final replies = <Reply>{}.obs;
  final String id;

  Comment({
    required this.author,
    required this.bodyHTML,
    required this.createdAt,
    this.lastEditedAt,
    required Iterable<Reply> replies,
    required this.id,
  }) {
    this.replies.addAll(replies);
  }

  @override
  operator ==(Object other) => other is Comment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class Reply {
  final Author author;
  final String bodyHTML;
  final DateTime createdAt;
  final DateTime? lastEditedAt;

  Reply({
    required this.author,
    required this.bodyHTML,
    required this.createdAt,
    this.lastEditedAt,
  });

  @override
  operator ==(Object other) =>
      other is Reply &&
      other.author == author &&
      other.bodyHTML == bodyHTML &&
      other.createdAt == createdAt &&
      other.lastEditedAt == lastEditedAt;

  @override
  int get hashCode => Object.hash(author, bodyHTML, createdAt, lastEditedAt);
}

bool canReport(Article article) =>
    ![owner, ...collaborators].contains(article.author.login) && !article.isPin;

extension Use<V> on V? {
  T? use<T>(T Function(V value) fn) => this == null ? null : fn(this as V);
}

extension True on bool {
  T? isTrue<T>(T Function() fn) => this ? fn() : null;
  T? isFalse<T>(T Function() fn) => !this ? fn() : null;
}

extension Num2Duration on num {
  Duration get microseconds => Duration(microseconds: toInt());
  Duration get ms => (this * 1000).microseconds;
  Duration get s => (this * 1000).ms;
  Duration get min => (this * 60).s;
  Duration get hour => (this * 60).min;
  Duration get day => (this * 24).hour;
  Duration get week => (this * 7).day;
}

extension DurationFomater on Duration {
  /// MM:SS
  String get format =>
      '${inMinutes.toString().padLeft(2, '0')}:${inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

class Author {
  final String login;
  late final name = login.obs;
  final String avatar;
  late final url = 'https://github.com/$login';
  final level = 0.obs;

  Author({required this.login, required this.avatar, int? level}) {
    if (level == null) {
      api_user.getUserInfo(login).then((v) {
        if (v.totalCount != null) this.level.value = v.totalCount!;
        if (v.name != null) name.value = v.name!;
      });
    } else {
      this.level.value = level;
    }
  }

  @override
  operator ==(Object other) => other is Author && other.login == login;

  @override
  int get hashCode => login.hashCode;
}
