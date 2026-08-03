import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

class ReentrantCubit extends CubitSignal<int> {
  ReentrantCubit() : super(initialState: 0);

  void triggerNestedEmit(int count) {
    if (count > 0) {
      emit(count);
      triggerNestedEmit(count - 1);
    }
  }
}

class CascadeA extends CubitSignal<int> {
  CascadeA() : super(initialState: 0);
  void step() => emit(stateValue + 1);
}

class CascadeB extends CubitSignal<int> {
  CascadeB(this.a) : super(initialState: 0) {
    a.state.subscribe((val) {
      if (val > 0 && val < 5) {
        emit(val * 10);
      }
    });
  }
  final CascadeA a;
}

void main() {
  group('Re-entrancy & Cyclic Emission Boundaries', () {
    test('ReentrantCubit handles synchronous nested emit calls predictably',
        () async {
      final cubit = ReentrantCubit();
      final emittedValues = <int>[];

      cubit.state.subscribe(emittedValues.add);

      cubit.triggerNestedEmit(3);

      expect(emittedValues, containsAllInOrder([0, 3, 2, 1]));
      expect(cubit.stateValue, equals(1));

      await cubit.close();
    });

    test('Cascading dependent cubits propagate updates synchronously',
        () async {
      final a = CascadeA();
      final b = CascadeB(a);

      expect(a.stateValue, equals(0));
      expect(b.stateValue, equals(0));

      a.step();

      expect(a.stateValue, equals(1));
      expect(b.stateValue, equals(10));

      await a.close();
      await b.close();
    });

    test('createEffect allows clean observation without unhandled cycles',
        () async {
      final cubit = ReentrantCubit();
      var effectRuns = 0;

      final cleanup = effect(() {
        cubit.stateValue;
        effectRuns++;
      });

      cubit.triggerNestedEmit(2);

      expect(effectRuns, greaterThanOrEqualTo(3));

      cleanup();
      await cubit.close();
    });
  });
}
