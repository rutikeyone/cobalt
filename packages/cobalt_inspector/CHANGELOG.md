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
