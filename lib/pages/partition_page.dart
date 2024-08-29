import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/data.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class PartitionPage extends StatelessWidget {
  const PartitionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Partition'.tr))],
        floatHeaderSlivers: true,
        body: GridView.extent(
          maxCrossAxisExtent: 270,
          padding: const EdgeInsets.all(8),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 5 / 6,
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '绝区零';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.zzz.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Zenless Zone Zero'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '原神';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.yuanshen.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Genshin Impact'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '崩坏：星穹铁道';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.sr.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Honkai: Star Rail'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '崩坏3';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.bh3.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Honkai Impact 3'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '科技';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.defaultCover.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Technology'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '教程';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.defaultCover.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Tutorial'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '委托';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.defaultCover.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Delegate'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '其他';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.defaultCover.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Other'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  c.searchQuery.value = '灌水';
                  c.animateToPage(1);
                },
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: Assets.images.defaultCover.provider(),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Irrigation'.tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
