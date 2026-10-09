# graph_events

A Cobalt example about one thing: watching the graph report itself, through
[talker](https://pub.dev/packages/talker).

> **Not a runnable app.** This package is a library the gallery mounts — it has no `main.dart`
> and no native project of its own. Run it, and everything else, from one place:
>
> ```bash
> cd examples/gallery && flutter run
> ```

```
flutter pub get
```

## What to try

| Step | What appears in the log |
|---|---|
| launch | `bootstrap "warm-up" started/done`, then `scope "app" ready in …ms` |
| Open a session scope | `scope "app/session" pushed`, an init level, the instances it built |
| Close the session | `scope "app/session" disposing`, each release, then `disposed` |
| Open one that will not close | same, until teardown — then an `cobalt-failure` entry naming `StubbornResource.dispose` |
| The log button (app bar) | `TalkerScreen`, where the four titles can be filtered apart |

The last row is the point. A teardown that cannot release something used to be visible only as a
thrown `CobaltDisposeError` that somebody had to catch and print; now it is a log line with the
failing label, the original error and its stack trace.

## The whole integration

```dart
final talker = Talker();

await CobaltApplication.start(
  root: const AppScope(),
  bootstrap: [WarmUp()],
  observers: [CobaltTalkerObserver(talker, verbose: true)],
);
```

`verbose: true` here because the example is small and per-instance lines are the interesting part.
In a real app leave it off — see the `cobalt_talker` README.

## Layout

```
lib/
  main.dart
  app/                  app_scope.dart (graph + startup), logging_app.dart
  core/                 telemetry.dart — an async service and one that refuses to close
  features/
    home/ui/            the buttons that drive the graph
    session/            the child scope they open and close
```
