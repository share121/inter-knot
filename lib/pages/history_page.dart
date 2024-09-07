import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../widget/article_grid.dart';

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
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('History'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() => ArticleGrid(list: c.history(), hasNextPage: false)),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
