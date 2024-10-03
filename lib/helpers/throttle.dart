import 'dart:async';

Future<void> Function() throttle(
  FutureOr<void> Function() func, [
  Duration delay = const Duration(seconds: 5),
]) {
  var flag = false;
  return () async {
    if (flag) return;
    flag = true;
    await func();
    Timer(delay, () => flag = false);
  };
}

Future<void> Function() retryThrottle(
  FutureOr<void> Function() func, [
  Duration delay = const Duration(seconds: 5),
]) {
  var flag = false;
  var needRetry = false;
  return () async {
    if (flag) {
      needRetry = true;
      return;
    }
    flag = true;
    await func();
    Timer(delay, () async {
      while (needRetry) {
        needRetry = false;
        await func();
        await Future.delayed(delay);
      }
      flag = false;
    });
  };
}
