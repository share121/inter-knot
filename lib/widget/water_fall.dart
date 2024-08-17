import 'dart:math';

import 'package:flutter/material.dart';

class WaterFall extends StatefulWidget {
  const WaterFall({super.key, required this.minWidth, required this.children})
      : assert(minWidth > 0);

  final double minWidth;
  final List<Widget> children;

  @override
  State<WaterFall> createState() => _WaterFallState();
}

class _WaterFallState extends State<WaterFall> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, con) {
      final col = max(con.maxWidth ~/ widget.minWidth, 1);
      return SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final i in Iterable.generate(col, (i) => i))
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children.indexed
                      .where((e) => e.$1 % col == i)
                      .map((e) => e.$2)
                      .toList(),
                ),
              )
          ],
        ),
      );
    });
  }
}
