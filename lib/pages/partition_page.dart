import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../common.dart';
import '../gen/assets.gen.dart';

class PartitionPage extends StatelessWidget {
  const PartitionPage({super.key});

  @override
  Widget build(BuildContext context) {
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
            MyCard(
              searchQuery: 'category:绝区零',
              img: Assets.images.zzz.provider(),
              text: 'Zenless Zone Zero'.tr,
            ),
            MyCard(
              searchQuery: 'category:原神',
              img: Assets.images.yuanshen.provider(),
              text: 'Genshin Impact'.tr,
            ),
            MyCard(
              searchQuery: 'category:崩坏：星穹铁道',
              img: Assets.images.sr.provider(),
              text: 'Honkai: Star Rail'.tr,
            ),
            MyCard(
              searchQuery: 'category:崩坏3',
              img: Assets.images.bh3.provider(),
              text: 'Honkai Impact 3'.tr,
            ),
            MyCard(
              searchQuery: 'category:科技',
              img: Assets.images.defaultCover.provider(),
              text: 'Technology'.tr,
            ),
            MyCard(
              searchQuery: 'category:公告',
              img: Assets.images.defaultCover.provider(),
              text: 'Announcement'.tr,
            ),
            MyCard(
              searchQuery: 'category:投票',
              img: Assets.images.defaultCover.provider(),
              text: 'Polls'.tr,
            ),
            MyCard(
              searchQuery: 'category:教程',
              img: Assets.images.defaultCover.provider(),
              text: 'Tutorial'.tr,
            ),
            MyCard(
              searchQuery: 'category:委托',
              img: Assets.images.defaultCover.provider(),
              text: 'Delegate'.tr,
            ),
            MyCard(
              searchQuery: 'category:其他',
              img: Assets.images.defaultCover.provider(),
              text: 'Other'.tr,
            ),
            MyCard(
              searchQuery: 'category:灌水',
              img: Assets.images.defaultCover.provider(),
              text: 'Irrigation'.tr,
            ),
          ],
        ),
      ),
    );
  }
}

class MyCard extends StatelessWidget {
  const MyCard({
    super.key,
    required this.searchQuery,
    required this.img,
    required this.text,
  });

  final String searchQuery;
  final ImageProvider img;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          c.searchQuery.value = searchQuery;
          c.animateToPage(1);
        },
        child: Container(
          alignment: Alignment.bottomCenter,
          decoration: BoxDecoration(
            image: DecorationImage(
              fit: BoxFit.cover,
              image: img,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              style: const TextStyle(fontSize: 24, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
