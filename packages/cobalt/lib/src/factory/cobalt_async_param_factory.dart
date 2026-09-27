import 'package:cobalt/src/lifecycle/cobalt_resolver.dart';

/// Builds a [T] asynchronously from a runtime argument the container cannot
/// supply.
///
/// The async counterpart of `CobaltParamFactory`: for an object whose
/// construction awaits something and depends on a value from the call site —
/// a document loaded by id, a session opened for one account. Resolve it
/// through `getAsyncWithParam`; every call builds a new instance, and the scope
/// never retains it.
abstract interface class CobaltAsyncParamFactory<
  T extends Object,
  P extends Object
> {
  /// Builds a new [T] from [param], resolving the rest from [resolver].
  Future<T> create(CobaltResolver resolver, P param);
}
