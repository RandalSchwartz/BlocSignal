import 'package:bloc_signals_replay/bloc_signals_replay.dart';
import 'package:test/test.dart';

class _CoalescingSliderCubit extends ReplayCubit<int> {
  _CoalescingSliderCubit({
    this.coalesce = true,
    this.skipNegOne = false,
    super.limit,
  }) : super(initialState: 0);

  final bool coalesce;
  final bool skipNegOne;

  void setValue(int value) => emit(value);

  @override
  bool shouldCoalesce(int previousState, int currentState, int nextState) {
    if (skipNegOne && (previousState == -1 || currentState == -1)) {
      return false;
    }
    return coalesce;
  }
}

sealed class _SliderEvent extends ReplayEvent {
  const _SliderEvent();
}

final class _SetSliderValue extends _SliderEvent {
  const _SetSliderValue(this.value);
  final int value;
}

class _CoalescingSliderBloc extends ReplayBloc<_SliderEvent, int> {
  _CoalescingSliderBloc() : super(initialState: 0) {
    on<_SetSliderValue>((event, emit) => emit(event.value));
  }

  @override
  bool shouldCoalesce(int previousState, int currentState, int nextState) =>
      true;
}

void main() {
  group('(Issue #479) shouldCoalesce on ReplayCubit', () {
    test('merges 0 -> 1 -> 2 -> 3 into single undo to 0 and redo to 3',
        () async {
      final cubit = _CoalescingSliderCubit()
        ..setValue(1)
        ..setValue(2)
        ..setValue(3);

      expect(cubit.stateValue, 3);
      expect(cubit.canUndo, isTrue);

      cubit.undo();
      expect(cubit.stateValue, 0);
      expect(cubit.canUndo, isFalse);
      expect(cubit.canRedo, isTrue);

      cubit.redo();
      expect(cubit.stateValue, 3);
      expect(cubit.canRedo, isFalse);
      expect(cubit.canUndo, isTrue);
      await cubit.close();
    });

    test('drops no-op entry when 0 -> 1 -> 0 coalesces back to initial state',
        () async {
      final cubit = _CoalescingSliderCubit()
        ..setValue(1)
        ..setValue(0);

      expect(cubit.stateValue, 0);
      expect(cubit.canUndo, isFalse);
      expect(cubit.canRedo, isFalse);
      await cubit.close();
    });

    test('pushes separate entries when shouldCoalesce returns false', () async {
      final cubit = _CoalescingSliderCubit(coalesce: false)
        ..setValue(1)
        ..setValue(2)
        ..setValue(3)
        ..undo();
      expect(cubit.stateValue, 2);
      cubit.undo();
      expect(cubit.stateValue, 1);
      cubit.undo();
      expect(cubit.stateValue, 0);
      await cubit.close();
    });
  });

  group('(Issue #479) shouldCoalesce on ReplayBloc', () {
    test('merges 0 -> 1 -> 2 -> 3 into single undo to 0 and redo to 3',
        () async {
      final bloc = _CoalescingSliderBloc()
        ..add(const _SetSliderValue(1))
        ..add(const _SetSliderValue(2))
        ..add(const _SetSliderValue(3));

      expect(bloc.stateValue, 3);
      expect(bloc.canUndo, isTrue);

      bloc.undo();
      expect(bloc.stateValue, 0);
      expect(bloc.canUndo, isFalse);
      expect(bloc.canRedo, isTrue);

      bloc.redo();
      expect(bloc.stateValue, 3);
      expect(bloc.canRedo, isFalse);
      expect(bloc.canUndo, isTrue);
      await bloc.close();
    });

    test('drops no-op entry when 0 -> 1 -> 0 coalesces back to initial state',
        () async {
      final bloc = _CoalescingSliderBloc()
        ..add(const _SetSliderValue(1))
        ..add(const _SetSliderValue(0));

      expect(bloc.stateValue, 0);
      expect(bloc.canUndo, isFalse);
      expect(bloc.canRedo, isFalse);
      await bloc.close();
    });

    test(
        'BLOCKER-6: coalescing replaceLast and dropLast clear redo stack on '
        'ReplayCubit and ReplayBloc', () async {
      // ReplayCubit: replaceLast clears redo stack.
      final cubit = _CoalescingSliderCubit()
        ..setValue(1)
        ..undo();
      expect(cubit.canRedo, isTrue);

      cubit
        ..setValue(2)
        ..setValue(3);
      expect(cubit.canRedo, isFalse);
      cubit.redo();
      expect(cubit.stateValue, 3);
      await cubit.close();

      // ReplayCubit: dropLast (0 -> 1 -> 0) clears redo stack.
      final cubitDrop = _CoalescingSliderCubit()
        ..setValue(1)
        ..undo();
      expect(cubitDrop.canRedo, isTrue);
      cubitDrop
        ..setValue(2)
        ..setValue(0);
      expect(cubitDrop.canRedo, isFalse);
      cubitDrop.redo();
      expect(cubitDrop.stateValue, 0);
      await cubitDrop.close();

      // ReplayBloc: replaceLast and dropLast clear redo stack.
      final bloc = _CoalescingSliderBloc()
        ..add(const _SetSliderValue(1))
        ..undo();
      expect(bloc.canRedo, isTrue);
      bloc
        ..add(const _SetSliderValue(2))
        ..add(const _SetSliderValue(3));
      expect(bloc.canRedo, isFalse);
      bloc.redo();
      expect(bloc.stateValue, 3);
      await bloc.close();
    });

    test(
        'NBO-3: shouldCoalesce with limit: 1, limit: 0, and preserving earlier '
        'non-coalesced entry on dropLast', () async {
      // limit: 1 retains 0 across 0 -> 1 -> 2 -> 3.
      final cubitLimit1 = _CoalescingSliderCubit(limit: 1)
        ..setValue(1)
        ..setValue(2)
        ..setValue(3);
      expect(cubitLimit1.canUndo, isTrue);
      cubitLimit1.undo();
      expect(cubitLimit1.stateValue, 0);
      await cubitLimit1.close();

      // limit: 0 records no history even with shouldCoalesce returning true.
      final cubitLimit0 = _CoalescingSliderCubit(limit: 0)
        ..setValue(1)
        ..setValue(2);
      expect(cubitLimit0.canUndo, isFalse);
      await cubitLimit0.close();

      // -1 -> 0 -> 1 -> 0 drops only the 0 -> 1 -> 0 entry, preserving -1.
      final cubitPreserve = _CoalescingSliderCubit(skipNegOne: true)
        ..setValue(-1)
        ..setValue(0)
        ..setValue(1)
        ..setValue(0);
      expect(cubitPreserve.canUndo, isTrue);
      cubitPreserve.undo();
      expect(cubitPreserve.stateValue, -1);
      expect(cubitPreserve.canUndo, isTrue);
      cubitPreserve.undo();
      expect(cubitPreserve.stateValue, 0);
      expect(cubitPreserve.canUndo, isFalse);
      await cubitPreserve.close();
    });
  });
}
