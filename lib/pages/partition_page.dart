import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/gen/assets.gen.dart';

class PartitionPage extends StatefulWidget {
  const PartitionPage({super.key});

  @override
  State<PartitionPage> createState() => _PartitionPageState();
}

class _PartitionPageState extends State<PartitionPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            [SliverAppBar(title: Text('Partition'.tr))],
        floatHeaderSlivers: true,
        body: GridView.extent(
          maxCrossAxisExtent: 270,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 5 / 6,
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
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
            Card(
              clipBehavior: Clip.antiAlias,
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
            Card(
              clipBehavior: Clip.antiAlias,
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
            Card(
              clipBehavior: Clip.antiAlias,
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
            Card(
              clipBehavior: Clip.antiAlias,
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
            Card(
              clipBehavior: Clip.antiAlias,
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
            Card(
              clipBehavior: Clip.antiAlias,
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
            Card(
              clipBehavior: Clip.antiAlias,
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
            Card(
              clipBehavior: Clip.antiAlias,
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
          ],
        ),
      ),
    );
  }
}
