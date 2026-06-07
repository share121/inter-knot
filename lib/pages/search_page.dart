import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/ai_review_helper.dart';
import 'package:inter_knot/helpers/discussion_category_helper.dart';
import 'package:inter_knot/helpers/num2dur.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:inter_knot/models/discussion.dart';
import 'package:inter_knot/pages/new_discussion_page.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with AutomaticKeepAliveClientMixin {
  final c = Get.find<Controller>();

  final keyboardVisibilityController = KeyboardVisibilityController();
  late final keyboardSubscription =
      keyboardVisibilityController.onChange.listen((visible) {
    if (!visible) FocusManager.instance.primaryFocus?.unfocus();
  });

  late final fetchData = retryThrottle(
    c.searchData,
    const Duration(milliseconds: 500),
  );

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final borderColor =
        selected ? const Color(0xffD7FF00) : const Color(0xff2D2D2D);
    final backgroundColor =
        selected ? const Color(0xff2A2A2A) : const Color(0xff1A1A1A);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool iconOnly = false,
  }) {
    return Material(
      color: const Color(0xff1A1A1A),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 14 : 18,
            vertical: 10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              if (!iconOnly) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openNewDiscussion(BuildContext context) {
    if (kIsWeb) {
      launchUrlString(newDiscussionLink);
      return;
    }
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close'.tr,
      pageBuilder: (context, animation, secondaryAnimation) {
        return const NewDiscussionPage(url: newDiscussionLink);
      },
      transitionDuration: 300.ms,
      transitionBuilder: (context, animation, secondaryAnimation, child) {
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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return Stack(
      children: [
        Column(
          children: [
            Obx(() {
              final categories = c
                  .discussionCategories()
                  .where(
                    (category) => !isVideoDiscussionCategoryName(category.name),
                  )
                  .toList();
              final selectedCategoryIds = c.selectedCategoryIds();
              final visibleCategoryIds =
                  categories.map((category) => category.id).toSet();
              final invalidSelectedIds = selectedCategoryIds
                  .where((id) => !visibleCategoryIds.contains(id))
                  .toList();
              if (invalidSelectedIds.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  c.selectedCategoryIds.removeAll(invalidSelectedIds);
                  c.selectedCategoryIds.refresh();
                });
              }

              if (categories.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: categories.map((category) {
                          final selected =
                              selectedCategoryIds.contains(category.id);
                          final categoryView =
                              mapDiscussionCategory(category.name);
                          final label =
                              categoryView?.displayName ?? category.name;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _buildFilterChip(
                              label: label,
                              selected: selected,
                              onTap: () {
                                final value = !selected;
                                if (value) {
                                  c.selectedCategoryIds.add(category.id);
                                } else {
                                  c.selectedCategoryIds.remove(category.id);
                                }
                                c.selectedCategoryIds.refresh();
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
            Obx(() {
              final selectedRatings = c.selectedAiReviewRatings();
              final ratingViews = <MapEntry<AiReviewRating, AiReviewView>>[];
              for (final rating in aiReviewFilterOrder) {
                final view = mapAiReviewRatingView(rating);
                if (view != null) {
                  ratingViews.add(MapEntry(rating, view));
                }
              }

              return Column(
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'AI Review'.tr,
                              style: const TextStyle(
                                color: Color(0xffB3B3B1),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ...ratingViews.map((entry) {
                            final rating = entry.key;
                            final view = entry.value;
                            final selected = selectedRatings.contains(rating);
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildFilterChip(
                                label: view.displayName.tr,
                                selected: selected,
                                onTap: () {
                                  if (selected) {
                                    c.selectedAiReviewRatings.remove(rating);
                                  } else {
                                    c.selectedAiReviewRatings.add(rating);
                                  }
                                  c.selectedAiReviewRatings.refresh();
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }),
            Expanded(
              child: isCompact
                  ? RefreshIndicator(
                      displacement: 56,
                      onRefresh: () async {
                        await c.refreshSearchData();
                      },
                      child: Obx(() {
                        final selectedIds = c.selectedCategoryIds().toList()
                          ..sort();
                        final selectedRatings = c
                            .selectedAiReviewRatings()
                            .toList()
                          ..sort((a, b) => a.index.compareTo(b.index));
                        return DiscussionGrid(
                          key: ValueKey(
                            'search-${selectedIds.join(",")}-${selectedRatings.map((e) => e.name).join(",")}-${c.searchQuery()}',
                          ),
                          list: c.mergedSearchResult,
                          hasNextPage: c.searchHasNextPage(),
                          fetchData: fetchData,
                          selectedCategoryIds: selectedIds.toSet(),
                          selectedAiReviewRatings: selectedRatings.toSet(),
                          isLoadingCurrentPage: c.searchLoading(),
                        );
                      }),
                    )
                  : Obx(() {
                      final selectedIds = c.selectedCategoryIds().toList()
                        ..sort();
                      final selectedRatings = c
                          .selectedAiReviewRatings()
                          .toList()
                        ..sort((a, b) => a.index.compareTo(b.index));
                      return DiscussionGrid(
                        key: ValueKey(
                          'search-${selectedIds.join(",")}-${selectedRatings.map((e) => e.name).join(",")}-${c.searchQuery()}',
                        ),
                        list: c.mergedSearchResult,
                        hasNextPage: c.searchHasNextPage(),
                        fetchData: fetchData,
                        selectedCategoryIds: selectedIds.toSet(),
                        selectedAiReviewRatings: selectedRatings.toSet(),
                        isLoadingCurrentPage: c.searchLoading(),
                      );
                    }),
            ),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: isCompact
              ? IconButton.filledTonal(
                  iconSize: 28,
                  padding: const EdgeInsets.all(12),
                  onPressed: () => _openNewDiscussion(context),
                  icon: const Icon(Icons.add),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildActionButton(
                      icon: Icons.refresh_rounded,
                      label: 'Refresh'.tr,
                      iconOnly: true,
                      onTap: () => c.refreshSearchData(),
                    ),
                    const SizedBox(height: 12),
                    _buildActionButton(
                      icon: Icons.add,
                      label: 'Create a new discussion'.tr,
                      onTap: () => _openNewDiscussion(context),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
