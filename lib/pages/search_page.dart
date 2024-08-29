import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import 'article_page.dart';
import '../widget/discussion_card.dart';
import '../data.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Search'.tr))],
        floatHeaderSlivers: true,
        body: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SearchBar(
                controller: c.searchController,
                onSubmitted: c.searchQuery.call,
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.search),
                ),
                hintText: 'Search for articles'.tr,
                autoFocus: true,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                if (c.searchResult.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                return WaterfallFlow.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 270,
                    lastChildLayoutTypeBuilder: (index) =>
                        index == c.searchResult.length
                            ? LastChildLayoutType.foot
                            : LastChildLayoutType.none,
                    viewportBuilder: (firstIndex, lastIndex) {
                      if (lastIndex == c.searchResult.length) c.searchData();
                    },
                  ),
                  itemCount: c.searchResult.length + 1,
                  itemBuilder: (context, index) {
                    return Obx(() {
                      if (index == c.searchResult.length) {
                        if (c.searchHasNextPage.isFalse) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text('No more data'.tr),
                            ),
                          );
                        }
                        return const SizedBox(
                          width: 60,
                          height: 60,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return DiscussionCard(
                        article: c.searchResult.elementAt(index),
                        onTap: (heroKey) {
                          Get.to<void>(() => ArticlePage(
                                heroKey: heroKey,
                                article: c.searchResult.elementAt(index),
                              ));
                        },
                      );
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => c.refreshSearchData(),
        tooltip: 'Refresh'.tr,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
