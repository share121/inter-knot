import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/controllers/data.dart';

class LikedPage extends StatefulWidget {
  const LikedPage({super.key});

  @override
  State<LikedPage> createState() => _LikedPageState();
}

class _LikedPageState extends State<LikedPage>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(title: Text('Like'.tr)),
      body: Obx(() => DiscussionGrid(list: c.bookmarks().toList(), hasNextPage: false)),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
