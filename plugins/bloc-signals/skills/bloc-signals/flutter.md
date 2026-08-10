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

Use `context.select<B, R>` inside `build` for a narrow state slice:

```dart
final isSubmitEnabled = context.select<FormCubit, bool>(
  (cubit) => cubit.stateValue.canSubmit,
);
```

> [!TIP]
> **Generic Type Signature & Selector Parameter (`context.select<B, R>`)**:
> In `bloc_signals_flutter`, `context.select` takes **2** generic type parameters:
> 1. `B`: The `BlocSignalBase` container type (e.g. `FormCubit` or `CounterBloc`).
> 2. `R`: The selected return value type (e.g. `bool` or `String`).
>
> Unlike `flutter_riverpod` (which uses 3 generic parameters in some forms) or classic `flutter_bloc` context selection, `bloc_signals_flutter` passes the **`bloc` container instance** to the selector callback (`(bloc) => bloc.stateValue.canSubmit`), allowing direct property access via `bloc.stateValue`.

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

`BlocSignalBuilder` supports `buildWhen(previous, current)` to conditionally suppress rebuilds when state changes:

```dart
BlocSignalBuilder<CounterBloc, int>(
  buildWhen: (previous, current) => current.isEven,
  builder: (context, count) => Text('$count'),
)
```

`BlocSignalConsumer<T, S>` combines that listener with `BlocSignalBuilder`. It forwards both `listenWhen` and `buildWhen`. Its provider lookup does listen for instance replacement.


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

`MultiBlocSignalListener` nests several listeners around one child. Individual listeners do not require a placeholder `child` parameter:

```dart
MultiBlocSignalListener(
  listeners: [
    BlocSignalListener<AuthBloc, AuthState>(
      listener: onAuthState,
    ),
    BlocSignalListener<SyncCubit, SyncState>(
      listener: onSyncState,
    ),
  ],
  child: const AppShell(),
)
```

## Multiple providers

`MultiBlocSignalProvider` nests its providers in list order. Individual providers do not require a placeholder `child` parameter:

```dart
MultiBlocSignalProvider(
  providers: [
    BlocSignalProvider<AuthBloc>(
      create: (_) => AuthBloc(),
    ),
    BlocSignalProvider<ThemeBloc>(
      create: (_) => ThemeBloc(),
    ),
  ],
  child: const AppShell(),
)
```

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

## Flutter Hooks Integration (Zero-Cost with `signals_hooks`)

Because `bloc.state` is natively a `ReadonlySignal<S>`, developers migrating from or using `flutter_hooks` do **not** need a separate glue-code package (like the legacy `flutter_hooks_bloc`). Using `package:signals_hooks`, any `HookWidget` can consume, filter, or react to `BlocSignal` state out-of-the-box:

```dart
class CounterHookView extends HookWidget {
  const CounterHookView({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Create or read the bloc instance
    final bloc = useMemoized(() => CounterBloc());

    // 2. Direct reactive subscription without BlocBuilder / Consumer
    final count = useSignalValue(bloc.state);

    // 3. Inline reactive side-effects without BlocListener
    useSignalEffect(() {
      if (count > 10) debugPrint('Counter reached double digits: $count');
    });

    // 4. Fine-grained inline computed selections without BlocSelector
    final isEven = useComputed(() => count.isEven);

    return Scaffold(
      body: Text('Count: $count (Even: ${isEven.value})'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => bloc.add(Increment()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Key advantages for hook workflows:
- **No `flutter_hooks_bloc` Glue Code**: No need for `useBloc` or custom macro-widgets.
- **Zero-Cost Lifecycle Teardown**: Hooks naturally manage subscription lifecycle and unmount disposal.
- **Composable State**: Effortlessly combine BLoC signals with local widget signals using `useComputed` or `useSignalEffect`.

## Form Input Synchronization (`TextFormField` with `ValueKey`)

When synchronizing form fields (`TextFormField`) with `BlocSignalBuilder` or signal state, avoid mutating a `TextEditingController.text` property inside a `build` method or `useEffect` hook:

```dart
// ❌ BAD: Mutating controller during build triggers Flutter assertion:
// "setState() or markNeedsBuild() called during build."
useEffect(() {
  controller.text = displayValue;
  return null;
}, [displayValue]);
```

### Idiomatic `ValueKey` Pattern

The cleanest pattern in `bloc_signals_flutter` is using `initialValue` paired with a state-derived `ValueKey` on `TextFormField` inside `BlocSignalBuilder`:

```dart
BlocSignalBuilder<UserDataCubit, UserData>(
  builder: (context, userData) {
    final displayWeight = userData.displayWeight;

    return TextFormField(
      // Pair ValueKey with initialValue to re-initialize field on external state changes
      key: ValueKey('weight_${userData.unit}_$displayWeight'),
      initialValue: displayWeight.toStringAsFixed(1),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          context.read<UserDataCubit>().setWeight(parsed);
        }
      },
    );
  },
);
```

**Why this works**:
- **Zero Build-Phase Mutations**: Eliminates `controller.text` mutations during frame builds.
- **Automatic Sync on External Changes**: Updating `ValueKey` forces `TextFormField` to re-initialize cleanly with `initialValue` when state changes externally (e.g. state hydration or unit switching).
- **Clean Field State**: Allows standard typing and validation while keeping state reactivity declarative.

## Missing-provider failures


`BlocSignalProvider.of<T>` throws `FlutterError` when no exact provider type is found. Check that the
lookup context is below the provider and that the generic type matches the provided concrete bloc.
Do not catch the error and construct a hidden fallback bloc.
