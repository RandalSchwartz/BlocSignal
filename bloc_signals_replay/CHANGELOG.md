## 0.1.1

- Add top-level `example/example.dart` for 100% pub.dev score checklist compliance.
- Update `bloc_signals` dependency to `^0.2.9` for explicit default constructor doc comments.

## 0.1.0

- Initial release of `bloc_signals_replay`.
- Add `ReplayCubit` and `ReplayCubitMixin` for method-driven `CubitSignal` containers.
- Add `ReplayBloc` and `ReplayBlocMixin` for event-driven `BlocSignal` containers with synthetic `_Undo` and `_Redo` transition tracing.
- Add `_ChangeStack` supporting configurable history limits (`limit`) and state filtering (`shouldReplay`).
