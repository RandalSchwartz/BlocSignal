## 0.2.3

- Initial release as `bloc_signals_otel` (formerly `otel_bloc_signals`).
- Aligned package name with `bloc_signals_*` monorepo package naming convention.
- OpenTelemetry tracing instrumentation for `BlocSignal` and `CubitSignal`.
- Cap active span maps and purge lingering spans on `onClose` disposal to prevent memory leaks during high-frequency error cascades.
- Route error exceptions directly to active event spans via identity hash-matching.
- Update `bloc_signals` dependency to `^0.2.8`.
