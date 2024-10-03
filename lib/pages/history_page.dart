import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';

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
      backgroundColor: const Color(0xff121212),
      appBar: AppBar(title: Text('History'.tr)),
      body: Obx(() => DiscussionGrid(list: c.history(), hasNextPage: false)),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
