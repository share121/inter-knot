import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../widget/article_grid.dart';

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
        headerSliverBuilder: (context, innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Like'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() => ArticleGrid(list: c.bookmarks(), hasNextPage: false)),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
