import 'package:flutter/material.dart';
import 'package:inter_knot/components/click_region.dart';

class MyTab extends StatelessWidget {
  const MyTab({
    super.key,
    required this.text,
    required this.onTap,
    this.first = false,
    this.last = false,
    this.trailing,
  }) : assert(first && !last || !first && last || !first && !last);

  final String text;
  final void Function() onTap;
  final bool first;
  final bool last;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ClickRegion(
      onTap: onTap,
      child: Stack(
        children: [
          if (first) Container(),
          if (last) Container(),
          if (!first && !last) Container(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
            child: Row(
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                AnimatedContainer(
                  duration: 200.ms,
                  curve: Curves.ease,
                  width: trailing == null ? 0 : 32,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
