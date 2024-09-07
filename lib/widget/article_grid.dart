import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../interface.dart';
import '../pages/article_page.dart';
import 'discussion_card.dart';

class ArticleGrid extends StatelessWidget {
  const ArticleGrid({
    super.key,
    required this.list,
    required this.hasNextPage,
    this.fetchData,
  });

  final Set<HData> list;
  final bool hasNextPage;
  final void Function()? fetchData;

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return Center(child: Text('Empty'.tr));
    return WaterfallFlow.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 270,
        lastChildLayoutTypeBuilder: (index) => index == list.length
            ? LastChildLayoutType.foot
            : LastChildLayoutType.none,
        viewportBuilder: (firstIndex, lastIndex) {
          if (lastIndex == list.length) fetchData?.call();
        },
      ),
      itemCount: list.length + 1,
      itemBuilder: (context, index) {
        if (index == list.length) {
          if (hasNextPage) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text('No more data'.tr),
            ),
          );
        }
        final item = list.elementAt(index);
        return FutureBuilder(
          future: item.article,
          builder: (context, snaphost) {
            if (snaphost.hasData) {
              return DiscussionCard(
                article: snaphost.data!,
                isPin: item.isPin,
                onTap: (heroKey) {
                  Get.to(() => ArticlePage(
                        heroKey: heroKey,
                        article: snaphost.data!,
                        isPin: item.isPin,
                      ));
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
                    child: Center(child: SelectableText('${snaphost.error}')),
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
      },
    );
  }
}
