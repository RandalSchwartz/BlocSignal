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

class _UninitializedMixinController with CubitSignalMixin<int> {}

class _RedactedStateCubit extends CubitSignal<String> {
  _RedactedStateCubit(String initial) : super(initialState: initial);

  @override
  String describeState(String state) => '***REDACTED***';
}

class _RedactedStateBloc extends BlocSignal<String, String> {
  _RedactedStateBloc(String initial) : super(initialState: initial);

  @override
  String describeState(String state) => 'BLOC_REDACTED';
}

void main() {
  group('BlocSignalBase.toString() (#78)', () {
    test('CubitSignal.toString() formats as ClassName(stateValue)', () {
      final cubit = TestCounterCubit();
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

    test(
      '(Issue #474: F01) uninitialized CubitSignalMixin.toString() returns '
      'ClassName(<uninitialized>) without throwing',
      () {
        final controller = _UninitializedMixinController();
        expect(
          controller.toString(),
          equals('_UninitializedMixinController(<uninitialized>)'),
        );
      },
    );

    test(
      '(Issue #474: F02) describeState overrides initialized toString() '
      'output',
      () async {
        final cubit = _RedactedStateCubit('secret-token');
        addTearDown(cubit.close);
        expect(
          cubit.toString(),
          equals('_RedactedStateCubit(***REDACTED***)'),
        );

        final bloc = _RedactedStateBloc('secret-bloc');
        addTearDown(bloc.close);
        expect(
          bloc.toString(),
          equals('_RedactedStateBloc(BLOC_REDACTED)'),
        );
      },
    );
  });
}
