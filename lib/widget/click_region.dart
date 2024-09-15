import 'package:flutter/material.dart';

class ClickRegion extends StatelessWidget {
  const ClickRegion({
    super.key,
    required this.child,
    required this.onTap,
    this.hitTestBehavior = HitTestBehavior.opaque,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final void Function() onTap;
  final HitTestBehavior hitTestBehavior;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      hitTestBehavior: hitTestBehavior,
      child: GestureDetector(
        behavior: behavior,
        onTap: onTap,
        child: child,
      ),
    );
  }
}
