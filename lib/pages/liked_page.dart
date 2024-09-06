import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../common.dart';
import '../widget/discussion_card.dart';
import 'article_page.dart';

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
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Like'.tr))],
        floatHeaderSlivers: true,
        body: Obx(() {
          if (c.bookmarks.isEmpty) return Center(child: Text('Empty'.tr));
          return WaterfallFlow.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate:
                const SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 270,
            ),
            itemCount: c.bookmarks.length,
            itemBuilder: (context, index) {
              return Obx(() {
                final item = c.bookmarks.elementAt(index);
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
                    if (snaphost.connectionState == ConnectionState.done) {
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => launchUrlString(item.url),
                          child: const AspectRatio(
                            aspectRatio: 5 / 6,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: Text('文章已删除')),
                            ),
                          ),
                        ),
                      );
                    }
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => launchUrlString(item.url),
                        child: const AspectRatio(
                          aspectRatio: 5 / 6,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
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
