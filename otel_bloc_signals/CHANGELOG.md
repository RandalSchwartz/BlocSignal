## 0.2.1

- Update `bloc_signals` dependency constraint to `^0.2.1` to align with the new pure Dart `signals_core` package classification.

## 0.2.0

- Update OpenTelemetry instrumentation for version 0.2.0:
  - Support the new `close()` method returning `Future<void>`.
  - Update `bloc_signals` dependency constraint to `^0.2.0`.

## 0.1.6

- Update `bloc_signals` dependency constraint to `^0.1.12`.

## 0.1.5

- Update observer to accept `BlocSignalBase` to track transitions and errors on both Blocs and Cubits.
- Route Cubit errors to transient trace spans.

## 0.1.4

- Remove pre-release Dart SDK constraints in favor of stable `^3.10.0`.
- Update documentation and link package READMEs to the primary consumable AI coding assistant skill.

## 0.1.3

- Widen Dart SDK constraint to include pre-release versions of Dart `3.10.0`.


## 0.1.2

- Relax Dart SDK constraints to `^3.10.0` and relax dependency requirements.

## 0.1.1

- Add example demonstrating OpenTelemetry integration with `BlocSignal`.

## 0.1.0

- Initial release of `otel_bloc_signals` providing OpenTelemetry tracing instrumentation for `BlocSignal`.
