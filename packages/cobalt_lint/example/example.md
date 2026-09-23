# cobalt_lint example

An analyzer plugin. Add it to `analysis_options.yaml` at the root of the
package or workspace:

```yaml
plugins:
  cobalt_lint: ^0.2.0
```

Then `dart analyze` and the IDE report Cobalt mistakes where you make them,
instead of when `build_runner` runs:

```dart
@cobaltInject
abstract class Broken {}
// warning: Cobalt cannot construct 'Broken': it is abstract.
//          — cobalt_injectable_must_be_constructible

@cobaltInject
class Controller {
  @injected
  Repository repository;
  // warning: Controller.repository must be declared "late final" to receive
  //          property injection. — cobalt_injected_field_must_be_late_final
}

@CobaltInit()
class Telemetry {}
// warning: Telemetry is annotated with @CobaltInit but declares no
//          'Future<void> init()' method. — cobalt_init_requires_init_method
```

Twelve rules ship; all read annotations through `cobalt_analyzer`, the same
layer the generator uses.

Note that `plugins` only works at the root of a package or workspace, and that
the analysis server resolves plugins from pub.dev rather than from your
pubspec — see the README if you need to point it at local sources.
