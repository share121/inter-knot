import 'package:flutter/material.dart';

class MyChip extends StatelessWidget {
  const MyChip(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(left: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Text(text, style: const TextStyle(fontSize: 10)),
      ),
    );
  }
}
