import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../common.dart';
import '../widget/discussion_card.dart';
import 'article_page.dart';

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
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('History'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() {
          if (c.history.isEmpty) return Center(child: Text('Empty'.tr));
          return WaterfallFlow.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate:
                const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 270,
            ),
            itemCount: c.history.length,
            itemBuilder: (context, index) {
              return Obx(() {
                final item = c.history.elementAt(index);
                return FutureBuilder(
                  future: item.article,
                  builder: (context, snaphost) {
                    if (snaphost.hasData) {
                      return DiscussionCard(
                        article: snaphost.data!,
                        onTap: (heroKey) {
                          Get.to<void>(() => ArticlePage(
                              heroKey: heroKey, article: snaphost.data!));
                        },
                      );
                    }
                    if (snaphost.hasError) {
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: AspectRatio(
                          aspectRatio: 5 / 6,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                                child: SelectableText('${snaphost.error}')),
                          ),
                        ),
                      );
                    }
                    return const Card(
                      clipBehavior: Clip.antiAlias,
                      child: AspectRatio(
                        aspectRatio: 5 / 6,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    );
                  },
                );
              });
            },
          );
        }),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
