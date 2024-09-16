import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../gen/assets.gen.dart';
import '../main.dart';
import 'avatar.dart';
import 'my_tab.dart';

class MyAppBar extends StatelessWidget {
  const MyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: max(MediaQuery.of(context).size.width, 640),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.black,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff212121),
                      Color(0xff141414),
                      Color(0xff181818),
                    ],
                    stops: [0, 0.9, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(maxRadius),
                ),
                child: Row(
                  children: [
                    Obx(() => Avatar(c.user()?.avatar)),
                    const SizedBox(width: 4),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() {
                          return Text(
                            c.user()?.name() ?? 'Not logged in'.tr,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }),
                        const SizedBox(height: 4),
                        Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(
                              width: 150,
                              height: 16,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(maxRadius),
                                color: const Color(0xff222222),
                              ),
                              clipBehavior: Clip.antiAlias,
                              alignment: Alignment.topLeft,
                              child: FractionallySizedBox(
                                widthFactor: 502 / 1145,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(maxRadius),
                                    gradient: const LinearGradient(colors: [
                                      Color(0xff4661fd),
                                      Color(0xff10bff0),
                                    ]),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                ),
                              ),
                            ),
                            const Positioned(
                              left: 4,
                              child: Text(
                                '502/1145',
                                style: TextStyle(fontSize: 12, height: 1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Column(
                      children: [
                        Obx(() => Text(
                              c.user()?.level().toString() ?? '0',
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1,
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                        const SizedBox(height: 4),
                        const Text(
                          'LEVEL',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xff313131),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(maxRadius),
                  image: DecorationImage(
                    image: Assets.images.tabBgPoint.provider(),
                    repeat: ImageRepeat.repeat,
                  ),
                ),
                child: Row(
                  children: [
                    Obx(() {
                      return MyTab(
                        first: true,
                        text: 'Notifications'.tr,
                        trailing:
                            c.curPage() == 0 ? const Icon(Icons.refresh) : null,
                        onTap: () {
                          if (c.curPage() == 0) c.refreshSearchData();
                          c.animateToPage(0);
                        },
                      );
                    }),
                    MyTab(
                      text: 'Toolkit'.tr,
                      onTap: () => c.animateToPage(1),
                    ),
                    MyTab(
                      text: 'Home'.tr,
                      onTap: () => c.animateToPage(2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
