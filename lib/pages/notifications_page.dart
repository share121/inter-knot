import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/pages/article_page.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

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
    final c = Get.find<Controller>();

    return Scaffold(
      appBar: AppBar(title: Text('Notifications'.tr)),
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
          addAutomaticKeepAlives: true,
          itemCount: c.data.length + 1,
          itemBuilder: (context, index) {
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
                Get.to<void>(() =>
                    ArticlePage(heroKey: heroKey, article: c.data[index]));
              },
            );
          },
        );
      }),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
