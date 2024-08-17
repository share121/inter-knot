import 'package:flutter/material.dart';

class Header extends StatelessWidget {
  const Header(
    this.text, {
    super.key,
    this.onPressed,
    required this.btnChild,
  });
  final String text;
  final void Function()? onPressed;
  final Widget btnChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            text,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          TextButton(onPressed: onPressed, child: btnChild)
        ],
      ),
    );
  }
}
