import 'package:cobalt_annotations/src/cobalt_lifetime.dart';
import 'package:meta/meta_meta.dart';

/// Registers the annotated class in the generated container.
///
/// The class needs a public generative constructor; every parameter is
/// resolved from the scope, and [Named] selects a named registration.
///
/// ```dart
/// @cobaltInject
/// class Repository {
///   Repository(this.database);
///   final Database database;
/// }
/// ```
@Target({TargetKind.classType, TargetKind.method, TargetKind.getter})
class CobaltInject {
  /// Creates an annotation describing how the registration behaves.
  const CobaltInject({
    this.lifetime = CobaltLifetime.lazySingleton,
    this.name,
    this.exposeAs,
    this.dispose,
    this.lazyInit = false,
    this.instantiations = const <Type>[],
  });

  /// How long the instance lives. Defaults to [CobaltLifetime.lazySingleton].
  final CobaltLifetime lifetime;

  /// Distinguishes this registration from others of the same type.
  ///
  /// Consumers ask for it with `@Named('...')` or `get<T>(name: '...')`.
  final String? name;

  /// Registers the class under this type instead of its own.
  ///
  /// Use it to publish an interface and keep the implementation unreachable:
  /// `@CobaltInject(exposeAs: NoteStore)` on `NoteRepository` means
  /// `get<NoteStore>()` works and `get<NoteRepository>()` does not.
  final Type? exposeAs;

  /// Closes the instance at teardown, for a type that cannot say how itself.
  ///
  /// Point it at a top-level or static function taking the registered type:
  /// `@CobaltInject(dispose: closeClient)`. It works on a class and on an
  /// [CobaltModule] member alike — it used to be read only for members, and a
  /// class naming one registered without it and was never closed.
  ///
  /// Prefer implementing `Disposable` or `AsyncDisposable` where you can: that
  /// keeps the knowledge on the object rather than at every registration of
  /// it. Reach for this when you cannot — a type from another package, or one
  /// whose closing method belongs to a base class you do not control.
  ///
  /// A transient and a parameterized registration are never retained by the
  /// scope, so it could never call this — pairing them is a build error.
  final Function? dispose;

  /// On a [CobaltModule] member returning a `Future`, builds it on the first
  /// `getAsync` instead of during `scope.init()` — the module form of
  /// `@CobaltInit(lazy: true)`. On anything else it is a build error.
  final bool lazyInit;

  /// The instantiations of a generic class to register, one registration
  /// each.
  ///
  /// A class with type parameters has no single type to register, so it names
  /// the ones it wants. This registers `Cache<Note>` and `Cache<Tag>`, and the
  /// constructor of each receives its own `Store<Note>` or `Store<Tag>`:
  ///
  /// ```dart
  /// @CobaltInject(instantiations: [Cache<Note>, Cache<Tag>])
  /// class Cache<T> {
  ///   Cache(this.store);
  ///   final Store<T> store;
  /// }
  /// ```
  ///
  /// [name], [lifetime], [dispose] and the environment apply to every one of
  /// them. Each entry has to be the annotated class with every type argument
  /// spelled out; a raw `Cache` reads as `Cache<dynamic>` and is a build
  /// error, as is listing the same instantiation twice, combining it with
  /// [exposeAs], or giving the class an `@injected` field.
  ///
  /// Leave it empty on a class without type parameters.
  final List<Type> instantiations;
}

/// Registers the class as a lazy singleton — one instance per scope, built on
/// first use.
const cobaltInject = CobaltInject();

/// Registers the class as an eager singleton, built while the container is
/// assembled.
const cobaltSingleton = CobaltInject(lifetime: CobaltLifetime.singleton);

/// Registers the class as a transient — a fresh instance per resolution, not
/// retained by the scope.
const cobaltTransient = CobaltInject(lifetime: CobaltLifetime.transient);
