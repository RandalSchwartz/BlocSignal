# Changelog

## 1.1.0

- Add `traced` transformer decorator wrapping standard `EventTransformer` instances with OpenTelemetry distributed trace span instrumentation.
- Add `tracedBloc` transformer decorator wrapping contextual `BlocEventTransformer` instances with OpenTelemetry distributed trace span instrumentation.
- Automatically record unhandled errors on active spans and set status to `StatusCode.error`.
- Preserve synchronous fast-paths for synchronous handlers to avoid artificial `Future` allocations and microtask deferral.
- Update `bloc_signals` dependency constraint to `^1.3.0`.

## 1.0.0+1

- Maintenance patch release for pub.dev package score re-analysis.

## 1.0.0


- Official 1.0.0 production release.
- Update `bloc_signals` dependency constraint to `^1.0.0`.

## 0.9.0

- Staging release candidate for the 1.0.0 production milestone.
- Update `bloc_signals` dependency constraint to `^0.9.0`.

## 0.2.4

- Initial release as `bloc_signals_otel` (formerly `otel_bloc_signals`).
- Aligned package name with `bloc_signals_*` monorepo package naming convention.
- OpenTelemetry tracing instrumentation for `BlocSignal` and `CubitSignal`.
- Cap active span maps and purge lingering spans on `onClose` disposal to prevent memory leaks during high-frequency error cascades.
- Route error exceptions directly to active event spans via identity hash-matching.
- Update `bloc_signals` dependency to `^0.2.8`.
