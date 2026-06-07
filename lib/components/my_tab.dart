import 'package:flutter/material.dart';
import 'package:inter_knot/components/click_region.dart';
import 'package:inter_knot/helpers/num2dur.dart';

class MyTab extends StatelessWidget {
  const MyTab({
    super.key,
    required this.text,
    required this.onTap,
    this.first = false,
    this.last = false,
    this.trailing,
    this.isSelected = false,
  }) : assert(first && !last || !first && last || !first && !last);

  final String text;
  final void Function() onTap;
  final bool first;
  final bool last;
  final Widget? trailing;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ClickRegion(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          children: [
            AnimatedDefaultTextStyle(
              duration: 200.ms,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: isSelected ? const Color(0xffD7FF00) : Colors.white,
              ),
              child: Text(text),
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
    );
  }
}
