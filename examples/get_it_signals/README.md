# GetIt Dependency Injection Example (`BlocSignal` & `GetIt`)

A service locator dependency injection example demonstrating how `BlocSignal` pairs with `package:get_it`.

## ✨ Features

- **Service Locator Integration**: Registers state containers (`ServiceCubit`) as singletons or factories within `GetIt.instance`.
- **Non-Disposing Value Provider**: Uses `BlocSignalProvider.value(value: getIt<T>())` to provide instances to the widget tree without automatically calling `close()` when widgets unmount, preserving global singleton ownership.
- **Synchronous Graph Reactivity**: Consumes injected cubits with `BlocSignalBuilder` and `context.read<T>()` with zero latency.

## 🚀 Running the Example

```bash
cd examples/get_it_signals
flutter run
```

## 🧪 Running Tests

```bash
cd examples/get_it_signals
flutter test
```
