# gallery

Every Cobalt example in one app, organised by capability rather than by project.

```bash
flutter run
```

Sixteen entries in six sections. Each one that has a UI opens with a graph **of its own** — built
when you open it, disposed when you leave — so opening two gives you two unrelated scope trees.
That is the thing the gallery is really demonstrating, which is why there is no container above the
entries.

Three entries have no UI at all (`Teardown`, `Manual mode`, `Testing patterns`): they show their
console output instead of a button. A gallery that offered to "open" a command-line program would
be lying about what happens next.

## Three languages

English, Russian and Chinese, switched from the chips at the top of the hub. Every string the
gallery owns — the catalog's titles, one-liners and bullet points, the section headings, the
chrome — comes from `l10n/gallery_*.arb`; `buildCatalog` takes a `GalleryL10n` and holds no prose
of its own, which is what a test checks by building the catalog twice and insisting the two
disagree.

The screens come from four other packages, and each of those owns its own strings: `notes_app`,
`flow_scopes`, `graph_events` and `codegen_basics` each carry `l10n/*.arb` and generate their own
`NotesL10n`, `FlowScopesL10n`, `GraphEventsL10n` and `CodegenBasicsL10n`. The gallery collects
their delegates beside its own and the inspector's, which is what a multi-package Flutter app looks
like: the strings belong to the package that shows them, and the app registers the delegates. A
test reads `GalleryApp` — not the test harness — and fails if one is missing.

`CobaltInspectorL10n.delegate` would work without being registered, since that package falls back to
the ambient locale; it is listed anyway, so the gallery shows the documented path rather than the
one you get for free.

### The domain reports facts, the screen names them

Two places had prose below the widgets, where there is no `BuildContext` and so no way to know the
reader's language: `flow_scopes` recorded `'draft 1 created'` into a log the home screen renders,
and `notes_app`'s `ApiClient` described itself as `'FakeApiClient → no network'`. Both now report
what happened — a `FlowEvent(kind, subject)`, an `implementation` and an `endpoint` — and the screen
turns it into a sentence. That is the only shape that localizes a layer resolved from a graph, and
it made both tests better: they compare values now instead of prose.

`codegen_basics` has the same split in miniature. `Greeting.render(phrase)` still decides whether to
shout, which is what `loud` was for; the words come from the screen.

### The face follows the language

Space Grotesk, which the gallery is drawn in, has no Cyrillic — Google Fonts ships it as latin,
latin-ext and vietnamese. Set a Russian screen in it and only the Latin words are Space Grotesk
while everything around them falls back to whatever the platform has, so «Bootstrap-шаги» changes
typeface in the middle of the word and does it differently on iOS than on Android. A face that
cannot write the language is the wrong face for that language, so Russian is set in Manrope: the
same modern semi-geometric grotesque, with Cyrillic that was designed rather than substituted.

`GalleryFace.of(locale)` decides, `GalleryText.of(context)` hands out the scale, and the theme is
rebuilt in `MaterialApp.builder` — below `Localizations`, which is the first place there is a
language to ask about. Chinese needs no entry: no webfont worth downloading carries CJK, the
platform's own face is what every Chinese interface is set in, and Latin beside it is the ordinary
mixed-script pairing rather than an accident. The mono styles never move — JetBrains Mono covers
Cyrillic, and what they set is code.

A test mounts the hub in both languages and fails if any style still names Space Grotesk under
Russian, because a missed call site shows up as a typeface change mid-sentence rather than as a
crash.

A second test opens every entry under Russian and fails if any `Text` still renders a string that
appears verbatim in an English `.arb`. A call site that never learned about the language shows up
as a sentence in the wrong one, not as a crash, so it needs looking for.

What is **not** translated: `manual_mode` and `teardown`. They have no screens — their whole point
is that the runtime works without Flutter — and localizing console output would drag `intl` into
two pure-Dart packages for nobody's benefit. Neither are the identifiers on screen: bootstrap step
names, scope names, registration keys, lifetimes and formatter labels are how you find the code
that produced a line, and translating them would break the one thing they are for.

## Where the screens come from

The gallery owns its design, its catalog and the three small graphs no other example has. The rest
of the screens are mounted from the example packages next door:

| Package | Supplies |
|---|---|
| `notes_app` | seven entries across Startup, Injection and Scopes |
| `flow_scopes` | Navigation flows |
| `graph_events` | Graph events |
| `codegen_basics` | Generated container |
| `gallery` itself | Lazy async · Decorators · In-app inspector, each in `lib/catalog/` |

Those stay separate packages for a reason that is not tidiness: `cobalt_container` aggregates a
whole package into a single `$CobaltRootScope`, and two `@CobaltScopeRoot` classes in one package is
a generation error. Merged, `notes_app` and `codegen_basics` would share one graph — which is
exactly what a gallery of independent examples must not do.

## The icons

One family, drawn as nodes and edges on a 24px grid — the same primitives the framework is about.
They are a `CustomPainter` rather than an SVG dependency, because circles and lines are all they
ever were; dashes are cut from the path by hand, since Flutter's `Paint` has none.
