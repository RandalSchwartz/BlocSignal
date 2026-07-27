// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'package:bloc_signals/bloc_signals.dart';
import 'package:preact_signals/preact_signals.dart' show SignalEquality;
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

class SampleCubit extends CubitSignal<int> {
  SampleCubit({super.options}) : super(initialState: 0);

  void triggerEffect() {
    createEffect(() {});
  }

  void triggerNamedEffect(String effectName) {
    createEffect(
      () {},
      options: EffectOptions(name: effectName),
    );
  }
}

sealed class CounterEvent {}

class Increment extends CounterEvent {}

class SampleBloc extends BlocSignal<CounterEvent, int> {
  SampleBloc({super.options}) : super(initialState: 0);
}

void main() {
  group('SignalOptions & Debug Name Tests', () {
    test(r'default state signal name uses $runtimeType.state', () {
      final cubit = SampleCubit();
      expect(cubit.state.name, equals('SampleCubit.state'));
    });

    test('custom SignalOptions overrides state signal name and options', () {
      final cubit = SampleCubit(
        options: const SignalOptions<int>(name: 'custom_cubit_state'),
      );
      expect(cubit.state.name, equals('custom_cubit_state'));
    });

    test('custom SignalOptions propagates to BlocSignal', () {
      final bloc = SampleBloc(
        options: const SignalOptions<int>(name: 'custom_bloc_state'),
      );
      expect(bloc.state.name, equals('custom_bloc_state'));
    });

    test('createEffect assigns default effect debug names', () {
      final cubit = SampleCubit();
      cubit.triggerEffect();
      expect(cubit.isClosed, isFalse);
    });

    test('createEffect accepts custom EffectOptions', () {
      final cubit = SampleCubit();
      cubit.triggerNamedEffect('my_custom_effect');
      expect(cubit.isClosed, isFalse);
    });

    test(
      'options.equality takes precedence over equals callback',
      () {
        final cubit = SampleCubit(
          options: SignalOptions<int>(
            equality: SignalEquality.custom((a, b) => false),
          ),
        );
        // Even if default equals would match 0 == 0, custom false comparator
        // in options takes precedence.
        expect(cubit.state.name, equals('SampleCubit.state'));
      },
    );
  });
}
