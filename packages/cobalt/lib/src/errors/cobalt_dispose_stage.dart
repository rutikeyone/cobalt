/// Which part of teardown a failure came from.
enum CobaltDisposeStage {
  /// Waiting for an `init()` that was still running when [CobaltScope.dispose]
  /// was called.
  ///
  /// A failure here is the initialization failing, not teardown failing.
  /// Teardown still runs afterwards, because a half-built scope has more to
  /// release than a fully built one, not less.
  awaitingInit,

  /// Waiting for a lazy async registration that was still being built when
  /// [CobaltScope.dispose] was called.
  ///
  /// Like [awaitingInit], a failure here is the build failing, and it already
  /// reached whoever awaited `getAsync`. Waiting is what keeps a build that
  /// finishes during teardown from escaping it.
  awaitingLazyBuild,

  /// Releasing a child scope or an instance this scope owned.
  releasing,
}
