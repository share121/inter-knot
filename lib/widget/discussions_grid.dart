import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

import '../common.dart';
import '../interface.dart';
import '../pages/discussion_page.dart';
import 'discussion_card.dart';

class DiscussionGrid extends StatelessWidget {
  const DiscussionGrid({
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
    return LayoutBuilder(builder: (context, con) {
      return WaterfallFlow.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
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
            future: item.discussion,
            builder: (context, snaphost) {
              if (snaphost.hasData) {
                return DiscussionCard(
                  discussion: snaphost.data!,
                  isPin: item.isPin,
                  onTap: () {
                    showGeneralDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierLabel: 'Close'.tr,
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return DiscussionPage(
                          discussion: snaphost.data!,
                          isPin: item.isPin,
                        );
                      },
                      transitionDuration: 300.ms,
                      transitionBuilder:
                          (context, animaton1, secondaryAnimation, child) {
                        return FadeTransition(
                          opacity: animaton1,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0.1, 0.0),
                              end: const Offset(0.0, 0.0),
                            ).animate(CurvedAnimation(
                                parent: animaton1, curve: Curves.ease)),
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                );
              }
              if (snaphost.hasError) {
                return Card(
                  clipBehavior: Clip.antiAlias,
                  color: const Color(0xff222222),
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
                  color: const Color(0xff222222),
                  child: InkWell(
                    onTap: () => launchUrlString(
                      item.url,
                      mode: LaunchMode.inAppWebView,
                    ),
                    child: AspectRatio(
                      aspectRatio: 5 / 6,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(child: Text('Discussion deleted'.tr)),
                      ),
                    ),
                  ),
                );
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                color: const Color(0xff222222),
                child: InkWell(
                  onTap: () => launchUrlString(
                    item.url,
                    mode: LaunchMode.inAppWebView,
                  ),
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
    });
  }
}
