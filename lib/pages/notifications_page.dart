import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../common.dart';
import 'article_page.dart';
import '../widget/discussion_card.dart';
import '../data.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Notifications'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() {
          if (c.data.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return WaterfallFlow.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 270,
              lastChildLayoutTypeBuilder: (index) => index == c.data.length
                  ? LastChildLayoutType.foot
                  : LastChildLayoutType.none,
              viewportBuilder: (firstIndex, lastIndex) {
                if (lastIndex == c.data.length) c.fetchData();
              },
            ),
            itemCount: c.data.length + 1,
            itemBuilder: (context, index) {
              return Obx(() {
                if (index == c.data.length) {
                  if (c.hasNextPage.isFalse) {
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
                  article: c.data.elementAt(index),
                  onTap: (heroKey) {
                    Get.to<void>(() => ArticlePage(
                        heroKey: heroKey, article: c.data.elementAt(index)));
                  },
                );
              });
            },
          );
        }),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: null,
            onPressed: () => c.refreshData(),
            tooltip: 'Refresh'.tr,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: null,
            onPressed: () => launchUrlString(
                'https://github.com/$owner/$repo/discussions/new?category=general'),
            tooltip: 'Create a new discussion'.tr,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
