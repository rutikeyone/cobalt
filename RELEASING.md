# Releasing

Fifteen packages depend on each other, so the order is not a preference — a package
cannot be published until everything it depends on is already on pub.dev, or
version solving fails.

## Order

```
1. cobalt_annotations          (depends on nothing of ours)
2. cobalt                      (cobalt_annotations)
3. cobalt_analyzer             (cobalt, cobalt_annotations)
   cobalt_flutter              (cobalt)
   cobalt_logger               (cobalt)
   cobalt_logging              (cobalt)
   cobalt_talker               (cobalt)
   cobalt_test                 (cobalt)
   cobalt_bloc                 (cobalt)
4. cobalt_generator            (cobalt_analyzer, cobalt_annotations)
   cobalt_lint                 (cobalt_analyzer)
   cobalt_go_router            (cobalt_flutter)
   cobalt_inspector            (cobalt_flutter)
   cobalt_test_flutter         (cobalt_flutter)
5. cobalt_talker_flutter       (cobalt_inspector, cobalt_talker)
```

Steps within a numbered group are independent of each other. Between groups,
wait for the previous group to appear on pub.dev — the index is not instant.

## Before the first publish

- [ ] Working copy is under git and clean. Without it `pub publish` ignores
      `.gitignore` and puts `build/` — tens of megabytes — into the archive.
- [ ] `dart pub publish --dry-run` in every package. Expect **0 warnings**
      everywhere except `cobalt_lint`, which reports one for `lib/main.dart`;
      that name is required by the plugin API and `riverpod_lint` carries the
      same warning.
- [ ] Archives are kilobytes, not megabytes. Anything larger means the previous
      two boxes are not really ticked.
- [ ] `repository:` and `issue_tracker:` point at a repository that actually
      exists and has the code pushed. They are currently
      `github.com/rutikeyone/cobalt`.
- [ ] CI is green on that repository.
- [ ] Translations updated. `README.ru.md`, `README.zh-CN.md`, the four
      translated guides, `MIGRATION.ru.md` and `MIGRATION.zh-CN.md` track the
      English originals; a test checks that all four sets exist and link to each
      other, and CI checks they are not empty, but nothing checks that they still
      say the same thing — so this box is the only thing that does. English is
      authoritative: if a translation is stale, fix it or say so in it.
- [ ] Code in both guides still compiles against the API it describes. It is the
      document a new reader copies from, and the two defects this repository has
      already shipped in prose — `CobaltInspectorScreen` without its required
      `scope:`, `CobaltLoggerSink` called positionally — were both in example
      snippets, which no compiler reads. Check the API of anything you changed
      this release.
