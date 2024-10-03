import 'package:flutter/material.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/discussions_grid.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:inter_knot/helpers/throttle.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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

  @override
  void dispose() {
    keyboardSubscription.cancel();
    super.dispose();
  }

  late final fetchData = retryThrottle(c.searchData);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SearchBar(
                controller: c.searchController,
                onSubmitted: c.searchQuery.call,
                backgroundColor:
                    const WidgetStatePropertyAll(Color(0xff222222)),
                leading: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.search),
                ),
                hintText: 'Search for discussions'.tr,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Obx(() {
                return DiscussionGrid(
                  list: c.searchResult(),
                  hasNextPage: c.searchHasNextPage(),
                  fetchData: fetchData,
                );
              }),
            ),
          ],
        ),
        Positioned(
          right: 24,
          bottom: 24,
          child: IconButton.filledTonal(
            iconSize: 32,
            padding: const EdgeInsets.all(12),
            onPressed: () => launchUrlString(
              'https://github.com/share121/inter-knot/discussions/new/choose',
            ),
            icon: Icon(MdiIcons.pen),
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
