import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

class TestCounterCubit extends CubitSignal<int> {
  TestCounterCubit([int initial = 0]) : super(initialState: initial);

  void increment() => emit(stateValue + 1);
}

class TestCounterBloc extends BlocSignal<String, int> {
  TestCounterBloc([int initial = 0]) : super(initialState: initial) {
    on<String>((event, emit) {
      if (event == 'inc') {
        emit(stateValue + 1);
      }
    });
  }
}

void main() {
  group('BlocSignalBase.toString() (#78)', () {
    test('CubitSignal.toString() formats as ClassName(stateValue)', () {
      final cubit = TestCounterCubit(0);
      expect(cubit.toString(), equals('TestCounterCubit(0)'));

      cubit.increment();
      expect(cubit.toString(), equals('TestCounterCubit(1)'));
    });

    test('BlocSignal.toString() formats as ClassName(stateValue)', () {
      final bloc = TestCounterBloc(10);
      expect(bloc.toString(), equals('TestCounterBloc(10)'));

      bloc.add('inc');
      expect(bloc.toString(), equals('TestCounterBloc(11)'));
    });
  });
}
