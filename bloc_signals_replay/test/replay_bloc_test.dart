import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_replay/bloc_signals_replay.dart';
import 'package:test/test.dart';

import 'blocs/counter_bloc.dart';

class TestBlocObserver extends BlocSignalObserver {
  final events = <Object?>[];
  final transitions = <Transition<dynamic, dynamic>>[];

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    events.add(event);
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);
    if (event != null) {
      transitions.add(
        Transition<dynamic, dynamic>(
          currentState: bloc.stateValue,
          event: event,
          nextState: state,
        ),
      );
    }
  }
}

void main() {
  group('ReplayBloc', () {
    group('initial state', () {
      test('is correct', () {
        expect(CounterBloc().stateValue, 0);
      });
    });

    group('canUndo', () {
      test('is false when no state changes have occurred', () async {
        final bloc = CounterBloc();
        expect(bloc.canUndo, isFalse);
        await bloc.close();
      });

      test('is true when a single state change has occurred', () async {
        final bloc = CounterBloc()..add(const CounterIncrementPressed());
        expect(bloc.canUndo, isTrue);
        await bloc.close();
      });

      test('is false when undos have been exhausted', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..undo();
        expect(bloc.canUndo, isFalse);
        await bloc.close();
      });
    });

    group('canRedo', () {
      test('is false when no state changes have occurred', () async {
        final bloc = CounterBloc();
        expect(bloc.canRedo, isFalse);
        await bloc.close();
      });

      test('is true when a single undo has occurred', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..undo();
        expect(bloc.canRedo, isTrue);
        await bloc.close();
      });

      test('is false when redos have been exhausted', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..undo()
          ..redo();
        expect(bloc.canRedo, isFalse);
        await bloc.close();
      });
    });

    group('clearHistory', () {
      test('clears history and redos on new bloc', () async {
        final bloc = CounterBloc()
          ..add(const CounterIncrementPressed())
          ..clearHistory();
        expect(bloc.canRedo, isFalse);
        expect(bloc.canUndo, isFalse);
        await bloc.close();
      });
    });

    group('undo', () {
      test('does nothing when no state changes have occurred', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc.undo();
        await bloc.close();
        dispose();
        expect(states, [0]);
      });

      test('does nothing when limit is 0', () async {
        final states = <int>[];
        final bloc = CounterBloc(limit: 0);
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..undo();
        await bloc.close();
        dispose();
        expect(states, [0, 1]);
      });

      test('skips states filtered out by shouldReplay at undo time', () async {
        final states = <int>[];
        final bloc = CounterBloc(shouldReplayCallback: (i) => !i.isEven);
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed());
        bloc
          ..undo()
          ..undo()
          ..undo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2, 3, 1]);
      });

      test('reverts to initial state', () async {
        final states = <int>[];
        final observer = TestBlocObserver();
        BlocSignalObserver.observer = observer;
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..undo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 0]);
        expect(observer.events.map((e) => e.toString()),
            ['CounterIncrementPressed', 'Undo']);
      });

      test('reverts to previous state with multiple state changes', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..undo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2, 1]);
      });
    });

    group('redo', () {
      test('does nothing when no state changes have occurred', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc.redo();
        await bloc.close();
        dispose();
        expect(states, [0]);
      });

      test('does nothing when no undos have occurred', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..redo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2]);
      });

      test('works when one undo has occurred', () async {
        final states = <int>[];
        final observer = TestBlocObserver();
        BlocSignalObserver.observer = observer;
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..undo()
          ..redo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2, 1, 2]);
        expect(observer.events.map((e) => e.toString()), [
          'CounterIncrementPressed',
          'CounterIncrementPressed',
          'Undo',
          'Redo',
        ]);
      });

      test('does nothing when undos have been exhausted', () async {
        final states = <int>[];
        final bloc = CounterBloc();
        final dispose = bloc.state.subscribe(states.add);
        bloc
          ..add(const CounterIncrementPressed())
          ..add(const CounterIncrementPressed())
          ..undo()
          ..redo()
          ..redo();
        await bloc.close();
        dispose();
        expect(states, [0, 1, 2, 1, 2]);
      });
    });
  });

  group('CounterBlocMixin', () {
    test('works as expected', () async {
      final states = <int>[];
      final bloc = CounterBlocMixin();
      final dispose = bloc.state.subscribe(states.add);
      bloc
        ..add(const CounterIncrementPressed())
        ..add(const CounterIncrementPressed())
        ..undo()
        ..redo();
      await bloc.close();
      dispose();
      expect(states, [0, 1, 2, 1, 2]);
    });
  });
}
