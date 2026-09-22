<p align="center">
  <img src="https://raw.githubusercontent.com/rutikeyone/cobalt/main/assets/screenshots/tree.png" width="30%" alt="The live scope tree">
  <img src="https://raw.githubusercontent.com/rutikeyone/cobalt/main/assets/screenshots/log.png" width="30%" alt="Everything the graph reported">
</p>

# cobalt_inspector

The live scope tree, what [Cobalt](https://pub.dev/packages/cobalt) built and with what lifetime, and
everything the graph reported — on a screen inside your app, with nothing attached from outside.

```yaml
dev_dependencies:
  cobalt_inspector: ^0.1.0
```

## Wiring

The log has to be installed when the graph is built. Observers are fixed when a scope is
constructed and handed down to its children, so an inspector cannot start listening to a graph that
is already running:

```dart
final log = CobaltInspectorLog();

final scope = await CobaltApplication.start(
  root: const AppScope(),
  observers: [log],
);
```

Then push the screen from wherever your debug menu lives:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => CobaltInspectorScreen(log: log)),
);
```

It reads the scope above it and climbs to the root, so it shows the whole graph wherever it opens.

## Three views, and why they read different things

**Tree** walks the live scopes. It is not rebuilt from events, because an event carries an
`CobaltScopeRef` — a name, a depth and a parent name — and two same-named siblings are
indistinguishable there, as are a scope that was disposed and one pushed later under the same name.
Good enough to label a log row, not to identify a node.

Each scope lists what it registers with its lifetime, read through `debugKindOf`, and separately
what it inherits, with the scope that owns it. That owner is the fact that decides what an override
actually affects: a factory runs on the scope that owns *its* registration, not the one you asked
from.

**Built** comes from creation events, and has to. A scope's registrations are what was *declared* —
a lazy singleton nobody resolved looks there exactly like one that is built — so only an event
proves an object exists.

**Log** is everything, filterable by event kind.

## Two things it will not do

**It never builds anything to show you.** Resolving a registration creates it for real: the object
starts existing, the scope takes ownership, and a creation event appears. An inspector that resolved
rows in order to display them would change the graph it is there to observe. Tapping a row shows
facts; building is a separate action that says what it costs.

**An eager singleton never appears under Built.** It is constructed by whoever called
`registerSingleton` and handed over already made, so the scope has nothing to report constructing.
It appears in the tree, with its lifetime, and never in the built list.

## The notification is deferred, on purpose

Observer callbacks are synchronous and arrive in the middle of the work they describe — including a
teardown running while the widget tree builds, where notifying immediately throws
`setState() called during build`. `CobaltInspectorLog` defers to the next turn, and drops a
notification that comes due after it has been disposed.

## Dressing it in your own colours

The inspector derives its palette from the host application's `Theme`, so dropped into an app it
already matches — light, dark, whatever seed. Where the derived answer is not the one you want,
name the colours:

```dart
CobaltInspectorTheme(
  data: CobaltInspectorThemeData.of(Theme.of(context)).copyWith(
    accent: brand.primary,
    failure: brand.danger,
  ),
  child: child,
)
```

Put it once above wherever a debug menu opens from and pushed routes and sheets inherit it; or pass
`theme:` to a screen to override it there. Nothing is required: with neither, the ambient theme
decides.

Colour is by **family**, not by event: thirteen kinds is more than anyone can hold, and level says
how loud an event is rather than what it concerns. The four — scope, startup, instance, failure —
are the same division `cobalt_talker` files its logs under, which is what lets
[`cobalt_talker_flutter`](https://pub.dev/packages/cobalt_talker_flutter) dress talker's screen in the
same palette.

Three things are drawn from a base colour rather than named directly, and each has an override map
beside it. A lifetime badge takes the colour of what retains it, so six lifetimes share three
colours; a severity takes `failure`, `warning` or `muted`; a family takes an icon. Where that
reading is not yours, name the entries you care about — the map is read per entry, so the rest keep
deriving:

```dart
CobaltInspectorThemeData.of(Theme.of(context)).copyWith(
  lifetimeColors: {CobaltRegistrationKind.singleton: brand.gold},
  levelColors: {CobaltLogLevel.trace: brand.faint},
  familyIcons: {CobaltInspectorFamily.startup: Icons.bolt},
)
```

Four opacities decide how strongly a coloured chip reads: `tintAlpha` for a badge or family mark,
`selectedTintAlpha` and `idleTintAlpha` for a filter, `borderAlpha` for the outline. They are
settings rather than constants because the same value carries much further on a dark host than on a
light one.

## Speaking your users' language

The chrome is translated into English, Russian and Chinese, and picks the language the host app is
already in. Nothing is required for that — with no delegate installed, the inspector reads the
ambient `Localizations.localeOf` and falls back to English for a language it has no translation
for. It is a screen you drop in to look at a graph, and asking for a `localizationsDelegates` edit
before it renders at all would be the wrong trade.

Installing the delegate is still the documented path, and the one to take when the app's language
is chosen rather than inherited:

```dart
MaterialApp(
  localizationsDelegates: const [
    CobaltInspectorL10n.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: CobaltInspectorL10n.supportedLocales,
)
```

To add a language, drop an `.arb` beside `l10n/inspector_en.arb` and run `flutter gen-l10n`.

**The typeface is the host's too, and that one can go wrong quietly.** The inspector sets its text
in whatever the ambient `Theme` provides, which is right — it should look like the app it is inside.
But a font is only obliged to have the glyphs it has: a display face chosen for a Latin product
often has no Cyrillic and never has CJK, and Flutter then fills those in from the platform. The
result is not a crash or a missing-glyph box, it is a change of typeface partway through a line —
mid-word where a scope name sits inside a translated sentence. Nothing in a test suite can see it,
because widget tests draw in a test font. If you localize an app into a script your display face
does not cover, choose a face per language; the gallery in this repository does exactly that, and
[its README](https://github.com/rutikeyone/cobalt/blob/main/examples/gallery/README.md) says how.

**What stays in English, deliberately.** Lifetimes (`lazySingleton`, `asyncSingleton`) and levels
(`trace`, `warning`) are Cobalt's own identifiers — translating them would break the one thing the
screen is for, which is finding the line of code a row came from. Scope names and registration keys
are your code's, and the framework does not rename it. And the **records themselves** are written
by `cobalt`, which is pure Dart with no localization in it at all: `scope "app/session" pushed` is
the same sentence in every language. The inspector translates its own chrome and nothing that
belongs to somebody else.

## What the screens do

**Tree** walks the live scopes, with a search over registrations and one control that folds every
node. Reading it builds nothing: a lazy singleton nobody asked for is still unbuilt after you have
looked at it.

**Built** comes from creation events, grouped by scope, by lifetime, or not at all.

**Log** is the event stream, newest first, searchable, filtered by family, each row carrying its
time and the gap since the one before. Tapping opens the record whole — error, stack and the
structured map — with a button that copies it. The pause control in the app bar holds the view
still without dropping anything: records keep arriving and appear when you let go.
