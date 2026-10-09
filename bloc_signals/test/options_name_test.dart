// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'package:bloc_signals/bloc_signals.dart';
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

    group('(Issue #323: R9) SignalOptions lifecycle callbacks', () {
      test(
        '(Issue #323: R9) SignalOptions(watched, unwatched) does not fire on '
        'construction and fires on external subscribe/unsubscribe for '
        'CubitSignal and BlocSignal',
        () {
          var cubitWatched = 0;
          var cubitUnwatched = 0;
          final cubit = SampleCubit(
            options: SignalOptions<int>(
              watched: () => cubitWatched++,
              unwatched: () => cubitUnwatched++,
            ),
          );
          addTearDown(cubit.close);

          expect(cubitWatched, equals(0));
          expect(cubitUnwatched, equals(0));

          final disposeCubitSub = cubit.state.subscribe((_) {});
          expect(cubitWatched, equals(1));
          expect(cubitUnwatched, equals(0));

          disposeCubitSub();
          expect(cubit.isClosed, isFalse);
          expect(cubitUnwatched, equals(1));

          var blocWatched = 0;
          var blocUnwatched = 0;
          final bloc = SampleBloc(
            options: SignalOptions<int>(
              watched: () => blocWatched++,
              unwatched: () => blocUnwatched++,
            ),
          );
          addTearDown(bloc.close);

          expect(blocWatched, equals(0));
          expect(blocUnwatched, equals(0));

          final disposeBlocSub = bloc.state.subscribe((_) {});
          expect(blocWatched, equals(1));
          expect(blocUnwatched, equals(0));

          disposeBlocSub();
          expect(bloc.isClosed, isFalse);
          expect(blocUnwatched, equals(1));
        },
      );

      test(
        '(Issue #323: R9) SignalOptions(autoDispose: true) disposes state '
        'signal when external watchers detach while container is open',
        () {
          final cubit = SampleCubit(
            options: const SignalOptions<int>(autoDispose: true),
          );
          addTearDown(cubit.close);

          expect(cubit.state.disposed, isFalse);

          final unsubscribe = cubit.state.subscribe((_) {});
          expect(cubit.state.disposed, isFalse);

          unsubscribe();
          expect(cubit.isClosed, isFalse);
          expect(cubit.state.disposed, isTrue);
        },
      );
    });
  });
}
