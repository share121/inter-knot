import 'package:flutter/material.dart';
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '还没做好呢😎',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
