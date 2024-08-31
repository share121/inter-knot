import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../common.dart';
import '../widget/discussion_card.dart';
import 'article_page.dart';

class LikedPage extends StatefulWidget {
  const LikedPage({super.key});

  @override
  State<LikedPage> createState() => _LikedPageState();
}

class _LikedPageState extends State<LikedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Like'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() {
          if (c.bookmarks.isEmpty) return Center(child: Text('Empty'.tr));
          return WaterfallFlow.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate:
                const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 270,
            ),
            itemCount: c.bookmarks.length,
            itemBuilder: (context, index) {
              return Obx(() {
                return DiscussionCard(
                  article: c.bookmarks.elementAt(index),
                  onTap: (heroKey) {
                    Get.to<void>(() => ArticlePage(
                          heroKey: heroKey,
                          article: c.bookmarks.elementAt(index),
                        ));
                  },
                );
              });
            },
          );
        }),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
