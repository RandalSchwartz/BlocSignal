# Migrating from Riverpod

This reference covers migrations from `riverpod`, `flutter_riverpod`, `hooks_riverpod`, and
generated `@riverpod` or `@Riverpod` declarations. The BlocSignal notes match `bloc_signals` 0.1.10,
`bloc_signals_flutter` 0.1.6, and Signals 7.1.0. Inspect the consumer project's resolved Riverpod
version, generated output, and installed source before changing it.

Riverpod provider declarations are often top-level, but their state and lifetime belong to a
`ProviderContainer` or `ProviderScope`. Do not treat the migration as replacing global singletons
with inherited widgets. First map the actual scope, dependency graph, cache, and disposal rules.

## Inventory the feature

Search handwritten and generated code:

```bash
rg -n \
  "package:(riverpod|flutter_riverpod|hooks_riverpod|riverpod_annotation)/|@(riverpod|Riverpod)|ProviderScope|ProviderContainer|ProviderObserver|Consumer|WidgetRef|Ref\b|(Provider|StateProvider|StateNotifierProvider|ChangeNotifierProvider|NotifierProvider|FutureProvider|StreamProvider|AsyncNotifierProvider)\b|ref\.[A-Za-z_][A-Za-z0-9_]*|\.family\b|\.autoDispose\b|AsyncValue|overrideWith|select\(|retry\s*:" \
  lib test
```

Record these contracts before editing:

- manual or generated providers, plus whether generated providers use `keepAlive`;
- initialization and dependency-driven recomputation in `build` or provider callbacks;
- family keys, cache retention, auto-disposal, and request cancellation;
- `AsyncValue` loading, data, error, refresh, reload, and retry behavior;
- scoped overrides, test overrides, observers, and provider invalidation;
- widget rebuild selection and the initial-callback behavior of listeners.

A mechanical migration is unsafe when any of those behaviors matter.

## Capability map

| Riverpod surface | Possible replacement | Boundary to preserve |
| --- | --- | --- |
| `Provider<T>` for a service | Constructor injection or the project's existing DI | A `computed` signal is for derived reactive data, not general service lookup. |
| `Provider<T>` for derived data | Owned `computed<T>` | Dispose it with its owner and preserve equality behavior. |
| `StateProvider<T>` | Owned `Signal<T>` for local reactive data, or a BlocSignal command | Preserve who may mutate the value and who owns its lifetime. |
| `StateNotifierProvider` | `BlocSignal<void, State>` only after mapping its commands and listeners | Preserve every mutation entry point, listener contract, and initialization rule. |
| `ChangeNotifierProvider` | Keep it behind DI or perform a tested rewrite | ChangeNotifier has no direct BlocSignal equivalent. Account for its mutable object identity and notification timing. |
| `NotifierProvider` | `BlocSignal<void, State>` with public methods, or an event-based bloc | Initialization no longer comes from `build()`. |
| `AsyncNotifierProvider` | Event-based `BlocSignal` with sealed async states | BlocSignal has no automatic `AsyncValue`, retry, invalidation, or cancellation. |
| `FutureProvider` | Owned `FutureSignal<T>` or an event-based bloc | Choose based on whether the feature needs commands, observation, or only read-only async data. |
| `StreamProvider` | Owned `StreamSignal<T>` or a project-owned subscription | BlocSignal itself has no state stream. |
| `.family` or generated parameters | Parameterized `BlocSignalProvider` or an owned `SignalContainer` | Signals auto-disposal can approximate last-subscriber eviction when configured, but it is not Riverpod scope or cache behavior. |
| `ConsumerWidget` or `Consumer` | A normal widget with `BlocSignalBuilder` or `SignalBuilder` | Put the builder at the old rebuild boundary. |
| Widget `ref.watch(provider)` | `BlocSignalBuilder` for bloc state, or `.value` inside `SignalBuilder` | `context.watch<Bloc>()` watches provider instance replacement only. |
| Provider or Notifier `ref.watch(provider)` | Constructor dependency plus an explicit recomputation trigger, or an owned signal dependency | There is no `BuildContext` inside a bloc. |
| Widget `ref.read(provider)` | `context.read<Bloc>()` for lookup and commands, or `signal.peek()` inside a reactive callback | Reading and rebuilding are separate choices. |
| Provider or Notifier `ref.read(provider)` | Read the injected dependency directly | Constructor injection replaces service lookup, not dependency recomputation. |
| `ref.listen` | Lifecycle-owned subscription or `effect` | Signals reactions run once when created; preserve Riverpod's initial-callback policy. |
| `select` | Owned `computed` or a narrow builder | The selected value needs meaningful equality. |
| `ProviderScope` overrides | Constructor injection, `BlocSignalProvider.value`, or a test-owned instance | BlocSignal has no general provider override registry. |
| `ProviderObserver` | `BlocSignalObserver` for BlocSignal activity, plus separate instrumentation where needed | Riverpod reports provider and container lifecycle plus value events. BlocSignal reports only its own events, transitions, and errors through one global observer slot. Raw Signal activity is separate. |