- [x] After publishing, drop the `dependency_overrides` from the plugin
      config — but do **not** move `plugins:` into `analysis_options.yaml`
      itself. `cobalt_lint` is enabled from `analysis_options.plugin.yaml`,
      copied over by hand, and that split is permanent, not a scaffold for
      being unpublished. Before publication the analysis server's synthetic
      `plugin_entrypoint` package could not resolve our own path dependencies
      at all; that part is fixed by publishing. What publishing does **not**
      fix is that `plugin_entrypoint` also resolves `analysis_server_plugin`
      at a version the *SDK* chooses, and `analysis_server_plugin` pins the
      analyzer it depends on exactly. `cobalt_lint` deliberately caps
      `analyzer` below 13.0.0 to keep working on Flutter 3.38.9 (see "Flutter
      and Dart versions" below), and an SDK whose bundled
      `analysis_server_plugin` needs an analyzer at or above that — which the
      beta channel already does — makes `dart analyze` crash **before a
      single file is read**, everywhere in the repository, gating the build on
      something that has nothing to do with the code. This was tried once,
      broke CI on beta the same day, and was reverted. Both
      `analysis_options.plugin.yaml` files now carry the plain
      `plugins: cobalt_lint: ^0.2.0` a real consumer would write — publication
      only shortened their content, it did not remove the file.
- [ ] **Shipped strings** translated too, which is a different job from the
      documents above: `packages/cobalt_inspector/l10n/*.arb` and the examples'
      — `gallery`, `notes_app`, `flow_scopes`, `graph_events` and
      `codegen_basics` each carry their own. A test in each package fails when a key is
      missing from a translation, so a *gap* cannot slip through — but a key
      whose English changed while the translations kept the old wording passes
      every check there is. Re-read the diff of `*_en.arb`, then
      `flutter gen-l10n` and commit the output; CI regenerates and fails on any
      difference.

## Versioning

Lockstep: every package carries the same version. A DI framework whose runtime
and generator drift apart produces generation errors nobody can decipher, so the
constraint between them (`^0.1.0`) is deliberately tight.

Lockstep is the whole policy, including the awkward cases:

- **A breaking change anywhere majors everything.** `cobalt_talker` gets a new
  major even if not one line of it changed. The cost is a meaningless version
  bump; the alternative cost is a user resolving `cobalt 2.x` against
  `cobalt_talker 1.x` and reading a generator error that names neither.
- **A fix in one package still ships as a patch for all fifteen.** Publishing a
  subset is what lets the set drift.
- **The dependency constraint between our own packages stays exact-major**
  (`^X.Y.0`), never `>=X <Z`. Widening it is the same trap in slower motion.

Before 1.0, `0.x` majors mean `0.x` — a breaking change bumps the minor, so
`^0.1.0` already refuses `0.2.0`. That is the behaviour we want; it just looks
different from what the rule above describes.

A test enforces the mechanical half of this: every package declares the same
version, and every changelog heads with the version its own pubspec declares.
Bumping a release is fifteen identical edits, and the one you miss is not
visible in a diff you are scrolling past.

## Flutter and Dart versions

One floor: Dart `^3.10.0` for all fifteen, and Flutter `>=3.38.0` for the five
that need Flutter. The compatibility stand and every example say the same.

It was two floors until 2026-09-04, and what collapsed it is worth keeping,
because the binding constraint is not the one the pubspec names.

**`meta` decides, not the SDK.** Flutter 3.38 pins `meta 1.17.0`; analyzer
10.0.2 wants `^1.18.0`. So a Flutter application on 3.38 cannot resolve an
analyzer newer than 10.0.1 no matter what its SDK constraint says, and no
matter what ours says. A pure-Dart consumer is not bound by that and takes
12.1.0. 13.0.0 is out of reach for both: it needs `_fe_analyzer_shared 100`,
which needs Dart 3.11.

**And every package that reads the analyzer pins it exactly** —
`analysis_server_plugin`, `analyzer_plugin`, `analyzer_testing`, `dart_style`
all do. So the constraint does not permit a span, it selects a row:

| where | analyzer | analyzer_plugin | analysis_server_plugin | analyzer_testing | dart_style |
|---|---|---|---|---|---|
| Flutter 3.38 | 10.0.1 | 0.14.1 | 0.3.7 | 0.1.9 | 3.1.7 |
| newer, until something else needs analyzer 13 | 12.1.0 | 0.14.8 | 0.3.14 | 0.2.5 | 3.1.8 |
| Flutter 3.49's `test`, `build` 4.0.8+, current `freezed` | 13.x – 14.x | 0.14.9 – 0.14.17 | 0.3.15 – 0.3.23 | 0.2.6 – 0.4.2 | 3.1.9 – 3.1.13 |

The three toolchain packages therefore declare `analyzer: ">=10.0.1 <15.0.0"`,
and `cobalt_generator` declares `dart_style: ">=3.1.7 <3.2.0"`. The range was
capped below 13 for one release, 0.2.0, and that cap was the mistake this table
exists to prevent repeating: Flutter 3.49's `flutter_test` pins `test_api
0.7.14`, the `test` releases that accept it require analyzer 13, and the
workspace stopped resolving on beta. A new analyzer major is admitted by a
patch release of all fifteen once the matrix below passes on it.

Things that were measured rather than assumed:

- **Every row emits identical bytes for generated code.** The generator formats
  at a fixed language version, 3.10, not at `DartFormatter.latestLanguageVersion`,
  which moves with each `dart_style` release and gates its style changes. On
  3.1.7, 3.1.8 and 3.1.13 the output was already identical, because their
  latest language versions agree; the fixed version is what keeps the next
  formatter release from changing that. The floor job regenerates on 3.38.9 and
  diffs against what is committed on the two older rows — the stand for 12.1.0,
  and `codegen_basics`, a Flutter package held to `meta 1.17.0`, for 10.0.1 —
  and the `beta` job diffs the same files on the newest. Only `*.g.dart` is
  compared: `flutter gen-l10n` formats its output with the `dart_style` the
  *package* resolves, and differs by a blank line between rows, which is
  Flutter's generator disagreeing with itself.
- **Only `cobalt_lint` ever touched an analyzer-version-specific API**, in
  `registration_index.dart`. Analyzer 13 removed `NamedExpression`,
  `DefaultFormalParameter` and `NormalFormalParameter`, and changed
  `ArgumentList.arguments` from `Expression` to `Argument`, so no source that
  names them compiles on both sides. The index reads what both sides share
  instead — `childEntities`, tokens and `FormalParameter.metadata`. The rule
  API is identical across the range, `cobalt_analyzer` reads only the element
  model, and `cobalt_generator` does not import the analyzer at all.

To check a new analyzer before admitting it, copy the three toolchain packages
out of the workspace, set their `analyzer` constraint to that exact version,
and run `dart analyze` and `dart test` in each: the constraint, not
`dependency_overrides`, has to choose the version, or pub keeps whatever
`analysis_server_plugin` and `dart_style` the old analyzer had and the result
says nothing.

`tool/floor_check.sh` proves the floor. It copies each member out of the
workspace — keeping the repository layout, so a package whose analysis options
reach the root still find them — and resolves it alone, because a workspace is
one resolution and this one cannot exist on 3.38: `flutter_test` there pins
`test_api 0.7.7`, capping the `test` runner at 1.26.3 and `analyzer` below 9.
Consumers never meet that; we do, because our analyzer packages and the test
runner share a resolution. Both floor rows of the analyzer range are exercised —
`codegen_basics` is a Flutter package with the generator, so it lands on
10.0.1, while the pure-Dart members land on 12.1.0. Members declaring a floor
above the running SDK are skipped, named, and not counted as passing.

CI runs it pinned to Flutter 3.38.9 alongside `stable` and `beta`, so an
upcoming Flutter change is found before release and the old floor cannot rot
unnoticed.

Raising a floor later is a breaking change; lowering one is not. That asymmetry
is why this was settled before the first publish rather than after.

## After publishing

**Tag the commit the archives were built from**, and do it before anything else
lands on `main`:

```bash
git tag -a v0.1.0 -m 'Cobalt 0.1.0'
git push origin v0.1.0
```

Without it nothing in git says which source is on pub.dev. An archive carries
no commit, so a bug reported against a published version can only be traced by
guessing at dates — and the version itself cannot help, because lockstep means
fifteen packages share one number and the repository has one history for all
of them. The tag is the only join between them.

One tag for the release, not fifteen: they are published together and carry the
same version, so a tag each would say the same thing fifteen times and go stale
the first time one of them is republished on its own.

**A tag can be moved right up until the first `publish`, and not one commit
after.** Before that it points at a candidate nobody can have; after it, it is
the only claim about which source a downloaded archive was built from, and
moving it makes that claim quietly false for everyone who already has the
package. If the tagged commit turns out to be the wrong one after publishing,
the answer is another version, not another tag.

A GitHub release on that tag is optional and costs nothing — its body is the
release's own CHANGELOG entry, which is written already.

`cobalt_lint` becomes installable the normal way — just the `plugins:` entry.
Until then the analysis server cannot find it, because it resolves plugins from
pub.dev rather than from the consumer's pubspec, which is why
`compat/external_consumer/analysis_options.yaml` names local paths. Drop that
block once the packages are live, and the stand starts proving the real
installation path too.

## What `pana` can and cannot tell you before the first publish

`pana` resolves against pub.dev and strips `dependency_overrides`, so it scores a package only once
everything it depends on is published. Before the first release that means exactly one package can
be measured — `cobalt_annotations`, whose only dependency is `meta` — and each later one becomes
measurable as the one below it lands. Run it as you go rather than saving it for the end:

```bash
dart pub global activate pana
(cd packages/cobalt_annotations && dart pub global run pana --no-warning .)
```

Measured 2026-09-01: `cobalt_annotations` scores **160/160**, with all six platforms detected and
`is:wasm-ready`, without declaring a `platforms:` key. Two things follow, and both save work:
declaring platforms by hand buys nothing here and can only contradict what the analysis finds; and
the documentation criterion is *20% or more* of the public API, not all of it, so chasing complete
dartdoc coverage is a matter of taste rather than of score.

## Lower bounds

`pana` also checks that a package resolves and analyses at the bottom of its own constraints.
That one is runnable locally against the whole workspace:

```bash
flutter pub downgrade && dart analyze --fatal-infos .
flutter pub upgrade
```

Measured 2026-09-01: clean, with 92 packages moved — including `bloc` at its floor of 9.0.0, which
`cobalt_bloc` is the only thing to constrain and which nothing had resolved before.

Restore with `pub upgrade`, never `pub get`: `get` honours the existing lockfile and leaves
`frontend_server_client` downgraded, and that version invokes a `frontend_server.dart.snapshot` Dart
3.13 no longer ships. The symptom is not an error — `dart analyze` stays green while every test file
silently fails to load.

That same downgraded package is why the test *runner* cannot run at the lower bounds at all. It is a
transitive dev dependency nothing here declares, invisible to consumers, who never run these tests —
so `dart analyze` is the whole of the check, and it is also the whole of what `pana` scores.

## `cobalt` dev-depends on `cobalt_test`

Its own tests use the helpers, which looks like a cycle and is not: dev dependencies are not
transitive, so nothing a consumer resolves is affected, and `pub publish --dry-run` is clean. The
publication order below is unchanged — `cobalt` goes out before `cobalt_test`, and the dev dependency
plays no part in that.
