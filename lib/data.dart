import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

final isDesktop = !kIsWeb && GetPlatform.isDesktop;

const owner = 'share121';
const repo = 'inter-knot';
const clientId = 'Iv23li8gf1MxGAgvw5lU';
const clientSecret = '3ea999c0e2d7283f602ab4994cc684ada2eeec2b';
const collaborators = ['VacuolePaoo'];

class Controller extends GetxController {
  late final SharedPreferencesWithCache pref;

  final searchQuery = ''.obs;
  final searchResult = <Article>[].obs;
  String? searchEndCur;
  final searchHasNextPage = true.obs;

  String getToken() => pref.getString('access_token') ?? '';
  Future<void> setToken(String v) => pref.setString('access_token', v);
  String getRefreshToken() => pref.getString('refresh_token') ?? '';
  Future<void> setRefreshToken(String v) => pref.setString('refresh_token', v);

  @override
  Future<void> onInit() async {
    super.onInit();
    ever(data, (_) {
      removeDuplicateArticle(data);
    });
    ever(searchResult, (_) {
      removeDuplicateArticle(searchResult);
    });
    debounce(searchQuery, (query) {
      searchResult.clear();
      searchEndCur = null;
      searchHasNextPage.value = true;
      searchCache.clear();
      searchData();
    }, time: 500.ms);
    pref = await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(),
    );
    await fetchData();
    searchResult.addAll(data);
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

  final data = <Article>[].obs;
  String? endCur;
  final hasNextPage = true.obs;

  final cache = <String?>[];
  Future<void> fetchData() async {
    if (this.hasNextPage.isFalse || cache.contains(endCur)) return;
    cache.add(endCur);
    final (:endCursor, :hasNextPage, :res) = await getDiscussions(endCur);
    endCur = endCursor;
    this.hasNextPage.value = hasNextPage;
    data.addAll(res);
  }

  final searchCache = <String?>[];
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
        await search(searchQuery(), searchEndCur);
    searchEndCur = endCursor;
    searchHasNextPage.value = hasNextPage;
    searchResult.addAll(res);
  }
}

class Article extends GetxController {
  final String title;
  final String bodyHTML;
  final String bodyText;
  final Author author;
  final String? cover;
  final int number;
  final String url;
  final String id;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final int commentsCount;
  final comments = <Comment>[].obs;
  var hasNextPage = true.obs;
  String? endCursor;

  final cache = <String?>[];
  Future<void> fetchComments() async {
    if (hasNextPage() == false || cache.contains(endCursor)) {
      return;
    }
    final (:res, hasNextPage: newHasNextPage, endCursor: newEndCursor) =
        await getComments(number, endCursor);
    comments.addAll(res);
    removeDuplicateComment(comments);
    hasNextPage.value = newHasNextPage;
    endCursor = newEndCursor;
  }

  Article({
    required this.title,
    required this.bodyHTML,
    required this.bodyText,
    required this.author,
    this.cover,
    required this.number,
    required this.id,
    required this.createdAt,
    required this.commentsCount,
    this.lastEditedAt,
  }) : url = 'https://github.com/share121/inter-knot/discussions/$number';
}

class Comment extends GetxController {
  final Author author;
  final String bodyHTML;
  final DateTime createdAt;
  final DateTime? lastEditedAt;
  final replies = <Reply>[].obs;
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
}

extension Use<V> on V? {
  T? use<T>(T Function(V value) fn) => this == null ? null : fn(this as V);
}

extension True on bool {
  T? isTrue<T>(T Function() fn) => this == true ? fn() : null;
  T? isFalse<T>(T Function() fn) => this == false ? fn() : null;
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
  final String name;
  final String avatar;
  final String url;
  final level = 0.obs;

  Author({required this.name, required this.avatar, int? level})
      : url = 'https://github.com/$name' {
    if (level == null) {
      getRepositoriesCount(name).then((v) {
        if (v == null) return;
        this.level.value = v;
      });
    } else {
      this.level.value = level;
    }
  }
}

void removeDuplicateArticle(List<Article> arr) {
  var len = arr.length;
  for (var i = 0; i < len; i++) {
    for (var j = i + 1; j < len; j++) {
      if (arr[i].number == arr[j].number) {
        arr.removeAt(j);
        len--;
        j--;
      }
    }
  }
}

void removeDuplicateComment(List<Comment> arr) {
  var len = arr.length;
  for (var i = 0; i < len; i++) {
    for (var j = i + 1; j < len; j++) {
      if (arr[i].id == arr[j].id) {
        arr.removeAt(j);
        len--;
        j--;
      }
    }
  }
}
