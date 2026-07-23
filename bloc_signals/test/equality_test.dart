// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'package:bloc_signals/bloc_signals.dart';
import 'package:meta/meta.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

@immutable
class TestState {
  const TestState(this.id, this.data);
  final int id;
  final String data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TestState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          data == other.data;

  @override
  int get hashCode => id.hashCode ^ data.hashCode;
}

sealed class CounterEvent {}

class Increment extends CounterEvent {}

class DefaultEqualsBloc extends BlocSignal<CounterEvent, TestState> {
  DefaultEqualsBloc(TestState initial) : super(initialState: initial) {
    on<Increment>((event, emit) {
      emit(TestState(stateValue.id + 1, stateValue.data));
    });
  }
}

class IdentityEqualsBloc extends BlocSignal<CounterEvent, TestState> {
  IdentityEqualsBloc(TestState initial) : super(initialState: initial) {
    on<Increment>((event, emit) {
      // Emits new object instance with same field values
      emit(TestState(stateValue.id, stateValue.data));
    });
  }

  @override
  bool equals(TestState previous, TestState current) {
    return identical(previous, current);
  }
}

class CustomCallbackBloc extends BlocSignal<CounterEvent, TestState> {
  CustomCallbackBloc(
    TestState initial, {
    super.equals,
  }) : super(initialState: initial) {
    on<Increment>((event, emit) {
      emit(TestState(stateValue.id, 'updated'));
    });
  }
}

class IdentityEqualsCubit extends CubitSignal<TestState> {
  IdentityEqualsCubit(TestState initial) : super(initialState: initial);

  void updateSameFields() {
    emit(TestState(stateValue.id, stateValue.data));
  }

  @override
  bool equals(TestState previous, TestState current) {
    return identical(previous, current);
  }
}

void main() {
  group('BlocSignal Base Equality', () {
    test('defaults to == value equality', () {
      const initial = TestState(1, 'a');
      final bloc = DefaultEqualsBloc(initial);
      expect(bloc.stateValue, equals(initial));

      // Emitting an equal value object (same id, same data) should be ignored
      bloc.emit(const TestState(1, 'a'));
      expect(bloc.stateValue, same(initial));
    });

    test('supports subclass equals override (e.g. identity comparison)', () {
      const initial = TestState(1, 'a');
      final bloc = IdentityEqualsBloc(initial);

      // Track transition calls
      final observer = _TrackingObserver();
      BlocSignalObserver.observer = observer;

      // Emitting new object instance with same field values
      bloc.add(Increment());

      expect(bloc.stateValue, isNot(same(initial)));
      expect(bloc.stateValue, equals(initial));
      expect(observer.transitions.length, equals(1));

      BlocSignalObserver.observer = null;
    });

    test('supports constructor equals callback override', () {
      const initial = TestState(1, 'a');
      final bloc = CustomCallbackBloc(
        initial,
        equals: (prev, next) => prev.id == next.id,
      );

      // Emitting same id but different data ignored because equals compares id
      bloc.add(Increment());
      expect(bloc.stateValue.data, equals('a'));
    });

    test('synchronizes custom equality with read-only state signal graph', () {
      const initial = TestState(1, 'a');
      final bloc = IdentityEqualsBloc(initial);
      var effectRuns = 0;

      final dispose = effect(() {
        final _ = bloc.state.value;
        effectRuns++;
      });

      expect(effectRuns, equals(1));

      // Emitting a new instance with identical fields
      bloc.add(Increment());

      // Effect re-runs because the signal graph uses identical equality
      expect(effectRuns, equals(2));
      dispose();
    });

    test('supports CubitSignal custom equals override', () {
      const initial = TestState(1, 'a');
      final cubit = IdentityEqualsCubit(initial);

      cubit.updateSameFields();

      expect(cubit.stateValue, isNot(same(initial)));
      expect(cubit.stateValue, equals(initial));
    });
  });
}

class _TrackingObserver extends BlocSignalObserver {
  final List<dynamic> transitions = [];

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    transitions.add(state);
  }
}
