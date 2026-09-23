# flow_scopes

An Cobalt example built around one idea: a scope whose lifetime is a navigation flow, wired with
[go_router](https://pub.dev/packages/go_router) through `cobalt_go_router`.

> **Not a runnable app.** This package is a library the gallery mounts — it has no `main.dart`
> and no native project of its own. Run it, and everything else, from one place:
>
> ```bash
> cd examples/gallery && flutter run
> ```

```
flutter pub get
```

Manual Mode — there is no code generation here, because the subject is navigation, not the
generator. See `examples/codegen_basics` and `examples/notes_app` for that.

## What to try

| Step | What it proves |
|---|---|
| Open order 1 | a scope named `order:1` appears under the root |
| Continue to payment | same flow, so the draft instance is unchanged |
| Switch to order 2 | the identity changed, so order 1's draft is disposed and a new one built |
| Leave the flow | the scope and everything in it are gone |
| Cart → checkout → payment | three top-level routes, `/cart`, `/checkout`, `/payment`, share one draft |
| Workspace (tabs) | a shell scope plus a scope per tab — three levels |
| Switch tabs | a scope appears for the new tab and **nothing is disposed** |
| Leave the workspace | all three go at once |
| Scope tree (app bar) | the live hierarchy, read from `CobaltScope.children` |

The event log on the home screen survives all of it — it lives in the root scope, which is why a
flow can write to it and the entry outlives the flow.

## The whole integration

The flow is a route type of its own — `lib/features/orders/order_flow_route.dart`:

```dart
class OrderFlowRoute extends CobaltShellRoute {
  OrderFlowRoute()
    : super(
        name: 'order',
        identity: _orderId,
        scope: (state) => OrderFlowScope(_orderId(state)),
        shell: (_, _, child) => OrderFlowChrome(child: child),
        routes: [...],
      );
}
```

so the route table just names it:

```dart
GoRouter(routes: [homeRoute, scopeTreeRoute, OrderFlowRoute()]);
```

A flow does not need a path of its own. `lib/features/cart/checkout_flow_route.dart` puts three
top-level routes under one shell — a `ShellRoute` has no `path`, so `/cart`, `/checkout` and
`/payment` keep their URLs and still share one `CartDraft`:

```dart
class CheckoutFlowRoute extends CobaltShellRoute {
  CheckoutFlowRoute()
    : super(
        name: 'cart',
        scope: (_) => const CartFlowScope(),
        routes: [
          for (final step in CartStep.values)
            GoRoute(path: step.path, builder: (_, _) => CartStepScreen(step: step)),
        ],
      );
}
```

Nothing inside the flow knows it is scoped. `OrderSummaryScreen` calls `context.cobalt<OrderDraft>()`
exactly like any other screen resolves anything.

## Layout

```
lib/
  main.dart
  app/                    app_scope.dart, app_router.dart, app_routes.dart, flow_scopes_app.dart
  core/                   event_log.dart — root-scoped, outlives every flow
  features/
    home/ui/              the hub and the event log
    orders/               order_flow_route.dart, order_flow_scope.dart, domain/, ui/
    workspace/            workspace_shell_route.dart, workspace_scope.dart, domain/, ui/
    diagnostics/ui/       the live scope tree
```
