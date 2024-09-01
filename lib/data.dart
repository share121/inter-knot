import 'dart:async';
import 'package:flutter/material.dart';

import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'common.dart';
import 'interface.dart';
import 'widget/feedback_btn.dart';
import 'api/api_root.dart' as api_root;

const reportDiscussionNumber = 1685;
const owner = 'share121';
const repo = 'inter-knot';
const clientId = 'Iv23li8gf1MxGAgvw5lU';
const clientSecret = '3ea999c0e2d7283f602ab4994cc684ada2eeec2b';
const collaborators = ['VacuolePaoo'];
const githubLink = 'https://github.com/$owner/$repo';
const discordLink = 'https://disboard.org/zh-cn/server/1273078781241987134';
const docLink = 'https://d.inot.top/';
const issuesLink = '$githubLink/issues';
const releasesLink = '$githubLink/releases';

class HData {
  final int number;
  late final article = api_root.getDiscussion(number);

  HData(this.number);
  HData.fromStr(String number) : this(int.parse(number));
  HData.fromArtilce(Article article) : this(article.number);

  @override
  operator ==(Object other) {
    return other is HData && other.number == number;
  }

  @override
  int get hashCode => number;
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

  final report = <int, Set<ReportComment>>{}.obs;

  final bookmarks = <HData>{}.obs;
  final history = <HData>{}.obs;

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
    debounce(searchQuery, (query) {
      searchController.text = query;
      searchResult.clear();
      searchEndCur = null;
      searchHasNextPage.value = true;
      searchCache.clear();
      searchData();
    }, time: 500.ms);
    fetchData().then((_) => searchResult.addAll(data));
    bookmarks.addAll(pref.getStringList('bookmarks')?.map(HData.fromStr) ?? []);
    history.addAll(pref.getStringList('history')?.map(HData.fromStr) ?? []);
    ever(bookmarks, (v) {
      pref.setStringList(
          'bookmarks', v.map((e) => e.number.toString()).toList());
    });
    ever(history, (v) {
      pref.setStringList('history', v.map((e) => e.number.toString()).toList());
    });
    api_root.getAllReports(reportDiscussionNumber).then(report.call);
    api_root.getNewVersion().then(getVersionHandle);
  }

  FutureOr<Null> getVersionHandle(Release? release) async {
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
        final curVersion = Version.parse('${info.version}+${info.buildNumber}');
        if (newVersion > curVersion) {
          final newFullVer = 'v${release.version}';
          final curFullVer = 'v${info.version}+${info.buildNumber}';
          final descriptionHTML = release.descriptionHTML ?? '';
          showDialog(
            context: Get.context!,
            barrierDismissible: !mustUpdate(newVersion, curVersion),
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
                  if (!mustUpdate(newVersion, curVersion))
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
  }

  bool mustUpdate(Version newVer, Version curVer) =>
      newVer.major > curVer.major || newVer.minor > curVer.minor;

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
    late final Nodes<Article> res;
    if (isFetchPinDiscussions) {
      res = await api_root.getPinnedDiscussions(endCur);
    } else {
      res = await api_root.getDiscussions(endCur);
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
    isFetchPinDiscussions = true;
    hasNextPage.value = true;
    endCur = null;
    cache.clear();
    data.clear();
    await fetchData();
  }

  Future<void> refreshSearchData() async {
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
        await api_root.search(searchQuery(), searchEndCur);
    searchEndCur = endCursor;
    searchHasNextPage.value = hasNextPage;
    searchResult.addAll(res);
  }
}

bool canReport(Article article) =>
    ![owner, ...collaborators].contains(article.author.login) && !article.isPin;
