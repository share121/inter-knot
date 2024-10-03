extension Flat<T> on Iterable<Iterable<T>> {
  Iterable<T> get flat sync* {
    for (final e in this) {
      yield* e;
    }
  }
}
