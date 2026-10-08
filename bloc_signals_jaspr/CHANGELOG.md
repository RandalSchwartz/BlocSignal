# Changelog

## Unreleased

- **Fix (jaspr)**: Respect container `bloc.equals(previous, current)` in `BlocSignalBuilder` and `BlocSignalListener`, support custom `equals` and `SignalOptions.equalityCheck` in `BlocSignalSelector` while re-initializing `computed` when `options` or `equals` changes in `didUpdateComponent`, and pass `listen: true` when falling back to `BlocSignalProvider.of<T>(context, listen: true)` in `didUpdateComponent` (#320).

## 1.1.2

- Fix `BlocSignalProvider` and `context.select`:
  - Skip spurious rebuild on lazy `BlocSignalProvider` when container was initialized in-frame (F5, #298).
  - Wrap lazy provider factory invocation in `try`/`finally` to prevent unbounded retry loops (F24, #298).
  - Clean up orphaned selector subscriptions on conditional select branches (F25, #298).
  - Catch only defunct `AssertionError` during Jaspr selector effect rebuild to cleanly dispose unmounted component subscriptions while bubbling real developer exceptions (F26, #298).

## 1.1.1

- Fix `BlocSignalListener` and `BlocSignalConsumer` subscription transfer when provider container instance is swapped above `const` subtrees (#273).

## 1.1.0

- Add `context.value<T, S>()` and `context.state<T, S>()` extensions on `BuildContext` establishing feature parity with `bloc_signals_flutter` (#251).
- Bump minimum `bloc_signals` dependency constraint to `^1.4.0` (#251).

## 1.0.1

- Fix `context.select` subscription transfer when provider container instance is swapped above `const` subtrees (#204).

## 1.0.0+1

- Maintenance patch release for pub.dev package score re-analysis.

## 1.0.0


- Official 1.0.0 production release.
- Update `bloc_signals` dependency constraint to `^1.0.0`.

## 0.9.0+1

- Metadata release to verify repository URL on pub.dev.

## 0.9.0

- Staging release candidate for the 1.0.0 production milestone.
- Update `bloc_signals` dependency constraint to `^0.9.0`.

## 0.1.2

- Fix OSI license detection in LICENSE file.

# 0.1.1

- Add top-level `example/example.dart` for 100% pub.dev score checklist compliance.
- Update `bloc_signals` dependency to `^0.2.9` for explicit default constructor doc comments.

## 0.1.0

- Initial release of `bloc_signals_jaspr`.
- `BlocSignalProvider` and `MultiBlocSignalProvider` for Jaspr web component tree injection via `InheritedComponent`.
- `context.read<T>()`, `context.watch<T>()`, and `context.select<T, R>()` extensions on Jaspr `BuildContext`.
- `BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`, `BlocSignalSelector`, and `MultiBlocSignalListener` Jaspr components.
