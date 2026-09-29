# cobalt_talker

[talker](https://pub.dev/packages/talker) adapter for
[Cobalt](https://github.com/rutikeyone/cobalt). The DI graph reports itself as typed talker logs.

```dart
final talker = Talker();

final scope = await CobaltApplication.start(
  root: const AppScope(),
  observers: [CobaltTalkerObserver(talker)],
);
```

## Why an observer and not a sink

The other adapters in this family implement `CobaltLogSink` — they receive a formatted string. This
one implements `CobaltObserver` directly, because that is what talker is for: each kind of event
becomes its own `TalkerLog` with a title and a colour, and `TalkerScreen` can then filter them
apart.

| Title | What lands there |
|---|---|
| `cobalt-scope` | a scope was pushed, is disposing, or is gone |
| `cobalt-startup` | bootstrap steps and async initialization |
| `cobalt-instance` | an instance was built, with how long it took, or released — off unless `verbose` |
| `cobalt-failure` | init failed, teardown could not release something, a bootstrap step broke |

## `verbose` is off on purpose

Per-instance logs are the loudest thing Cobalt can emit: a real graph builds a great many, and the
signal you actually opened the log for — scopes appearing, startup finishing, things failing —
drowns in them. Turn them on when you are chasing one specific object:

```dart
CobaltTalkerObserver(talker, verbose: true)
```

## What it costs

An observer is called synchronously, in the middle of the work it describes. `Talker` does its own
formatting on that thread, so a graph that builds thousands of objects with `verbose: true` will
notice. With `verbose: false` the volume is proportional to the number of scopes, not instances.

An exception thrown from inside an observer is swallowed by Cobalt — watching cannot break what it
watches — so a misconfigured talker will go quiet rather than take the app down with it.
