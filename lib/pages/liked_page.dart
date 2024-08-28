import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/data.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../widget/discussion_card.dart';
import 'article_page.dart';

class LikedPage extends StatelessWidget {
  const LikedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Like'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() {
          if (c.bookmarks.isEmpty) return Center(child: Text('Empty'.tr));
          return WaterfallFlow.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
                const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 270,
            ),
            itemCount: c.bookmarks.length,
            itemBuilder: (context, index) {
              return Obx(() {
                return DiscussionCard(
                  article: c.bookmarks[index],
                  onTap: (heroKey) {
                    Get.to<void>(() => ArticlePage(
                        heroKey: heroKey, article: c.bookmarks[index]));
                  },
                );
              });
            },
          );
        }),
      ),
    );
  }
}
