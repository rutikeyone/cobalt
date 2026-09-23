# cobalt_generator example

A `dev_dependency` — it never ships in an application.

```yaml
dev_dependencies:
  cobalt_generator: ^0.2.0
  build_runner: ^2.15.0
```

```bash
dart run build_runner build
```

All three builders are `auto_apply: dependents`, so declaring the dependency is
the whole setup. From this:

```dart
@cobaltInject
class Repository {
  Repository(this.database);
  final Database database;
}
```

it writes `lib/cobalt.g.dart` with a named const factory class — never a
closure — and a `$CobaltRootScope` whose registrations are ordered by a
compile-time topological sort:

```dart
final class _RepositoryFactory implements CobaltFactory<Repository> {
  const _RepositoryFactory();

  @override
  Repository create(CobaltResolver resolver) => Repository(resolver.get<Database>());
}
```

Start it with the generated `$startCobalt()`, or hand the pieces to
`CobaltAppScope`. A dependency cycle fails the build naming the cycle instead of
emitting code that would deadlock.

Full setup:
[`examples/codegen_basics`](https://github.com/rutikeyone/cobalt/tree/main/examples/codegen_basics).
