import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/data.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../widget/discussion_card.dart';
import 'article_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = Get.find<Controller>();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('History'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() {
          if (c.history.isEmpty) return Center(child: Text('Empty'.tr));
          return WaterfallFlow.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
                const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 270,
            ),
            itemCount: c.history.length,
            itemBuilder: (context, index) {
              return Obx(() {
                return DiscussionCard(
                  article: c.history.elementAt(index),
                  onTap: (heroKey) {
                    Get.to<void>(() => ArticlePage(
                        heroKey: heroKey, article: c.history.elementAt(index)));
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
