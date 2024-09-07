import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class ToolkitPage extends StatelessWidget {
  const ToolkitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Toolkit'.tr))],
        floatHeaderSlivers: true,
        body: WaterfallFlow.extent(
          maxCrossAxisExtent: 270,
          padding: const EdgeInsets.all(8),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Toolkit',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
