import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/pages/material.dart';
import 'package:inter_knot/pages/video_archive_page.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class ToolkitPage extends StatelessWidget {
  const ToolkitPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WaterfallFlow.extent(
      maxCrossAxisExtent: 250,
      padding: const EdgeInsets.all(8),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Get.to(() => const KnockKnockPage()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '敲敲 UI',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '打开敲敲 UI 界面',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Get.to(() => const VideoArchivePage()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.video_library_rounded, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '录像带陈列',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '打开录像带陈列界面',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
