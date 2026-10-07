# Contributing

How the repository is laid out, how to check a change before it goes to CI, and what CI checks.
Releasing is in [RELEASING.md](RELEASING.md).

## Checking a change

```
./tool/get.sh
dart analyze --fatal-infos .
dart format --output=none --set-exit-if-changed .
python3 tool/modifiers.py --check
./tool/test.sh
(cd examples/hello && dart run build_runner build)
(cd examples/codegen_basics && dart run build_runner build)
(cd examples/notes_app && dart run build_runner build)
(cd compat/external_consumer && dart run build_runner build)
./tool/coverage.sh
```

All of it on Flutter 3.38.9. `tool/get.sh` resolves the root and every member that `tool/members.sh`
finds by its pubspec; after adding a package, or a dependency on a sibling, `python3
tool/overrides.py` rewrites the overrides, and CI fails while they are stale. `benchmark/` is a
member like the rest: its test, run by `tool/test.sh`, checks that every scenario runs and that both
containers do what the row says; the numbers under **Performance** in
[docs/OVERVIEW.md](docs/OVERVIEW.md#performance) come from its `bin/main.dart`, compiled AOT.

`tool/coverage.sh` measures line coverage of the publishable packages that have tests, prints them
worst-first, and fails under a floor on the **total** — 85%. The current figure is what the script
prints and is not repeated here: a number that moves with every commit goes stale in prose and
nothing checks it, which it has already done twice. The floor is on the total rather than per package
deliberately: coverage is measured per package while the code is shared, so `cobalt_analyzer`'s
parsers are driven far more from `cobalt_generator`'s tests and from `compat/external_consumer` than
from their own suite. A per-package floor would demand tests written where they do not belong.
Override it with `COVERAGE_FLOOR=90 ./tool/coverage.sh`.

CI's `verify` job (`.github/workflows/ci.yml`) runs all of the above on Flutter 3.38.9, plus a `git
diff --exit-code` after regenerating both examples **and `compat/external_consumer`**, so stale
generated code fails the build. The `forward` job repeats resolution, analysis, tests and the
generated-code diff on `stable` and `beta`. The generator formats its own output at a fixed language
version, so that diff does not depend on which SDK ran it.

## Layout

One public type per file. The sealed `CobaltRegistration` hierarchy is the deliberate
exception: a sealed hierarchy must live in one library, so its subclasses are `part` files rather
than separate libraries. `compat/external_consumer` is outside that rule of thumb entirely — it is a
package that takes its siblings through `dependency_overrides` in its own pubspec and stays out of
`tool/overrides.py`, so it resolves the way a third-party project would. It exists to keep the code-generation
pipeline honest from outside the repository.

## Known publish warning

`cobalt_lint` reports "the name of lib/main.dart should match the name of
the package". That entry point is fixed by the analysis server plugin API — the server generates code
that imports `package:cobalt_lint/main.dart` and reads its `plugin` variable. `riverpod_lint` carries
the same warning.
