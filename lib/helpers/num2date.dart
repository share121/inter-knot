extension Num2DateTime on num {
  DateTime get msSinceEpoch =>
      DateTime.fromMicrosecondsSinceEpoch((this * 1000).toInt());
}
