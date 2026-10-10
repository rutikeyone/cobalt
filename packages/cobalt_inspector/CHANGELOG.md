## 1.4.0

- The Built tab shows each build's own time, without the builds it waited
  on, with the whole time beside it; slowest first and the slow mark use
  the own time. A registration's sheet adds it after the last build time.
  Requires `cobalt` 1.4.0.

## 1.3.0

- No code changes in this package. Republished in lockstep with 1.3.0:
  `cobalt_generator` supports `@injected` fields on generic classes, and
  `cobalt_lint` checks the instantiations of a generic class.

## 1.2.0

- Reads the graph through `registrationOf` and `hooks` instead of the
  deprecated `debug*` members; the screens show the same. Requires
  `cobalt_flutter` 1.2.0, and with it `cobalt` 1.2.0.
- The README opens with how to install it, hand the log to the graph and
  open the screen.

## 1.1.1

- No code changes in this package. Republished in lockstep with 1.1.1:
  a shorter README with a Quick start, `examples/hello` as the smallest
  app, `docs/OVERVIEW.md` for everything the README no longer holds, and
  `docs/TROUBLESHOOTING.md`, one entry per error.

## 1.1.0

- Korean: the inspector is translated into Korean as well, so it speaks English,
  Russian, Chinese and Korean, chosen from the host app's locale. Each tab
  is checked at phone width in Korean too.
- The tree keeps every scope's counts at the right edge again. Since 1.0.0 a
  short scope name left a gap after them, most visibly on a nested scope.

## 1.0.0

- The API is stable: from here on, only a major release breaks it — see
  Compatibility in the README.
- A registration's sheet says the class it builds when that is not the
  key's own type and its factory says — `Builds: LiveApiClient` behind
  `ApiClient`; generated factories always say. In three languages.
- Fits a phone in every language. On the Built tab the grouping switch
  scrolls sideways, as the log's filters do — in Russian it ran past the
  edge — and in the scope tree a long scope name or count line ends in an
  ellipsis instead of overflowing. Each tab is checked at phone width in
  English, Russian and Chinese.

## 0.9.0

- The scope tree lists the hooks a scope adds under its name —
  `hooks: JoinRegistry on Loggable` — in all three languages.

## 0.8.0

- No code changes in this package. Republished in lockstep with 0.8.0, which
  adds hooks on a supertype, makes every Cobalt error `final` (breaking) and
  stops a log observer from formatting the records it drops — see `cobalt`'s
  changelog.

## 0.7.0

- `CobaltInspectorScreen(initialTab:)` and `CobaltInspectorTab` (`tree`,
  `built`, `log`): open the inspector straight on a tab — the log, say, from
  a debug-menu entry that is about what happened.
- Its own classification of registration kinds — what can be built from the
  tree, what is torn down with the scope, the lifetime colour — asks
  `CobaltRegistrationKind`'s getters. No behaviour change.
- `CreatedView`'s documentation no longer claims an eager singleton never
  appears: only a value handed over already made does.

## 0.6.0

- Build times. The Built tab shows how long each build took and marks one of
  at least `CobaltInspectorThemeData.slowBuild` — 16 ms, one 60 Hz frame, by
  default — in the warning colour; a new grouping sorts slowest first; a
  registration's sheet shows how long its last build took. `ScopeTreeView`
  takes the log for that, and `CobaltInspectorScreen` passes it.

## 0.5.0

- An async transient is shown as not torn down, in the instance colour.

## 0.4.0

- An async parameterized registration is shown as not retained and not
  buildable from the sheet, like a parameterized one.

## 0.3.0

- The tree marks a registration an override replaced and one a decorator
  wraps, and the registration sheet names both: that an override stands in,
  and the decorators, innermost first. Reading them builds nothing.

## 0.2.1

- No code changes in this package. Republished in lockstep with the toolchain
  packages, which now accept analyzer 13 and 14 — see `cobalt_generator`'s
  changelog.

## 0.2.0

- Lazy async registrations get the `startup` colour, count as retained in the
  detail sheet, and "build it" builds them through `getAsync`.
- A registration skipped for an override is logged in the `scope` family.

## 0.1.2

- No code changes in this package. Republished in lockstep with a
  packaging fix in `cobalt` 0.1.2 (a stray file removed from its
  archive) — see its changelog. A fix in one package still ships as a
  patch for all fifteen, because publishing a subset is what lets the
  set drift.

## 0.1.1

- No code changes in this package. Republished in lockstep with the fix
  in `cobalt_lint` 0.1.1 — see its changelog. Lockstep is the whole
  versioning policy: a fix in one package still ships as a patch for all
  fifteen, because publishing a subset is what lets the set drift.

## 0.1.0

- The palette answers for everything the screens draw. Three things that used to
  derive from a base colour with no way round it now take an override map read
  per entry, so naming one leaves the rest deriving: `lifetimeColors`,
  `levelColors`, `familyIcons`. The four chip opacities — `tintAlpha`,
  `selectedTintAlpha`, `idleTintAlpha`, `borderAlpha` — are settings rather than
  numbers written into four files, because the same value reads much weaker on a
  light host than on a dark one.
- `warning` is a colour of its own rather than the startup green it borrowed, and
  the severity of a record is now painted with it in the detail sheet. Until now
  `colorOfLevel` had no caller at all: a public method that decided nothing.
- English, Russian and Chinese, chosen from the host app's locale. Installing
  `CobaltInspectorL10n.delegate` is the documented path; with no delegate the
  ambient locale still decides, and English is the floor. Lifetimes, levels and
  the records themselves stay in Cobalt's own words. The typeface comes from the
  host as well, which is worth knowing: a display face with no glyphs for the
  language changes typeface mid-line rather than failing, and no test can see
  it.
- `CobaltInspectorThemeData` and `CobaltInspectorTheme`: the screens take their
  colours from the host application, and an app can name its own.
- The log carries the time each record arrived, is searchable, filters by
  family, opens a record whole and copies it, and can be paused.
- The tree searches registrations and folds every node at once; the built list
  groups by scope or by lifetime.
- Initial release.
- `CobaltInspectorScreen` — three views over a running graph: the live scope
  tree, what was built, and the event log.
- The tree walks live scopes rather than replaying events, because
  `CobaltScopeRef` cannot tell two same-named siblings apart. Each registration
  shows its lifetime from `debugKindOf`, and an inherited one names the scope
  that owns it.
- Nothing is resolved in order to display it: building an instance is a
  separate action that states it changes the graph.
- `CobaltInspectorLog` records what the graph reports and notifies on the next
  turn, since observer callbacks arrive mid-frame. It must be passed where the
  graph is built — observers are fixed at construction.
