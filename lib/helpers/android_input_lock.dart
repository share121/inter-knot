import 'package:flutter/foundation.dart';

class AndroidInputLock {
  AndroidInputLock._();

  static final ValueNotifier<bool> _lockedNotifier = ValueNotifier<bool>(false);

  static ValueListenable<bool> get lockedListenable => _lockedNotifier;

  static bool get requiresExplicitConfirm =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isLocked => requiresExplicitConfirm && _lockedNotifier.value;

  static void lock() {
    if (!requiresExplicitConfirm) return;
    if (_lockedNotifier.value) return;
    _lockedNotifier.value = true;
  }

  static void unlock() {
    if (!_lockedNotifier.value) return;
    _lockedNotifier.value = false;
  }
}
