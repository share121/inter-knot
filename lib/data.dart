import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Controller extends GetxController {
  final selectedIndex = 0.obs;
  final pageController = PageController();

  Future<void> animateToPage(int index) {
    selectedIndex.value = index;
    return pageController.animateToPage(
      index,
      duration: 0.5.s,
      curve: Curves.ease,
    );
  }
}

extension Use<V> on V? {
  T? use<T>(T Function(V value) fn) => this == null ? null : fn(this as V);
}

extension True on bool {
  T? isTrue<T>(T Function() fn) => this == true ? fn() : null;
  T? isFalse<T>(T Function() fn) => this == false ? fn() : null;
}

extension Num2Duration on num {
  Duration get microseconds => Duration(microseconds: toInt());
  Duration get ms => (this * 1000).microseconds;
  Duration get s => (this * 1000).ms;
  Duration get min => (this * 60).s;
  Duration get hour => (this * 60).min;
  Duration get day => (this * 24).hour;
  Duration get week => (this * 7).day;
}

extension DurationFomater on Duration {
  /// MM:SS
  String get format =>
      '${inMinutes.toString().padLeft(2, '0')}:${inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

class Author {
  final String name;
  final String avatar;
  final String url;

  Author({
    required this.name,
    required this.avatar,
    required this.url,
  });
}
