import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/widget/water_fall.dart';

import '../widget/discussion_card.dart';
import '../data.dart';

class NotificationsPage extends GetView<Controller> {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notifications'.tr)),
      body: WaterFall(
        minWidth: 256,
        children: [
          for (final _ in Iterable.generate(100, (_) => null))
            DiscussionCard(
              title: '原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神原神',
              bodyHTML:
                  '<h1>欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆</h1>',
              bodyText:
                  '欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆欢迎来到提瓦特大陆',
              author: Author(
                avatar: 'https://avatars.githubusercontent.com/u/111939263',
                name:
                    'share121share121share121share121share121share121share121share121share121share121share121share121share121share121',
                url: 'https://github.com/share121',
              ),
              cover:
                  'https://private-user-images.githubusercontent.com/111939263/356276367-9b3c5657-5489-436a-9675-8b6eb729a61f.png?jwt=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3MjM4NjE1NjYsIm5iZiI6MTcyMzg2MTI2NiwicGF0aCI6Ii8xMTE5MzkyNjMvMzU2Mjc2MzY3LTliM2M1NjU3LTU0ODktNDM2YS05Njc1LThiNmViNzI5YTYxZi5wbmc_WC1BbXotQWxnb3JpdGhtPUFXUzQtSE1BQy1TSEEyNTYmWC1BbXotQ3JlZGVudGlhbD1BS0lBVkNPRFlMU0E1M1BRSzRaQSUyRjIwMjQwODE3JTJGdXMtZWFzdC0xJTJGczMlMkZhd3M0X3JlcXVlc3QmWC1BbXotRGF0ZT0yMDI0MDgxN1QwMjIxMDZaJlgtQW16LUV4cGlyZXM9MzAwJlgtQW16LVNpZ25hdHVyZT1iMWIzYWIxZmFhNjYwNGQ2NWVhOWM0Y2VhMDQwZDJmYjQ1YTRjNGI0YWNkYTJiYjQyYmU3YTAxNmZjZDA2NTJhJlgtQW16LVNpZ25lZEhlYWRlcnM9aG9zdCZhY3Rvcl9pZD0wJmtleV9pZD0wJnJlcG9faWQ9MCJ9.FsEfRW4t-POfQYFlmnCKOa9JKbU9GTuWpdrVATdWQHI',
            ),
        ],
      ),
    );
  }
}
