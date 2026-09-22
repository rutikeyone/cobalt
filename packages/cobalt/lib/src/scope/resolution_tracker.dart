import 'dart:async';

import 'package:cobalt/src/graph/cobalt_cycle_error.dart';
import 'package:cobalt/src/key/cobalt_key.dart';

/// Tracks what is being built, so a resolution that comes back round on itself
/// fails naming the path instead of recursing until the stack overflows.
///
/// One tracker serves a whole scope tree, because a cycle can run through a
/// parent as easily as through one scope.
///
/// During a parallel init level this holds several branches at once rather than
/// a single call chain: `Future.wait` enters every registration in the level
/// before any of them suspends. That does not weaken the check. A cycle forms
/// in a synchronous chain of resolves, and two async branches cannot resolve
/// each other synchronously — an async singleton that is not ready yet throws
/// `CobaltNotReadyError` without ever reaching this class.
final class CobaltResolutionTracker {
  final _stack = <CobaltKey>[];
  final _chain = <CobaltKey>[];

  /// What is under construction right now, outermost first.
  ///
  /// Several branches at once during a parallel init level, so this answers
  /// "what is being built", never "what asked for what". For the second
  /// question use [chain].
  List<CobaltKey> get pending => List.unmodifiable(_stack);

  /// The synchronous chain of factories currently on the Dart stack.
  ///
  /// Only [guard] adds to this, which is what makes it a chain rather than a
  /// set: synchronous calls nest strictly, so the last entry really did ask
  /// for the next thing resolved. [guardAsync] deliberately stays out — an
  /// awaited build shares the stack with its siblings, and presenting those as
  /// a chain would name a caller that never called.
  ///
  /// The cost of that is a shorter chain, never a wrong one: a resolve inside
  /// an async factory shows the sync calls below it and stops there.
  List<CobaltKey> get chain => List.unmodifiable(_chain);

  void enter(CobaltKey key) {
    final index = _stack.indexOf(key);
    if (index >= 0) {
      throw CobaltCycleError([
        for (final entry in _stack.skip(index)) entry.toString(),
        key.toString(),
      ]);
    }
    _stack.add(key);
  }

  /// Removes [key] wherever it sits, not only from the top.
  ///
  /// Assuming the top is a mistake once a level runs in parallel: the branch
  /// that finishes first is usually not the one entered last, and a top-only
  /// removal would leave its key behind forever. [enter] rejects duplicates,
  /// so there is at most one entry to remove.
  void exit(CobaltKey key) => _stack.remove(key);

  T guard<T>(CobaltKey key, T Function() build) {
    enter(key);
    _chain.add(key);
    try {
      return build();
    } finally {
      _chain.removeLast();
      exit(key);
    }
  }

  Future<T> guardAsync<T>(CobaltKey key, Future<T> Function() build) async {
    enter(key);
    try {
      return await build();
    } finally {
      exit(key);
    }
  }

  static final _lazyChainKey = Object();

  /// The lazy async builds that led to the code running now, outermost first.
  ///
  /// Carried in the [Zone] rather than in this tracker, because it has to
  /// survive `await`: each lazy build runs its factory in a zone that extends
  /// its caller's chain, so the chain belongs to one call and not to the tree.
  /// That is the difference that matters. A key another caller is building is
  /// something to wait for; a key in *this* chain is a cycle, and waiting for
  /// it would never end.
  static List<CobaltKey> get lazyChain =>
      (Zone.current[_lazyChainKey] as List<CobaltKey>?) ?? const [];

  /// Runs [build] as the lazy build of [key], extending [lazyChain].
  ///
  /// Throws [CobaltCycleError] instead when [key] is already in the chain.
  static Future<T> guardLazy<T>(CobaltKey key, Future<T> Function() build) {
    final chain = lazyChain;
    final index = chain.indexOf(key);
    if (index >= 0) {
      return Future.error(
        CobaltCycleError([
          for (final entry in chain.skip(index)) entry.toString(),
          key.toString(),
        ]),
      );
    }
    return runZoned(
      build,
      zoneValues: {
        _lazyChainKey: List<CobaltKey>.unmodifiable([...chain, key]),
      },
    );
  }

  static final _phaseOneKey = Object();

  /// The scope whose `init()` is running the code running now, if any.
  static Object? get phaseOneOwner => Zone.current[_phaseOneKey];

  /// Runs [build] as part of [owner]'s phase 1.
  static Future<T> inPhaseOne<T>(Object owner, Future<T> Function() build) =>
      runZoned(build, zoneValues: {_phaseOneKey: owner});
}
