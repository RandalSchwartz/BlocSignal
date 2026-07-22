# Changelog

## 0.1.0

- Initial release of `bloc_signals_lint`.
- Custom lint rules and analyzer diagnostics for `bloc_signals`:
  - `avoid_duplicate_event_handlers`: Flags duplicate `on<E>` event handler registrations.
  - `require_super_on_event`: Enforces `super.onEvent(event)` calls inside `onEvent` overrides.
  - `avoid_stream_transformers_on_bloc_signal`: Flags stream transformer method invocations directly on synchronous state containers.
  - `avoid_direct_signal_mutation_outside_bloc`: Prevents external code from calling protected `emit()` methods outside the state container class.
