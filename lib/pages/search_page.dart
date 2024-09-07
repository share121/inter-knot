import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';

import '../widget/article_grid.dart';
import '../common.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  late StreamSubscription<bool> keyboardSubscription;

  @override
  void initState() {
    super.initState();
    final keyboardVisibilityController = KeyboardVisibilityController();
    keyboardSubscription =
        keyboardVisibilityController.onChange.listen((visible) {
      if (!visible) FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  final fetchData = retryThrottle(c.searchData, 3.s);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Search'.tr))],
        floatHeaderSlivers: true,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBar(
                controller: c.searchController,
                onSubmitted: c.searchQuery.call,
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.search),
                ),
                hintText: 'Search for articles'.tr,
              ),
            ),
            Expanded(
              child: Obx(() {
                return ArticleGrid(
                  list: c.searchResult(),
                  hasNextPage: c.searchHasNextPage(),
                  fetchData: fetchData,
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => c.refreshSearchData(),
        tooltip: 'Refresh'.tr,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
