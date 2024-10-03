extension Use<V> on V? {
  T? use<T>(T Function(V value) fn) => this == null ? null : fn(this as V);
}
