import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class Updata extends StatefulWidget {
  const Updata({
    super.key,
    required this.newFullVer,
    required this.curFullVer,
    required this.mustUpdate,
    required this.descriptionHTML,
    required this.release,
  });

  final String newFullVer;
  final String curFullVer;
  final String descriptionHTML;
  final bool mustUpdate;
  final Release release;

  @override
  State<Updata> createState() => _UpdataState();
}

const f = [
  'gh.llkk.cc',
  'github.moeyy.xyz',
  'mirror.ghproxy.com',
  'ghproxy.net',
  'gh.ddlc.top',
];

class _UpdataState extends State<Updata> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('New version available'.tr),
      content: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    onTap: () => copyText(widget.curFullVer),
                    title: Text('Current version'.tr),
                    subtitle: Text(widget.curFullVer),
                  ),
                  ListTile(
                    onTap: () => copyText(widget.newFullVer),
                    title: Text('Latest version'.tr),
                    subtitle: Text(widget.newFullVer),
                  ),
                  ListTile(
                    onTap: () {},
                    title: Text('Update content'.tr),
                    subtitle: widget.descriptionHTML.trim().isEmpty
                        ? Text('Empty'.tr)
                        : HtmlWidget(widget.descriptionHTML),
                  ),
                  const Divider(),
                  for (final item in widget.release.releaseAssets)
                    ListTile(
                      title: Text(item.name.tr),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last edited on: '.tr +
                                item.updatedAt.toLocal().toString(),
                          ),
                          Text(
                            'Size: @size bytes'
                                .trParams({'size': item.size.toString()}),
                          ),
                          Text(
                            'Download count: '.tr +
                                item.downloadCount.toString(),
                          ),
                        ],
                      ),
                      onTap: () =>
                          launchUrlString(c.accelerator() + item.downloadUrl),
                    ),
                ],
              ),
            ),
          ),
          ListTile(title: Text('Accelerator'.tr)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Column(
                  children: [
                    Obx(
                      () => Radio(
                        value: '',
                        groupValue: c.accelerator(),
                        onChanged: c.accelerator.call,
                      ),
                    ),
                    const Text('Github'),
                  ],
                ),
                for (final e in f) ...[
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Obx(
                        () => Radio(
                          value: 'https://$e/',
                          groupValue: c.accelerator(),
                          onChanged: c.accelerator.call,
                        ),
                      ),
                      Text(e),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (!widget.mustUpdate)
          TextButton(
            onPressed: () => Get.back(),
            child: Text('OK'.tr),
          ),
      ],
    );
  }
}
