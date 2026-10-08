import 'package:bloc_signals_replay/bloc_signals_replay.dart';
import 'package:test/test.dart';

import 'cubits/counter_cubit.dart';

void main() {
  group('ReplayCubit', () {
    group('initial state', () {
      test('is correct', () {
        expect(CounterCubit().stateValue, 0);
      });
    });

    group('canUndo', () {
      test('is false when no state changes have occurred', () async {
        final cubit = CounterCubit();
        expect(cubit.canUndo, isFalse);
        await cubit.close();
      });

      test('is true when a single state change has occurred', () async {
        final cubit = CounterCubit()..increment();
        expect(cubit.canUndo, isTrue);
        await cubit.close();
      });

      test('is false when undos have been exhausted', () async {
        final cubit = CounterCubit()
          ..increment()
          ..undo();
        expect(cubit.canUndo, isFalse);
        await cubit.close();
      });
    });

    group('canRedo', () {
      test('is false when no state changes have occurred', () async {
        final cubit = CounterCubit();
        expect(cubit.canRedo, isFalse);
        await cubit.close();
      });

      test('is true when a single undo has occurred', () async {
        final cubit = CounterCubit()
          ..increment()
          ..undo();
        expect(cubit.canRedo, isTrue);
        await cubit.close();
      });

      test('is false when redos have been exhausted', () async {
        final cubit = CounterCubit()
          ..increment()
          ..undo()
          ..redo();
        expect(cubit.canRedo, isFalse);
        await cubit.close();
      });

      test('does not clear redos when equal state is emitted', () async {
        final cubit = CounterCubit()
          ..increment()
          ..undo();
        expect(cubit.canRedo, isTrue);
        cubit.emitSelf();
        expect(cubit.canRedo, isTrue);
        await cubit.close();
      });

      test('does not add undo entry when equal state is emitted', () async {
        final cubit = CounterCubit()..emitSelf();
        expect(cubit.canUndo, isFalse);
        await cubit.close();
      });

      test('does not record history after close', () async {
        final cubit = CounterCubit();
        await cubit.close();
        cubit.increment();
        expect(cubit.canUndo, isFalse);
      });

      test(
        '(Issue #297: F6) does not mutate history or throw when undo or redo '
        'is called after close',
        () async {
          final cubit = CounterCubit()..increment();
          expect(cubit.canUndo, isTrue);
          expect(cubit.canRedo, isFalse);
          await cubit.close();

          expect(cubit.undo, returnsNormally);
          expect(cubit.stateValue, equals(1));
          expect(cubit.canUndo, isTrue);
          expect(cubit.canRedo, isFalse);

          expect(cubit.redo, returnsNormally);
          expect(cubit.stateValue, equals(1));
          expect(cubit.canUndo, isTrue);
          expect(cubit.canRedo, isFalse);
        },
      );
    });

    group('clearHistory', () {
      test('clears history and redos on new cubit', () async {
        final cubit = CounterCubit()
          ..increment()
          ..clearHistory();
        expect(cubit.canRedo, isFalse);
        expect(cubit.canUndo, isFalse);
        await cubit.close();
      });
    });

    group('undo', () {
      test('does nothing when no state changes have occurred', () async {
        final states = <int>[];
        final cubit = CounterCubit();
        final dispose = cubit.state.subscribe(states.add);
        cubit.undo();
        await cubit.close();
        dispose();
        expect(states, [0]);
      });

      test('does nothing when limit is 0', () async {
        final states = <int>[];
        final cubit = CounterCubit(limit: 0);
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1]);
      });

      test('skips states filtered out by shouldReplay at undo time', () async {
        final states = <int>[];
        final cubit = CounterCubit(shouldReplayCallback: (i) => !i.isEven);
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..increment()
          ..undo()
          ..undo()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 3, 1]);
      });

      test(
          "doesn't skip states that would be filtered out by shouldReplay "
          'at transition time but not at undo time', () async {
        var replayEvens = false;
        final states = <int>[];
        final cubit = CounterCubit(
          shouldReplayCallback: (i) => !i.isEven || replayEvens,
        );
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..increment();
        replayEvens = true;
        cubit
          ..undo()
          ..undo()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 3, 2, 1, 0]);
      });

      test('loses history outside of limit', () async {
        final states = <int>[];
        final cubit = CounterCubit(limit: 1);
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1]);
      });

      test('reverts to initial state', () async {
        final states = <int>[];
        final cubit = CounterCubit();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 0]);
      });

      test('reverts to previous state with multiple state changes', () async {
        final states = <int>[];
        final cubit = CounterCubit();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1]);
      });

      test('preserves undo order under synchronous nested effect emissions',
          () async {
        final cubit = CounterCubit();
        // A reactive effect listening to state 1 synchronously emits state 2.
        final disposeEffect = cubit.attachAutoIncrementEffect(1);

        cubit.increment(); // triggers effect -> emits 2
        expect(cubit.stateValue, 2);

        // Dispose reactive effect so restoring state 1 doesn't re-trigger it.
        disposeEffect();

        // Undo 2 -> 1 -> 0
        cubit.undo();
        expect(cubit.stateValue, 1);
        cubit.undo();
        expect(cubit.stateValue, 0);

        await cubit.close();
      });
    });

    group('redo', () {
      test('does nothing when no state changes have occurred', () async {
        final states = <int>[];
        final cubit = CounterCubit();
        final dispose = cubit.state.subscribe(states.add);
        cubit.redo();
        await cubit.close();
        dispose();
        expect(states, [0]);
      });

      test('does nothing when no undos have occurred', () async {
        final states = <int>[];
        final cubit = CounterCubit();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2]);
      });

      test('works when one undo has occurred', () async {
        final states = <int>[];
        final cubit = CounterCubit();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1, 2]);
      });

      test('does nothing when undos have been exhausted', () async {
        final states = <int>[];
        final cubit = CounterCubit();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo()
          ..redo()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1, 2]);
      });

      test(
          'does nothing when undos has occurred '
          'followed by a new state change', () async {
        final states = <int>[];
        final cubit = CounterCubit();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo()
          ..decrement()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1, 0]);
      });

      test(
          'redo does not redo states which were'
          ' filtered out by shouldReplay at undo time', () async {
        final states = <int>[];
        final cubit = CounterCubit(shouldReplayCallback: (i) => !i.isEven);
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..increment()
          ..undo()
          ..undo()
          ..undo()
          ..redo()
          ..redo()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 3, 1, 3]);
      });

      test(
          'redo does not redo states which were'
          ' filtered out by shouldReplay at transition time', () async {
        var replayEvens = false;
        final states = <int>[];
        final cubit = CounterCubit(
          shouldReplayCallback: (i) => !i.isEven || replayEvens,
        );
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..increment()
          ..undo()
          ..undo()
          ..undo();
        replayEvens = true;
        cubit
          ..redo()
          ..redo()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 3, 1, 2, 3]);
      });
    });
  });

  group('ReplayCubitMixin', () {
    group('initial state', () {
      test('is correct', () {
        expect(CounterCubitMixin().stateValue, 0);
      });
    });

    group('canUndo', () {
      test('is false when no state changes have occurred', () async {
        final cubit = CounterCubitMixin();
        expect(cubit.canUndo, isFalse);
        await cubit.close();
      });

      test('is true when a single state change has occurred', () async {
        final cubit = CounterCubitMixin()..increment();
        expect(cubit.canUndo, isTrue);
        await cubit.close();
      });

      test('is false when undos have been exhausted', () async {
        final cubit = CounterCubitMixin()
          ..increment()
          ..undo();
        expect(cubit.canUndo, isFalse);
        await cubit.close();
      });
    });

    group('canRedo', () {
      test('is false when no state changes have occurred', () async {
        final cubit = CounterCubitMixin();
        expect(cubit.canRedo, isFalse);
        await cubit.close();
      });

      test('is true when a single undo has occurred', () async {
        final cubit = CounterCubitMixin()
          ..increment()
          ..undo();
        expect(cubit.canRedo, isTrue);
        await cubit.close();
      });

      test('is false when redos have been exhausted', () async {
        final cubit = CounterCubitMixin()
          ..increment()
          ..undo()
          ..redo();
        expect(cubit.canRedo, isFalse);
        await cubit.close();
      });
    });

    group('clearHistory', () {
      test('clears history and redos on new cubit', () async {
        final cubit = CounterCubitMixin()
          ..increment()
          ..clearHistory();
        expect(cubit.canRedo, isFalse);
        expect(cubit.canUndo, isFalse);
        await cubit.close();
      });
    });

    group('undo', () {
      test('does nothing when no state changes have occurred', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin();
        final dispose = cubit.state.subscribe(states.add);
        cubit.undo();
        await cubit.close();
        dispose();
        expect(states, [0]);
      });

      test('does nothing when limit is 0', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin(limit: 0);
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1]);
      });

      test('loses history outside of limit', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin(limit: 1);
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1]);
      });

      test('reverts to initial state', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 0]);
      });

      test('reverts to previous state with multiple state changes', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1]);
      });
    });

    group('redo', () {
      test('does nothing when no state changes have occurred', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin();
        final dispose = cubit.state.subscribe(states.add);
        cubit.redo();
        await cubit.close();
        dispose();
        expect(states, [0]);
      });

      test('does nothing when no undos have occurred', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2]);
      });

      test('works when one undo has occurred', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1, 2]);
      });

      test('does nothing when undos have been exhausted', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo()
          ..redo()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1, 2]);
      });

      test(
          'does nothing when undos has occurred '
          'followed by a new state change', () async {
        final states = <int>[];
        final cubit = CounterCubitMixin();
        final dispose = cubit.state.subscribe(states.add);
        cubit
          ..increment()
          ..increment()
          ..undo()
          ..decrement()
          ..redo();
        await cubit.close();
        dispose();
        expect(states, [0, 1, 2, 1, 0]);
      });
    });

    group('named constructor & history limits ergonomics', () {
      test(
        'supports named initialState and maxHistoryLength parameter',
        () async {
          final cubit = _NamedCounterCubit(
            initialState: 10,
            maxHistoryLength: 2,
          );
          expect(cubit.stateValue, 10);
          cubit
            ..increment() // 11
            ..increment() // 12
            ..increment(); // 13
          expect(cubit.stateValue, 13);
          cubit.undo();
          expect(cubit.stateValue, 12);
          cubit.undo();
          expect(cubit.stateValue, 11);
          expect(cubit.canUndo, isFalse); // Limited to 2 historical states
          await cubit.close();
        },
      );

      test(
        'supports deprecated positional constructor for backward compatibility',
        () async {
          final cubit = _PositionalCounterCubit(10, limit: 2);
          expect(cubit.stateValue, 10);
          cubit
            ..increment()
            ..increment()
            ..increment();
          expect(cubit.stateValue, 13);
          cubit.undo();
          expect(cubit.stateValue, 12);
          cubit.undo();
          expect(cubit.stateValue, 11);
          expect(cubit.canUndo, isFalse);
          await cubit.close();
        },
      );
    });
  });

  group(
      '(Issue #319: R5) runtime limit trimming & atomic shouldReplay '
      'traversal', () {
    group('ReplayCubit', () {
      test('runtime limit lowering trims existing _history', () async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);
        for (var i = 1; i <= 5; i++) {
          cubit.increment();
        }
        expect(cubit.stateValue, 5);

        cubit.limit = 2;
        expect(cubit.limit, 2);

        cubit
          ..undo()
          ..undo()
          ..undo()
          ..undo()
          ..undo();

        expect(cubit.stateValue, 3);
        expect(cubit.canUndo, isFalse);
      });

      test('runtime limit = 0 clears existing _history and _redos', () async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);
        cubit
          ..increment()
          ..increment()
          ..increment();
        expect(cubit.stateValue, 3);

        cubit.undo();
        expect(cubit.stateValue, 2);
        expect(cubit.canUndo, isTrue);
        expect(cubit.canRedo, isTrue);

        cubit.limit = 0;
        expect(cubit.limit, 0);
        expect(cubit.canUndo, isFalse);
        expect(cubit.canRedo, isFalse);

        cubit.undo();
        expect(cubit.stateValue, 2);
        cubit.redo();
        expect(cubit.stateValue, 2);
      });

      test('runtime limit = null restores unbounded history', () async {
        final cubit = CounterCubit(limit: 1);
        addTearDown(cubit.close);
        cubit
          ..increment()
          ..increment();
        expect(cubit.stateValue, 2);

        cubit.limit = null;
        expect(cubit.limit, isNull);

        cubit
          ..increment()
          ..increment()
          ..increment();
        expect(cubit.stateValue, 5);

        cubit
          ..undo()
          ..undo()
          ..undo()
          ..undo();
        expect(cubit.stateValue, 1);
        expect(cubit.canUndo, isFalse);
      });

      test(
        'lowering limit while entries are in _redos trims _history upon redo()',
        () async {
          final cubit = CounterCubit();
          addTearDown(cubit.close);
          cubit
            ..increment()
            ..increment()
            ..increment()
            ..increment();
          expect(cubit.stateValue, 4);

          cubit
            ..undo()
            ..undo();
          expect(cubit.stateValue, 2);

          cubit.limit = 2;
          expect(cubit.limit, 2);

          cubit
            ..redo()
            ..redo();
          expect(cubit.stateValue, 4);

          cubit
            ..undo()
            ..undo()
            ..undo()
            ..undo();
          expect(cubit.stateValue, 2);
          expect(cubit.canUndo, isFalse);
        },
      );

      test(
        'single-pass shouldReplay evaluation & atomic rollback when no '
        'replayable target exists',
        () async {
          var evaluations = 0;
          final cubitA = CounterCubit(
            shouldReplayCallback: (s) {
              evaluations++;
              return s == 1;
            },
          );
          addTearDown(cubitA.close);

          for (var i = 1; i <= 5; i++) {
            cubitA.increment();
          }
          expect(cubitA.stateValue, 5);
          evaluations = 0;

          cubitA.undo();
          expect(cubitA.stateValue, 1);
          expect(evaluations, 4);

          var allowReplay = false;
          final cubitB = CounterCubit(
            shouldReplayCallback: (s) => allowReplay,
          );
          addTearDown(cubitB.close);

          cubitB
            ..increment()
            ..increment()
            ..increment();
          expect(cubitB.stateValue, 3);

          cubitB.undo();
          expect(cubitB.stateValue, 3);
          expect(cubitB.canRedo, isFalse);

          allowReplay = true;
          expect(cubitB.canUndo, isTrue);
          cubitB.undo();
          expect(cubitB.stateValue, 2);

          allowReplay = false;
          cubitB.redo();
          expect(cubitB.stateValue, 2);

          allowReplay = true;
          expect(cubitB.canRedo, isTrue);
          cubitB.redo();
          expect(cubitB.stateValue, 3);

          final cubitC = CounterCubit(
            shouldReplayCallback: (s) => s.isOdd,
          );
          addTearDown(cubitC.close);

          cubitC
            ..increment()
            ..increment()
            ..increment();
          expect(cubitC.stateValue, 3);

          cubitC.undo();
          expect(cubitC.stateValue, 1);
          expect(cubitC.canUndo, isFalse);

          cubitC.redo();
          expect(cubitC.stateValue, 3);
          expect(cubitC.canRedo, isFalse);

          cubitC.undo();
          expect(cubitC.stateValue, 1);
          cubitC.redo();
          expect(cubitC.stateValue, 3);
        },
      );
    });

    group('ReplayCubitMixin', () {
      test('runtime limit lowering trims existing _history', () async {
        final cubit = CounterCubitMixin();
        addTearDown(cubit.close);
        for (var i = 1; i <= 5; i++) {
          cubit.increment();
        }
        expect(cubit.stateValue, 5);

        cubit.limit = 2;
        expect(cubit.limit, 2);

        cubit
          ..undo()
          ..undo()
          ..undo()
          ..undo()
          ..undo();

        expect(cubit.stateValue, 3);
        expect(cubit.canUndo, isFalse);
      });

      test('runtime limit = 0 clears existing _history and _redos', () async {
        final cubit = CounterCubitMixin();
        addTearDown(cubit.close);
        cubit
          ..increment()
          ..increment()
          ..increment();
        expect(cubit.stateValue, 3);

        cubit.undo();
        expect(cubit.stateValue, 2);
        expect(cubit.canUndo, isTrue);
        expect(cubit.canRedo, isTrue);

        cubit.limit = 0;
        expect(cubit.limit, 0);
        expect(cubit.canUndo, isFalse);
        expect(cubit.canRedo, isFalse);

        cubit.undo();
        expect(cubit.stateValue, 2);
        cubit.redo();
        expect(cubit.stateValue, 2);
      });

      test('runtime limit = null restores unbounded history', () async {
        final cubit = CounterCubitMixin(limit: 1);
        addTearDown(cubit.close);
        cubit
          ..increment()
          ..increment();
        expect(cubit.stateValue, 2);

        cubit.limit = null;
        expect(cubit.limit, isNull);

        cubit
          ..increment()
          ..increment()
          ..increment();
        expect(cubit.stateValue, 5);

        cubit
          ..undo()
          ..undo()
          ..undo()
          ..undo();
        expect(cubit.stateValue, 1);
        expect(cubit.canUndo, isFalse);
      });

      test(
        'lowering limit while entries are in _redos trims _history upon redo()',
        () async {
          final cubit = CounterCubitMixin();
          addTearDown(cubit.close);
          cubit
            ..increment()
            ..increment()
            ..increment()
            ..increment();
          expect(cubit.stateValue, 4);

          cubit
            ..undo()
            ..undo();
          expect(cubit.stateValue, 2);

          cubit.limit = 2;
          expect(cubit.limit, 2);

          cubit
            ..redo()
            ..redo();
          expect(cubit.stateValue, 4);

          cubit
            ..undo()
            ..undo()
            ..undo()
            ..undo();
          expect(cubit.stateValue, 2);
          expect(cubit.canUndo, isFalse);
        },
      );

      test(
        'single-pass shouldReplay evaluation & atomic rollback when no '
        'replayable target exists',
        () async {
          var evaluations = 0;
          final cubitA = CounterCubitMixin(
            shouldReplayCallback: (s) {
              evaluations++;
              return s == 1;
            },
          );
          addTearDown(cubitA.close);

          for (var i = 1; i <= 5; i++) {
            cubitA.increment();
          }
          expect(cubitA.stateValue, 5);
          evaluations = 0;

          cubitA.undo();
          expect(cubitA.stateValue, 1);
          expect(evaluations, 4);

          var allowReplay = false;
          final cubitB = CounterCubitMixin(
            shouldReplayCallback: (s) => allowReplay,
          );
          addTearDown(cubitB.close);

          cubitB
            ..increment()
            ..increment()
            ..increment();
          expect(cubitB.stateValue, 3);

          cubitB.undo();
          expect(cubitB.stateValue, 3);
          expect(cubitB.canRedo, isFalse);

          allowReplay = true;
          expect(cubitB.canUndo, isTrue);
          cubitB.undo();
          expect(cubitB.stateValue, 2);

          allowReplay = false;
          cubitB.redo();
          expect(cubitB.stateValue, 2);

          allowReplay = true;
          expect(cubitB.canRedo, isTrue);
          cubitB.redo();
          expect(cubitB.stateValue, 3);

          final cubitC = CounterCubitMixin(
            shouldReplayCallback: (s) => s.isOdd,
          );
          addTearDown(cubitC.close);

          cubitC
            ..increment()
            ..increment()
            ..increment();
          expect(cubitC.stateValue, 3);

          cubitC.undo();
          expect(cubitC.stateValue, 1);
          expect(cubitC.canUndo, isFalse);

          cubitC.redo();
          expect(cubitC.stateValue, 3);
          expect(cubitC.canRedo, isFalse);

          cubitC.undo();
          expect(cubitC.stateValue, 1);
          cubitC.redo();
          expect(cubitC.stateValue, 3);
        },
      );
    });
  });
}

class _NamedCounterCubit extends ReplayCubit<int> {
  _NamedCounterCubit({required super.initialState, super.maxHistoryLength});

  void increment() => emit(stateValue + 1);
}

class _PositionalCounterCubit extends ReplayCubit<int> {
  _PositionalCounterCubit(super.initialState, {super.limit})
      // Testing backward-compatible positional constructor.
      // ignore: deprecated_member_use_from_same_package
      : super.positional();

  void increment() => emit(stateValue + 1);
}
