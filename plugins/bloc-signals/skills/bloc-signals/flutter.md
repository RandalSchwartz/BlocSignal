# Flutter bindings and ownership

This reference matches `bloc_signals_flutter` 0.1.9. Inspect the installed package when the version
differs.

## Provider ownership

Use the constructor that matches ownership:

| Form | Creates the bloc | Closes the bloc on dispose |
| --- | ---: | ---: |
| `BlocSignalProvider(create: ...)` | Yes | Yes |
| `BlocSignalProvider.value(value: ...)` | No | No |

```dart
BlocSignalProvider<CounterBloc>(
  create: (_) => CounterBloc(),
  child: const CounterPage(),
)
```

Use `.value` only when another owner already controls the bloc's lifetime. Closing that bloc from
both the provider and its original owner is an ownership bug even though the current `close` method
is idempotent.

## State rebuilds

`BlocSignalBuilder` reads a supplied bloc or finds one from the nearest matching provider. Its
internal `SignalBuilder` watches `bloc.state`:

```dart
BlocSignalBuilder<CounterBloc, int>(
  builder: (context, count) => Text('$count'),
)
```

Pass `bloc:` when the instance is not provided in the current subtree.

The provider and all state widgets accept `BlocSignalBase`, so they work with `BlocSignal` and
`CubitSignal`. When `bloc:` is omitted, the widget also depends on the provider and switches to a
replacement instance.

`context.read<T>()` finds a provider without adding an inherited-widget dependency. Use it for
commands:

```dart
context.read<CounterBloc>().add(Increment());
```

`context.watch<T>()` depends on the provider and rebuilds if the provided bloc instance changes.
It does not subscribe to `bloc.state`. Do not replace a state-aware `BlocBuilder` with
`context.watch<T>().stateValue`; use `BlocSignalBuilder` or a signals widget.

## Listeners, consumers, and selectors

`BlocSignalListener<T, S>` owns a signals effect around its child. Its listener receives the
current state immediately on mount and then receives later state changes:

```dart
BlocSignalListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state case Authenticated()) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  },
  child: const LoginForm(),
)
```

It exposes no previous state and has no `listenWhen`. In 0.1.9, rebuilding the listener widget can
restart its internal effect when the callback identity changes, which invokes the listener again
with the current state. Treat the callback as immediate and repeatable. Keep it idempotent, or add
an explicit first-run and previous-state guard when a navigation, dialog, or mutation must happen
once.

`BlocSignalConsumer<T, S>` combines that listener with `BlocSignalBuilder`. It has the same
immediate and repeatable listener behavior and no `buildWhen`.

`BlocSignalSelector<T, S, V>` computes `V` from each source state and rebuilds only when the new
selection is unequal to the previous selection:

```dart
BlocSignalSelector<ProfileCubit, ProfileState, String>(
  selector: (state) => state.displayName,
  builder: (context, name) => Text(name),
)
```

Give the selected type meaningful equality and avoid mutating a selected object in place. The
selector is reinitialized when its bloc or selector callback changes. In 0.1.9 it cleans up its
effect but does not explicitly dispose the `Computed` object; inspect the installed implementation
when deterministic computed disposal matters.

## Multiple providers

`MultiBlocSignalProvider` nests its providers in list order. Keep distinct concrete bloc types when
reading them by generic type:

```dart
MultiBlocSignalProvider(
  providers: [
    BlocSignalProvider<AuthBloc>(
      create: (_) => AuthBloc(),
      child: const SizedBox.shrink(),
    ),
    BlocSignalProvider<ThemeBloc>(
      create: (_) => ThemeBloc(),
      child: const SizedBox.shrink(),
    ),
  ],
  child: const AppShell(),
)
```

The placeholder children are replaced by `MultiBlocSignalProvider` through `copyWith`.

## Derived state and side effects

Create derived signals under an owner that outlives a build call. Valid owners include the bloc, a
`State` object, or a hooks API whose installed version owns disposal.

- Never call `effect` or `computed` from `build`.
- Dispose manual effects and subscriptions from `State.dispose`.
- Close a locally created bloc from the same owner.
- Do not assume optional `signals_hooks` APIs from an example. Inspect the version in the consumer
  project before using a hook.

For UI reactions, use `BlocSignalListener` only when its immediate, current-state-only behavior
matches the feature. Preserve mounted checks around work that crosses an async gap. Use a
state-owned or widget-owned reaction when previous/current filtering or stricter callback identity
is required.

## Missing-provider failures

`BlocSignalProvider.of<T>` throws `FlutterError` when no exact provider type is found. Check that the
lookup context is below the provider and that the generic type matches the provided concrete bloc.
Do not catch the error and construct a hidden fallback bloc.
