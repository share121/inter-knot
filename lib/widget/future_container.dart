import 'package:flutter/material.dart';

class FutureContainer<T> extends StatelessWidget {
  const FutureContainer(
    this.future, {
    super.key,
    required this.builder,
  });
  final Future<T> future;
  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasData) return builder(context, snapshot.data as T);
        return const SizedBox();
      },
    );
  }
}
