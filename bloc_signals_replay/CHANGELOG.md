## 1.1.0

- **Constructor Alignment**: Support named parameter `required State initialState` on `ReplayCubit` and `ReplayBloc` constructors to align with framework-wide conventions (#224).
- **Migration Path**: Existing subclasses calling positional `super(initialState)` can update to named `super(initialState: initialState)` or invoke the backward-compatible `@Deprecated` constructor `super.positional(initialState)`.
- Add `maxHistoryLength` parameter as a named alias for `limit`.

## 1.0.0+1

- Re-trigger pub.dev Pana static analysis.

## 1.0.0

- Official 1.0.0 production release.
- Update `bloc_signals` dependency constraint to `^1.0.0`.

## 0.9.0

- Staging release candidate for the 1.0.0 production milestone.
- Update `bloc_signals` dependency constraint to `^0.9.0`.

## 0.1.1

- Add top-level `example/example.dart` for 100% pub.dev score checklist compliance.
- Update `bloc_signals` dependency to `^0.2.9` for explicit default constructor doc comments.

## 0.1.0

- Initial release of `bloc_signals_replay`.
- Add `ReplayCubit` and `ReplayCubitMixin` for method-driven `CubitSignal` containers.
- Add `ReplayBloc` and `ReplayBlocMixin` for event-driven `BlocSignal` containers with synthetic `_Undo` and `_Redo` transition tracing.
- Add `_ChangeStack` supporting configurable history limits (`limit`) and state filtering (`shouldReplay`).
