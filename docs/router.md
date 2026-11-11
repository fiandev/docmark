# Router

How navigation works: one route enum, one derived gate, and a pure redirect
policy that is unit-tested. The router reads a single provider and enforces
its decision; nothing else navigates in response to app-state changes.

## The one rule

Pages never push routes in response to startup, onboarding, or App Lock
changes. They change the underlying state and invalidate the matching status
provider; the gate does the navigation.

| After | Invalidate | The gate then |
|---|---|---|
| Onboarding completed | `onboardingStatusProvider` | Redirects to home or lock |
| App Lock enabled / unlocked | `appLockStatusProvider` (via the service change stream) | Redirects to home or lock |
| App Lock disabled / PIN reset | `appLockStatusProvider` | Redirects to home |

Pushing a route imperatively in these situations races the gate: the gate may
redirect the push away, or the push may land on a route the gate immediately
bounces. Ordinary in-app navigation (a detail screen, a form step) still uses
`context.pushNamed(Routes.x.name)`; the gate does not interfere with routes
the current gate allows.

## The gate

`routerStateProvider` derives one destination from three inputs, in priority
order:

1. **Startup pending or failed** → `Routes.splash`. The splash route hosts the
   startup widget, so a failed startup shows its retry UI.
2. **Onboarding not completed** → `Routes.onboarding`.
3. **App Lock** → `Routes.lock` when locked, `Routes.home` when disabled or
   unlocked. The status starts locked before storage answers, so a cold start
   cannot skip the gate.

New gating inputs (a force-update screen, a maintenance mode) compose here,
as another early return in `routerState`; the router itself never changes.

`RedirectGate.redirect(path, gate)` turns that destination into a redirect
decision:

| Gate | Pinned to | Allowed | Everything else |
|---|---|---|---|
| `splash` | `/splash` | — | → `/splash` |
| `onboarding` | `/onboarding` | — | → `/onboarding` |
| `lock` | `/lock` | — | → `/lock` |
| `home` | — | all app routes | gate-only routes and `/` → `/home` |

The function is pure — no `Ref`, no `BuildContext` — and idempotent: it never
returns the path already being visited, which is what prevents redirect
loops. A path no gate handles and no route matches lands on `NotFoundScreen`
via the router's `errorBuilder`.

## Adding a route

1. Add a member to the `Routes` enum in
   `presentation/core/router/routes.dart`. Top-level routes carry an absolute
   path (leading `/`); sub-routes carry a relative segment and nest under
   their parent.
2. Register it in the matching `parts/<feature>_routes.dart` file:

```dart
GoRoute(
  path: Routes.newFeature.path,
  name: Routes.newFeature.name,
  pageBuilder: (context, state) =>
      const MaterialPage(child: NewFeaturePage()),
),
```

3. Decide how the gate treats it. A route in the normal app area needs no
   change — the `home` gate allows it. A route that must be reachable while
   onboarding or locked must be added to `RedirectGate` and covered by a
   test.

Route paths and names exist only on the enum. Never declare a path string
anywhere else; `GoRoute.path`, `GoRoute.name`, and every navigation call read
the same member, so the two cannot drift.

## Testing

`test/presentation/core/router/` holds the patterns:

- `redirect_gate_test.dart` — the policy matrix: what each gate pins, allows,
  and redirects, including idempotency. Pure function in, expectation out; no
  widgets, no router.
- `router_state_test.dart` — the derivation: override the startup, onboarding,
  and App Lock providers in a `ProviderContainer` and assert the resulting
  gate. The container disables provider auto-retry to match the app's root
  scope, so failures settle instead of silently retrying.
