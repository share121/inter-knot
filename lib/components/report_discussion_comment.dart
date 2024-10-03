import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ReportDiscussionComment extends StatelessWidget {
  const ReportDiscussionComment({super.key});

  @override
  Widget build(BuildContext context) {
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
                              'https://github.com/share121/inter-knot/discussions/$key',
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
                          SelectionArea(
                            child: HtmlWidget(comment.bodyHTML),
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
