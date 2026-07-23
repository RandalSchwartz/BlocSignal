# Flutter bindings and ownership

This reference matches `bloc_signals_flutter` 0.2.0. Inspect the installed package when the version
differs.

## Provider ownership

Use the constructor that matches ownership:

| Form | Creates the bloc | Closes the bloc on dispose |
| --- | ---: | ---: |
| `BlocSignalProvider(create: ..., lazy: true)` | On first lookup | Yes, if created |
| `BlocSignalProvider(create: ..., lazy: false)` | During provider initialization | Yes |
| `BlocSignalProvider.value(value: ...)` | No | No |

```dart
BlocSignalProvider<CounterBloc>(
  create: (_) => CounterBloc(),
  lazy: false,
  child: const CounterPage(),
)
```

`lazy` defaults to `true`. Use `lazy: false` only when creation must happen before the first lookup.
The provider intentionally does not await the owned bloc's `close()` future during widget disposal.

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

The provider and state widgets accept `BlocSignalBase`, so they work with `BlocSignal` and
`CubitSignal`. `BlocSignalBuilder` depends on the provider when `bloc:` is omitted and switches to
a replacement instance.

`context.read<T>()` finds a provider without adding an inherited-widget dependency. Use it for
commands:

```dart
context.read<CounterBloc>().add(Increment());
```

`context.watch<T>()` depends on the provider and rebuilds if the provided bloc instance changes.
It does not subscribe to `bloc.state`. Do not replace a state-aware `BlocBuilder` with
`context.watch<T>().stateValue`; use `BlocSignalBuilder` or a signals widget.

Use `context.select<T, R>` inside `build` for a narrow state slice:

```dart
final isSubmitEnabled = context.select<FormCubit, bool>(
  (cubit) => cubit.stateValue.canSubmit,
);
```

It rebuilds the element when the selected value changes by `!=`. Keep each element's select calls
unconditional and in a stable order because 0.2.0 caches subscriptions by call index. The lookup
does not register an inherited-provider dependency, so a provider instance swap is not observed
until another rebuild updates the subscription.

## Listeners, consumers, and selectors

`BlocSignalListener<T, S>` captures the current state on subscription, suppresses the effect's
initial run, and invokes its listener for later unequal states. Use `listenWhen` to filter with the
previous and current state:

```dart
BlocSignalListener<AuthBloc, AuthState>(
  listenWhen: (previous, current) => previous != current,
  listener: (context, state) {
    if (state case Authenticated()) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  },
  child: const LoginForm(),
)
```

The listener callback receives only the current state; `listenWhen` receives both values. An
unrelated parent rebuild does not restart the effect in 0.2.0. When `bloc:` is omitted, the listener
uses a non-listening provider lookup, so a provider instance swap can be missed until another
widget update runs. Pass the bloc explicitly or verify replacement behavior in a widget test when
the provider can change.

`BlocSignalConsumer<T, S>` combines that listener with `BlocSignalBuilder`. It has the same
initial-callback suppression and forwards `listenWhen`. It still has no `buildWhen`. Its provider
lookup does listen for instance replacement.

`BlocSignalSelector<T, S, V>` computes `V` from each source state and rebuilds only when the new
selection is unequal to the previous selection:

```dart
BlocSignalSelector<ProfileCubit, ProfileState, String>(
  selector: (state) => state.displayName,
  builder: (context, name) => Text(name),
)
```

Give the selected type meaningful equality and avoid mutating a selected object in place. The
selector is reinitialized when its bloc or selector callback changes. In 0.2.0 it cleans up its
effect but does not explicitly dispose the `Computed` object; inspect the installed implementation
when deterministic computed disposal matters.

`MultiBlocSignalListener` nests several listeners around one child. Each list entry still requires
its own placeholder child because `copyWith` replaces it:

```dart
MultiBlocSignalListener(
  listeners: [
    BlocSignalListener<AuthBloc, AuthState>(
      listener: onAuthState,
      child: const SizedBox.shrink(),
    ),
    BlocSignalListener<SyncCubit, SyncState>(
      listener: onSyncState,
      child: const SizedBox.shrink(),
    ),
  ],
  child: const AppShell(),
)
```

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

For UI reactions, use `BlocSignalListener` when suppressing the initial state and filtering through
`listenWhen` match the feature. Preserve mounted checks around work that crosses an async gap. Use
a state-owned or widget-owned reaction when the listener must receive both previous and current
values.

## Missing-provider failures

`BlocSignalProvider.of<T>` throws `FlutterError` when no exact provider type is found. Check that the
lookup context is below the provider and that the generic type matches the provided concrete bloc.
Do not catch the error and construct a hidden fallback bloc.