Raw signal APIs, including `FutureSignal`, require a direct `signals` dependency. `SignalBuilder`
and other Flutter signal widgets require a direct `signals_flutter` dependency. BlocSignal
packages do not re-export these APIs.

## Rebuilds and commands

Do not translate this Riverpod read:

```dart
final state = ref.watch(todoProvider);
```

to `context.watch<TodoBloc>().stateValue`. The latter rebuilds only when the provided bloc instance
changes. Use a state-aware builder:

```dart
BlocSignalProvider<TodoBloc>(
  create: (_) => TodoBloc(repository: repository),
  child: BlocSignalBuilder<TodoBloc, TodoState>(
    builder: (context, state) => TodoView(state: state),
  ),
)
```

Use `context.read<TodoBloc>()` for a button or callback that sends a command. Keep the builder small
when the Riverpod code used `Consumer`, `select`, or a row-level family to limit rebuilds.

BlocSignal has no `BlocSignalListener`. A replacement for `ref.listen` needs an explicit owner,
subscription disposal, mounted checks, and the same previous/next predicate. Signals subscriptions
and effects run once when created, so suppress the first callback when the Riverpod listener did
not fire immediately. Never create the reaction in `build`.

`signals_flutter` 7.1.0 also exports `SignalEffect` and its `SignalListener` alias. The widget owns
and disposes its effect, but it runs immediately on mount, provides no previous/current pair, and
recreates the effect when the callback identity changes. Use it only when those semantics are made
equivalent to the old listener.

## Async initialization and commands

Riverpod can run a provider or `AsyncNotifier.build`, track watched dependencies, expose
`AsyncValue`, discard obsolete results, and retry initialization failures. BlocSignal does none of
that automatically.

Choose and test each replacement explicitly:

- Decide who sends the initial load event. Do not hide an unawaited initialization change in a
  constructor without preserving current timing.
- Model loading, data, and error as immutable states when using BlocSignal.
- Remember that `add` returns `void`; tests and callers cannot await event completion.
- Cancel the real operation when the repository supports cancellation.
- Otherwise use a request revision or identity guard so an older completion cannot publish stale
  state.
- After every async gap, check both request freshness and `isClosed` before `emit` or another side
  effect.
- Recreate retry, refresh, and dependency-triggered reload behavior after checking both explicit
  configuration and the target Riverpod version's defaults.

Retry can be implicit. The inspected Riverpod 3.2.1 source retries provider initialization failures
up to 10 times, starting at 200 ms and doubling to a 6.4 second cap; it skips `ProviderException`
and `Error`. Riverpod 2 and custom container or provider retry policies differ. Inspect the target
before removing behavior that does not appear in the application source.

An owned `FutureSignal` can fit a read-only request. It exposes Signals `AsyncState`, refresh, and
reload behavior, but it is not a drop-in `FutureProvider`: it does not reproduce Riverpod scopes,
overrides, or the consumer project's exact listener-driven disposal and retry policy. It can ignore
a superseded Future's result while alive, but it does not cancel that Future. Test disposal during
an in-flight request against the installed Signals version and use repository cancellation when
the operation must stop.

## Families and cache ownership

For a bloc whose lifetime matches one widget subtree, pass the family argument to the bloc and let
`BlocSignalProvider(create:)` own it:

```dart
BlocSignalProvider<UserBloc>(
  key: ValueKey(userId),
  create: (_) => UserBloc(userId: userId, repository: repository),
  child: const UserView(),
)
```

