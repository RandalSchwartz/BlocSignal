# Changelog

## 0.2.2

- Added full runnable BLoC sample code in `example/example.dart` demonstrating custom lint rule invariants.

## 0.2.1

- Added example documentation and pubspec package topics to improve pub.dev score to 160/160.

## 0.2.0

- Added 3 Flutter UI lint rules:
  - `avoid_emit_in_build`: Flags state emissions (`emit`/`add`) directly inside Flutter `Widget.build()` methods.
  - `avoid_unmanaged_signal_effects`: Flags unassigned `effect()` calls created in Flutter `Widget` or `State` scopes.
  - `prefer_bloc_signal_provider_read_in_callbacks`: Warns on `context.watch<T>()` inside callback closures (e.g. `onPressed`).
- Added automated IDE quick-fixes (`Cmd+.` / `Alt+Enter`):
  - `AddSuperOnEventFix`: Automatically inserts `super.onEvent(event);`.
  - `PreferReadInCallbacksFix`: Automatically replaces `context.watch<T>()` with `context.read<T>()`.

## 0.1.0

- Initial release of `bloc_signals_lint`.
- Custom lint rules and analyzer diagnostics for `bloc_signals`:
  - `avoid_duplicate_event_handlers`: Flags duplicate `on<E>` event handler registrations.
  - `require_super_on_event`: Enforces `super.onEvent(event)` calls inside `onEvent` overrides.
  - `avoid_stream_transformers_on_bloc_signal`: Flags stream transformer method invocations directly on synchronous state containers.
  - `avoid_direct_signal_mutation_outside_bloc`: Prevents external code from calling protected `emit()` methods outside the state container class.
