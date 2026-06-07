import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussion_card.dart';
import 'package:inter_knot/gen/assets.gen.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/models/h_data.dart';
import 'package:inter_knot/pages/discussion_page.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class DiscussionEmptyState extends StatelessWidget {
  const DiscussionEmptyState({
    super.key,
    required this.message,
    this.imageAsset,
    this.imageSize = 120,
    this.textStyle,
  });

  final String message;
  final String? imageAsset;
  final double imageSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageAsset != null && imageAsset!.isNotEmpty;
    final hasMessage = message.trim().isNotEmpty;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        if (hasImage)
          Image.asset(
            imageAsset!,
            width: imageSize,
            height: imageSize,
          ),
        if (hasImage && hasMessage) const SizedBox(height: 16),
        if (hasMessage)
          Text(
            message,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }
}

bool _matchesAiReviewFilter({
  required HDataModel item,
  Set<AiReviewRating>? selectedAiReviewRatings,
}) {
  if (selectedAiReviewRatings == null || selectedAiReviewRatings.isEmpty) {
    return true;
  }
  final rating = item.aiReviewRatingFromLabels;
  if (rating == null) return false;
  return selectedAiReviewRatings.contains(rating);
}

bool _matchesCategoryFilter({
  required DiscussionModel discussion,
  Set<String>? selectedCategoryIds,
}) {
  if (selectedCategoryIds != null && selectedCategoryIds.isNotEmpty) {
    final categoryId = discussion.categoryId;
    if (categoryId == null || !selectedCategoryIds.contains(categoryId)) {
      return false;
    }
  }
  return true;
}

bool _matchesCategoryOnListItem({
  required HDataModel item,
  Set<String>? selectedCategoryIds,
}) {
  if (selectedCategoryIds == null || selectedCategoryIds.isEmpty) {
    return true;
  }
  final id = item.categoryId;
  if (id == null || !selectedCategoryIds.contains(id)) {
    return false;
  }
  return true;
}

/// When [HDataModel.categoryName] is known, drop video-category rows here so
/// the waterfall does not reserve cells that later shrink. Items without a
/// category name still pass through (e.g. bookmarks) and rely on [DiscussionModel].
bool _passesSyncVideoListFilter(HDataModel item) {
  final name = item.categoryName;
  if (name == null || name.trim().isEmpty) {
    return true;
  }
  return !isVideoDiscussionCategoryName(name);
}

Future<bool> _hasRenderableMatch({
  required List<HDataModel> items,
  Set<String>? selectedCategoryIds,
}) async {
  for (final item in items) {
    try {
      final discussion = await item.discussion;
      if (discussion == null) continue;
      if (isVideoDiscussion(discussion)) continue;
      if (!_matchesCategoryFilter(
        discussion: discussion,
        selectedCategoryIds: selectedCategoryIds,
      )) {
        continue;
      }
      return true;
    } catch (_) {
      continue;
    }
  }
  return false;
}

class DiscussionGrid extends StatelessWidget {
  const DiscussionGrid({
    super.key,
    required this.list,
    required this.hasNextPage,
    this.fetchData,
    this.selectedCategoryIds,
    this.selectedAiReviewRatings,
    this.isLoadingCurrentPage = false,
  });

  final List<HDataModel> list;
  final bool hasNextPage;
  final void Function()? fetchData;
  final Set<String>? selectedCategoryIds;
  final Set<AiReviewRating>? selectedAiReviewRatings;
  final bool isLoadingCurrentPage;