For read-only asynchronous data shared by key, Signals 7.1.0 provides the correctly typed helper:

```dart
final users = futureSignalContainer<User, String>(
  (userId) => futureSignal(
    () => repository.fetchUser(userId),
    options: const AsyncSignalOptions<User>(autoDispose: true),
  ),
  cache: true,
);
```

With `autoDispose: true`, the contained signal can dispose after its last reactive subscriber leaves
and the container removes that key. This differs from Riverpod: auto-disposal is off by default,
disposal is permanent for that signal instance, a later lookup creates another instance, and an
entry that never gains a reactive subscriber will not self-dispose.

The cache still has an application-defined owner. Call `users.dispose()` from that owner. For
manual eviction, use `users.remove(userId)?.dispose()`; in the inspected Signals source, `remove`
and `clear` do not themselves dispose evicted signals. `cache: true` alone is not equivalent to
Riverpod `autoDispose`. Family keys still need stable `==` and `hashCode`.

Do not introduce a custom bloc registry merely to imitate `.family` until its owner, eviction,
concurrency, and test reset behavior are explicit.

## Scope, ownership, and overrides

Riverpod's disposal defaults differ by declaration style: generated providers normally dispose
when unused, while manual providers normally retain state unless configured otherwise. Verify the
target instead of assuming one policy.

`BlocSignalProvider(create:)` closes its bloc only when that provider leaves the widget tree.
`BlocSignalProvider.value` never closes the supplied bloc. The BlocSignal provider layer has no
listener-count lifecycle, `keepAlive`, `invalidate`, or scoped dependency graph. Separate Signals
types do have reactive dependencies; `FutureSignal` and `StreamSignal` expose reset, refresh, and
reload operations, while `StreamSignal` can pause and resume. Those are signal operations, not
Riverpod provider lifecycle equivalents.

`BlocSignal.close()` disposes only the internal model created by its base constructor. A subclass
that owns a `computed`, `effect`, subscription, `FutureSignal`, `StreamSignal`, timer, cancellation
token, or `SignalContainer` must override `close`, dispose those resources, then call
`super.close()`. External subscribers to `bloc.state` remain the subscriber's responsibility.

Translate `ProviderScope` overrides into ordinary dependency injection. Pass repositories and
services to the bloc constructor, provide a test-owned bloc with `.value`, and keep each resource's
creator responsible for disposal. Preserve nested Riverpod scopes only when the replacement has an
equivalent subtree boundary.

## Testing the migration

Before changing code, keep focused tests for:

- initial provider evaluation and dependency-driven recomputation;
- loading, retained data, errors, refresh, and retry;
- overlapping requests and cancellation on disposal;
- family key reuse, eviction, and auto-disposal;
- `select` rebuild boundaries and listener predicates;
- scoped and test overrides.

For BlocSignal tests, instantiate the bloc with fakes and register `close` with `addTearDown`.
Assert synchronous handlers directly through `stateValue`. Control async dependencies with test
`Completer`s or subscriptions, as described in [testing.md](testing.md), rather than delays.

Prefer fresh signals and constructor-injected fakes over Signals `overrideWith`; the signal and
computed override methods are deprecated and are not scoped like `ProviderScope`. Reset the global
`BlocSignalObserver.observer` after tests that replace it, and dispose test-owned subscriptions and
containers.

Widget tests should prove that `BlocSignalBuilder` rebuilds for state, provider-created blocs close
when removed, `.value` blocs remain externally owned, and side-effect subscriptions stop after
disposal.

## Ordered migration

1. Freeze focused tests for the Riverpod behavior listed above.
2. Convert one provider family or feature slice at a time.
3. Introduce explicit constructor dependencies before removing provider overrides.
4. Replace the state owner, then its widget rebuilds, listeners, and tests.
5. Recreate only the cache, cancellation, retry, and invalidation behavior the feature needs.
6. Search imports, annotations, generated parts, provider names, and test overrides again.
7. Remove Riverpod dependencies and generated files only when no consumers remain.
8. Format, regenerate when required by the remaining code, analyze, and run the feature tests.

Stop at an unsupported boundary instead of hiding it behind a global cache, timer, or unowned
reaction.
