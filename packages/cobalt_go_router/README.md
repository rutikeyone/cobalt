# cobalt_go_router

go_router bindings for [Cobalt](https://github.com/rutikeyone/cobalt). A scope whose lifetime is a
navigation flow: created when the flow opens, disposed when it closes.

```dart
CobaltShellRoute(
  name: 'checkout',
  identity: (state) => state.pathParameters['orderId'],
  scope: (state) => CheckoutScope(state.pathParameters['orderId']!),
  routes: [
    GoRoute(path: '/orders/:orderId/summary', builder: (_, _) => const SummaryScreen()),
    GoRoute(path: '/orders/:orderId/payment', builder: (_, _) => const PaymentScreen()),
  ],
)
```

It is an ordinary `ShellRoute` subclass, so it drops into a route table wherever a `RouteBase`
goes. Being a class, a flow can also be given a name of its own and reused:

```dart
class CheckoutFlowRoute extends CobaltShellRoute {
  CheckoutFlowRoute()
    : super(name: 'checkout', scope: ..., routes: [...]);
}

GoRouter(routes: [HomeRoute(), CheckoutFlowRoute()]);
```

There is also `cobaltShellRoute(...)`, a function that builds the same object, for route tables
written that way. The class is the documented spelling — it reads alongside `GoRoute` and
`ShellRoute`, and it is the one that can be subclassed.

Inside the flow nothing new applies: `context.cobalt<T>()` resolves from the nearest scope, so the
flow shadows the root for exactly as long as it is open. No screen has to remember to clear
anything, and no repository grows a `reset()`.

## Naming

Each type is named after the go_router type it extends, so a route table reads in one register:

| This package | extends |
|---|---|
| `CobaltShellRoute` | `ShellRoute` |
| `CobaltStatefulShellRoute` | `StatefulShellRoute` (including `.indexedStack`) |
| `CobaltStatefulShellBranch` | `StatefulShellBranch` |

`CobaltRouteScope` is the odd one out because it extends nothing — it is the widget that actually
owns the scope, and the route types above use it internally.

"Flow" stays a word for the *concept*, not for a type: the types say what they are, the docs say
what they are for. Naming your own `CheckoutFlowRoute extends CobaltShellRoute` is exactly right.

## Why there is no router listener

`CobaltShellRoute` is an ordinary `ShellRoute`, and the scope is owned by a widget inside it. That is
enough because of how go_router keys a shell's page:

```dart
pageKey: ValueKey<String>(route.hashCode.toString())   // go_router, match.dart
```

The key is the identity of the route object, so the Navigator reuses the same `Route` — and
the whole subtree — for every navigation *within* the flow, and destroys it the frame the flow
leaves the match list. The widget tree already knows the flow's lifetime; nothing has to watch the
router and mirror it. That mirroring is exactly where hand-rolled solutions break on the back
button, on deep links and on tab switches.

One consequence worth stating: construct the flow route **once**, with the rest of the route table.
A fresh `CobaltShellRoute` instance is a different flow as far as go_router is concerned, so rebuilding
the routes list on every frame would tear the scope down every frame.

## Tabs — `StatefulShellRoute`

Two levels are available, and they compose:

```dart
CobaltStatefulShellRoute.indexedStack(
  name: 'workspace',                       // one scope for the whole shell
  scope: (_) => const WorkspaceScope(),
  shell: (_, _, navigationShell) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: navigationShell.goBranch,
      destinations: [...],
    ),
  ),
  branches: [
    CobaltStatefulShellBranch(                  // and one scope per tab
      name: 'feed',
      scope: (_) => const FeedScope(),
      routes: [GoRoute(path: '/feed', builder: (_, _) => const FeedScreen())],
    ),
    CobaltStatefulShellBranch(
      name: 'profile',
      scope: (_) => const ProfileScope(),
      routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
    ),
  ],
)
```

That gives three levels: the root, the shell's `workspace`, and `feed` / `profile` under it. Either
piece works alone — a plain `StatefulShellRoute` with `CobaltStatefulShellBranch` branches, or an
`CobaltStatefulShellRoute` with plain branches.

**A branch is kept alive, not kept visible.** This is the one thing to internalise. go_router
preserves branch navigators off-screen (`IndexedStack` plus `AutomaticKeepAliveClientMixin`), so a
branch scope is built the first time that tab is visited — or immediately, with `preload: true` —
and lives until the shell itself closes. Switching away disposes nothing. That is the whole point
of a stateful shell: the tab keeps its state, and its dependencies are part of that state.

If something must die when a tab is deselected, it does not belong to the tab. Give it a flow of
its own *inside* the tab, where leaving the flow is a real navigation. This package deliberately
offers no "dispose on deselect" switch: implementing it would mean watching `currentIndex` and
disposing imperatively, which is a second owner for a lifetime the widget tree already governs —
the thing this package exists to avoid.

### A branch's default route cannot be parameterized

go_router asserts it:

```
The default location of a StatefulShellBranch cannot be a parameterized route
'defaultGoRoute!.pathParameters.isEmpty'
```

So `CobaltStatefulShellRoute` with an `identity` read from a path parameter — `/workspace/:id` with tabs
under it — does not work unless every branch declares an explicit, literal `initialLocation`. This
is go_router's constraint, not ours, and it is worth knowing before designing routes around it.

## Identity

The router cannot decide one thing: whether `/orders/1` and `/orders/2` are the same flow. They
match the same `ShellRoute`, so by default the scope is reused. `identity` says otherwise — when
its value changes the scope is torn down and rebuilt:

```dart
identity: (state) => state.pathParameters['orderId'],
```

Leave it out when the flow has a single instance. The scope is named after the flow, with the
identity appended (`checkout:42`), so a scope tree stays readable.

## Replacing what a flow registers

Every flow-owning type — `CobaltShellRoute`, `CobaltStatefulShellRoute`, `CobaltStatefulShellBranch`
— takes `overrides`, built from the route state like `scope` is, and `CobaltRouteScope` takes the
same thing without a state:

```dart
CobaltShellRoute(
  name: 'checkout',
  scope: (state) => CheckoutScope(state.pathParameters['orderId']!),
  overrides: (state) => [CobaltOverride<PaymentGateway>.value(FakeGateway())],
  routes: [...],
)
```

It is called each time the flow's scope is created — on entry, and again when `identity` changes —
so a value handed over with `CobaltOverride.value` is never one the previous run already closed. It
replaces what the flow registers; a key the root owns is overridden on the root.

## What to expect

- **A frame of `loading` on every rebuild.** `CobaltScopeWidget` publishes its scope only after
  `init()` finishes, even for a fully synchronous graph. Changing `identity` therefore flashes
  whatever you pass as `loading`.
- **Teardown of the outgoing scope is not awaited.** On an identity change the old and new scopes
  are both children of the parent for a moment. Harmless for plain objects; visible if the flow
  holds a socket or a subscription.
- **Nested flows cost a frame each.** A flow inside a flow publishes its scope one frame after its
  parent does.
- **Registrations are built during the widget build phase.** `CobaltScopeBuilder.build` runs inside
  `didChangeDependencies`, so a dependency whose constructor has a side effect that notifies
  listeners will trigger `setState() called during build`. Keep construction inert, or defer the
  notification (a `scheduleMicrotask` is enough).
- **A scope cannot be reparented.** If the root scope is replaced, the subtree has to be rebuilt
  rather than left pointing at the old root. `CobaltAppScope` handles this — it keys the provider it
  publishes by the scope — so this only needs doing by hand if you own the root without it.

## A flow whose screens share no path

A `ShellRoute` has no `path` of its own, so its children keep the absolute URLs they declare. A
flow of top-level routes — `/cart`, `/checkout`, `/payment` — is one `CobaltShellRoute` with those
three as children, and no URL changes:

```dart
CobaltShellRoute(
  name: 'checkout',
  scope: (_) => const CheckoutScope(),
  routes: [
    GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
    GoRoute(path: '/checkout', builder: (_, _) => const CheckoutScreen()),
    GoRoute(path: '/payment', builder: (_, _) => const PaymentScreen()),
  ],
)
```

Moving between the three keeps the scope, leaving for any other route disposes it, and a deep link
straight to `/payment` raises it — `test/top_level_flow_test.dart` pins all three.

What is still not covered, and why:

- **A route shared by two flows.** A route lives in exactly one shell, so it belongs to one flow. A
  screen reachable from both checkout and returns has to live outside both and read what it needs
  from the root.
- **A flow whose boundary is decided at run time** — "the user is in the flow until they confirm",
  whatever the URL says. The route table cannot express that. Own the scope by hand the way
  `examples/notes_app` owns its session scope.
- **The shell's own navigator.** A shell pushes its children onto a nested `Navigator`. A screen
  that must cover the whole app, or be popped past the shell, sets `parentNavigatorKey` to the root
  navigator's key — and then it is outside the flow's scope.

A router listener that owns the scope outside the widget tree is still ruled out: it reconciles two
sources of truth about one lifetime, which is the bug class `get_it` ships `dropScope` for.

## `onExit` is not used

go_router's `onExit` is a veto hook (`FutureOr<bool>`), and it is skipped entirely when the
navigator has no context. It answers "may we leave?", not "we left" — the wrong shape for teardown.
