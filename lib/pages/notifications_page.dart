import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

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
  final c = Get.find<Controller>();

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
            padding: const EdgeInsets.all(16),
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
                  if (c.hasNextPage.isFalse) return Text('No more data.'.tr);
                  return const SizedBox(
                    width: 60,
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return DiscussionCard(
                  article: c.data[index],
                  onTap: (heroKey) {
                    Get.to<void>(() => Obx(() =>
                        ArticlePage(heroKey: heroKey, article: c.data[index])));
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
            onPressed: () => c.refreshData(),
            tooltip: 'Refresh'.tr,
            child: const Icon(Icons.refresh),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
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
