import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:inter_knot/components/my_html_widget.dart';
import 'package:inter_knot/constants/globals.dart';
import 'package:inter_knot/controllers/data.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ReportDiscussionComment extends StatelessWidget {
  const ReportDiscussionComment({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.find<Controller>();
    return Obx(() {
      return Column(
        children: [
          for (final MapEntry(:key, :value) in c.report.entries) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Discussions that have been reported: '.tr),
                    TextSpan(
                      text: '#$key',
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => launchUrlString(
                              '$discussionsLink/$key',
                            ),
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        color: Theme.of(context).colorScheme.primary,
                        decorationColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const TextSpan(text: '\n'),
                    TextSpan(
                      text: 'A total of @count reports'
                          .trParams({'count': value.length.toString()}),
                    ),
                  ],
                ),
              ),
              subtitle: Column(
                children: [
                  for (final (index, comment) in value.indexed)
                    ListTile(
                      minVerticalPadding: 0,
                      title: Row(
                        children: [
                          Flexible(
                            child: InkWell(
                              onTap: () => launchUrlString(comment.url),
                              child: Text(comment.login),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Column(
                        children: [
                          Builder(
                            builder: (context) {
                              final hasIframe = RegExp(
                                r'<\s*iframe\b',
                                caseSensitive: false,
                              ).hasMatch(comment.bodyHTML);
                              if (hasIframe) {
                                return MyHtmlWidget(
                                  html: comment.bodyHTML,
                                  inDiscussionDetail: true,
                                );
                              }
                              return SelectionArea(
                                child: MyHtmlWidget(
                                  html: comment.bodyHTML,
                                  inDiscussionDetail: true,
                                ),
                              );
                            },
                          ),
                          if (index != value.length - 1) const Divider(),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
          ],
        ],
      );
    });
  }
}
