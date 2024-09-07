import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../widget/article_grid.dart';
import '../common.dart';
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
        headerSliverBuilder: (context, innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Notifications'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() {
          return ArticleGrid(
            list: c.data(),
            hasNextPage: c.hasNextPage(),
            fetchData: c.fetchData,
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
                'https://github.com/$owner/$repo/discussions/new/choose'),
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
