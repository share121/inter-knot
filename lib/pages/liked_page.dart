import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../widget/discussions_grid.dart';

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
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(title: Text('Like'.tr)),
      body: Obx(() => DiscussionGrid(list: c.bookmarks(), hasNextPage: false)),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