  @override
  Widget build(BuildContext context) {
    final filteredList = list
        .where(
          (item) => _matchesAiReviewFilter(
            item: item,
            selectedAiReviewRatings: selectedAiReviewRatings,
          ),
        )
        .where(
          (item) => _matchesCategoryOnListItem(
            item: item,
            selectedCategoryIds: selectedCategoryIds,
          ),
        )
        .where(_passesSyncVideoListFilter)
        .toList();
    final hasCategoryFilter =
        selectedCategoryIds != null && selectedCategoryIds!.isNotEmpty;

    if (list.isEmpty && hasNextPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchData?.call();
      });
    }

    Widget buildEmptyState() {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: DiscussionEmptyState(
                message: 'Empty'.tr,
                imageAsset: Assets.images.zzz.path,
                textStyle: const TextStyle(
                  color: Color(0xff808080),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildGrid(List<HDataModel> items) {
      return LayoutBuilder(
        builder: (context, con) {
          final width = MediaQuery.of(context).size.width;
          final isCompact = width < 640;
          final mainAxisSpacing = isCompact ? 10.0 : 12.0;
          final crossAxisSpacing = isCompact ? 8.0 : 10.0;
          final maxCrossAxisExtent = isCompact ? 273.0 : 264.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1450),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth == 0 &&
                      notification.metrics.extentAfter < 500 &&
                      hasNextPage) {
                    fetchData?.call();
                  }
                  return false;
                },
                child: WaterfallFlow.builder(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                  gridDelegate:
                      SliverWaterfallFlowDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: maxCrossAxisExtent,
                    mainAxisSpacing: mainAxisSpacing,
                    crossAxisSpacing: crossAxisSpacing,
                    lastChildLayoutTypeBuilder: (index) => index == items.length
                        ? LastChildLayoutType.foot
                        : LastChildLayoutType.none,
                  ),
                  itemCount: items.length + 1,
                  itemBuilder: (context, index) {
                    if (index == items.length) {
                      if (hasNextPage) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Assets.images.zzz.image(
                              width: 80,
                              height: 80,
                            ),
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

                    final item = items.elementAt(index);
                    return FutureBuilder<DiscussionModel?>(
                      future: item.discussion,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final discussion = snapshot.data!;
                          if (isVideoDiscussion(discussion)) {
                            return const SizedBox.shrink();
                          }
                          if (!_matchesCategoryFilter(
                            discussion: discussion,
                            selectedCategoryIds: selectedCategoryIds,
                          )) {
                            return const SizedBox.shrink();
                          }
                          return DiscussionCard(
                            discussion: discussion,
                            hData: item,
                            onTap: () {
                              showGeneralDialog(
                                context: context,
                                barrierDismissible: true,
                                barrierLabel: 'Close'.tr,
                                pageBuilder:
                                    (context, animation, secondaryAnimation) {
                                  return DiscussionPage(
                                    discussion: snapshot.data!,
                                    hData: item,
                                  );
                                },
                                transitionDuration: 300.ms,
                                transitionBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween(
                                        begin: const Offset(0.1, 0.0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.ease,
                                        ),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }
                        if (snapshot.hasError) {
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            color: const Color(0xff222222),
                            child: AspectRatio(
                              aspectRatio: 5 / 6,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Center(
                                  child: SelectableText('${snapshot.error}'),
                                ),
                              ),
                            ),
                          );
                        }
                        if (snapshot.connectionState == ConnectionState.done) {
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            color: const Color(0xff222222),
                            child: InkWell(
                              onTap: () => launchUrlString(item.url),
                              child: AspectRatio(
                                aspectRatio: 5 / 6,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Center(
                                    child: Text('Discussion deleted'.tr),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          color: const Color(0xff222222),
                          child: InkWell(
                            onTap: () => launchUrlString(item.url),
                            child: const AspectRatio(
                              aspectRatio: 5 / 6,
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          );
        },
      );
    }

    Widget buildLoadMorePrompt() {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No matches on this page'.tr,
                    style: const TextStyle(
                      color: Color(0xff808080),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: fetchData,
                    child: Text('Load more'.tr),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (isLoadingCurrentPage) {
      return buildGrid(list);
    }

    if (hasCategoryFilter) {
      final hasMatch = filteredList.isNotEmpty;
      if (!hasMatch) {
        if (hasNextPage && list.isNotEmpty) {
          return buildLoadMorePrompt();
        }
        if (hasNextPage && list.isEmpty) {
          return buildGrid(list);
        }
        return buildEmptyState();
      }
      return buildGrid(filteredList);
    }

    return FutureBuilder<bool>(
      future: _hasRenderableMatch(items: filteredList),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return buildGrid(filteredList);
        }
        final hasMatch = snapshot.data ?? false;
        if (!hasMatch) {
          if (hasNextPage && list.isNotEmpty) {
            return buildLoadMorePrompt();
          }
          if (hasNextPage && list.isEmpty) {
            return buildGrid(list);
          }
          return buildEmptyState();
        }
        return buildGrid(filteredList);
      },
    );
  }
}
