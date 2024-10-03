import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/feedback_btn.dart';
import 'package:inter_knot/components/updata.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/models/release.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Controller extends GetxController {
  late final SharedPreferencesWithCache pref;

  final searchQuery = ''.obs;
  final searchResult = <HData>{}.obs;
  String? searchEndCur;
  final searchHasNextPage = true.obs;

  String rootToken = '';

  String getToken() => pref.getString('access_token') ?? '';
  Future<void> setToken(String v) => pref.setString('access_token', v);
  String getRefreshToken() => pref.getString('refresh_token') ?? '';
  Future<void> setRefreshToken(String v) => pref.setString('refresh_token', v);

  final isLogin = false.obs;
  final user = Rx<Author?>(null);

  final report = <int, Set<ReportComment>>{}.obs;

  final bookmarks = <HData>{}.obs;
  final history = <HData>{}.obs;

  late final info = PackageInfo.fromPlatform();

  bool canVisit(Discussion discussion, bool isPin) =>
      report[discussion.number] == null ||
      [owner, ...collaborators].contains(discussion.author.login) ||
      isPin ||
      report[discussion.number]!.length < 6;

  final curPage = 0.obs;

  final accelerator = ''.obs;

  @override
  Future<void> onInit() async {
    super.onInit();
    pref = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    pageController
        .addListener(() => curPage(pageController.page?.round() ?? 0));
    c.pref.remove('root_token');
    isLogin(pref.getBool('isLogin') ?? false);
    ever(isLogin, (v) => pref.setBool('isLogin', v));
    logger.i(isLogin());
    accelerator(pref.getString('accelerator') ?? '');
    ever(accelerator, (v) => pref.setString('accelerator', v));
    if (isLogin()) api_user.getSelfUserInfo().then(user.call);
    debounce(
      searchQuery,
      (query) {
        searchController.text = query;
        searchResult.clear();
        searchEndCur = null;
        searchHasNextPage.value = true;
        searchCache.clear();
        searchData();
      },
      time: 500.ms,
    );
    searchData();
    bookmarks.addAll(pref.getStringList('bookmarks')?.map(HData.fromStr) ?? []);
    history.addAll(pref.getStringList('history')?.map(HData.fromStr) ?? []);
    ever(bookmarks, (v) {
      pref.setStringList(
        'bookmarks',
        v.map((e) => '${e.number},${e.updatedAt}').toList(),
      );
    });
    ever(history, (v) {
      pref.setStringList(
        'history',
        v.map((e) => '${e.number},${e.updatedAt}').toList(),
      );
    });
    if (c.isLogin()) {
      api_user.getAllReports(reportDiscussionNumber).then(report.call);
      api_user.getNewVersion().then(getVersionHandle);
    } else {
      api_root.getAllReports(reportDiscussionNumber).then(report.call);
      api_root.getNewVersion().then(getVersionHandle);
    }
  }

  FutureOr<void> getVersionHandle(ReleaseModel? release) async {
    if (release == null) {
      showDialog(
        context: Get.context!,
        builder: (context) {
          return AlertDialog(
            title: Text('Error: Unable to detect the latest version'.tr),
            content: SelectableText(
              'Unable to detect the latest version, please go to @releasesLink to update manually.'
                  .trParams({'releasesLink': releasesLink}),
            ),
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
            builder: (context) => Updata(
              newFullVer: newFullVer,
              curFullVer: curFullVer,
              descriptionHTML: descriptionHTML,
              mustUpdate: mustUpdate(newVersion, curVersion),
              release: release,
            ),
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

  bool isFetchPinDiscussions = true;
  final searchController = SearchController();

  late final refreshSearchData = throttle(() async {
    searchHasNextPage.value = true;
    searchEndCur = null;
    searchCache.clear();
    searchResult.clear();
    await searchData();
  });

  final searchCache = <String?>{};
  Future<void> searchData() async {
    if (searchHasNextPage.isFalse || searchCache.contains(searchEndCur)) return;
    searchCache.add(searchEndCur);
    final (:endCursor, :hasNextPage, :res) = isLogin()
        ? await api_user.search(searchQuery(), searchEndCur)
        : await api_root.search(searchQuery(), searchEndCur);
    searchEndCur = endCursor;
    searchHasNextPage.value = hasNextPage;
    searchResult.addAll(res);
  }
}

bool canReport(Discussion discussion, bool isPin) =>
    ![owner, ...collaborators].contains(discussion.author.login) && !isPin;
