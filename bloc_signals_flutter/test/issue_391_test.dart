import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _CounterCubit extends CubitSignal<int> {
  _CounterCubit([int initial = 0]) : super(initialState: initial);

  void set(int value) => emit(value);
}

List<int> _providerSwapReceived = <int>[];

class _ConstDebouncedSubtree extends StatelessWidget {
  const _ConstDebouncedSubtree();

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<_CounterCubit, int>.debounce(
      duration: const Duration(milliseconds: 100),
      listener: (_, state) => _providerSwapReceived.add(state),
    );
  }
}

class _ConstThrottledSubtree extends StatelessWidget {
  const _ConstThrottledSubtree();

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<_CounterCubit, int>.throttle(
      duration: const Duration(milliseconds: 200),
      listener: (_, state) => _providerSwapReceived.add(state),
    );
  }
}

void main() {
  group('Issue #391: BlocSignalListener debounce and throttle', () {
    testWidgets(
      'BlocSignalListener.debounce suppresses rapid emissions and fires once '
      'after quiet window',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final received = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.debounce(
            bloc: cubit,
            duration: const Duration(milliseconds: 100),
            listener: (context, state) => received.add(state),
          ),
        );

        cubit.set(1);
        await tester.pump(const Duration(milliseconds: 50));
        expect(received, isEmpty);

        cubit.set(2);
        await tester.pump(const Duration(milliseconds: 50));
        expect(received, isEmpty);

        cubit.set(3);
        await tester.pump(const Duration(milliseconds: 99));
        expect(received, isEmpty);

        await tester.pump(const Duration(milliseconds: 1));
        expect(received, [3]);
      },
    );

    testWidgets(
      'debounce: parameter on .transition preserves baseline previous state',
      (tester) async {
        final cubit = _CounterCubit(10);
        addTearDown(cubit.close);
        final transitions = <(int, int)>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.transition(
            bloc: cubit,
            debounce: const Duration(milliseconds: 100),
            listener: (context, previous, current) =>
                transitions.add((previous, current)),
          ),
        );

        cubit.set(11);
        await tester.pump(const Duration(milliseconds: 40));
        cubit.set(12);
        await tester.pump(const Duration(milliseconds: 40));
        cubit.set(13);
        await tester.pump(const Duration(milliseconds: 100));

        expect(transitions, [(10, 13)]);

        // Next debounce window starts from 13.
        cubit.set(14);
        await tester.pump(const Duration(milliseconds: 100));
        expect(transitions, [(10, 13), (13, 14)]);
      },
    );

    testWidgets(
      'BlocSignalListener.throttle fires immediately on leading edge, '
      'suppresses within window, and fires again after cooldown',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final received = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.throttle(
            bloc: cubit,
            duration: const Duration(milliseconds: 100),
            listener: (context, state) => received.add(state),
          ),
        );

        cubit.set(1);
        expect(received, [1]);

        await tester.pump(const Duration(milliseconds: 50));
        cubit.set(2);
        expect(received, [1]);

        await tester.pump(const Duration(milliseconds: 50));
        // Cooldown of 100ms has now elapsed.
        cubit.set(3);
        expect(received, [1, 3]);

        // Drain remaining throttle timer cleanly.
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    testWidgets(
      'throttle: parameter works with listenWhen, take, and takeWhile',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final received = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>(
            bloc: cubit,
            throttle: const Duration(milliseconds: 100),
            listenWhen: (previous, current) => current.isEven,
            take: 2,
            takeWhile: (state) => state < 10,
            listener: (context, state) => received.add(state),
          ),
        );

        // Filtered out by listenWhen; does not arm throttle or consume take.
        cubit.set(1);
        expect(received, isEmpty);

        // Matches listenWhen; fires immediately and arms throttle.
        cubit.set(2);
        expect(received, [2]);

        // Suppressed by throttle.
        cubit.set(4);
        expect(received, [2]);

        await tester.pump(const Duration(milliseconds: 100));

        // Fires second time, exhausting take: 2.
        cubit.set(6);
        expect(received, [2, 6]);

        await tester.pump(const Duration(milliseconds: 100));
        cubit.set(8);
        expect(received, [2, 6]);
      },
    );

    testWidgets(
      'debounce works with listenWhen, take, and takeWhile',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final received = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>(
            bloc: cubit,
            debounce: const Duration(milliseconds: 50),
            listenWhen: (previous, current) => current.isEven,
            takeWhile: (state) => state < 10,
            listener: (context, state) => received.add(state),
          ),
        );

        cubit.set(2);
        await tester.pump(const Duration(milliseconds: 50));
        expect(received, [2]);

        // 10 fails takeWhile when timer fires, detaching permanently.
        cubit.set(10);
        await tester.pump(const Duration(milliseconds: 50));
        expect(received, [2]);

        cubit.set(4);
        await tester.pump(const Duration(milliseconds: 50));
        expect(received, [2]);
      },
    );

    testWidgets(
      'MultiBlocSignalListener preserves debounce and throttle via copyWith',
      (tester) async {
        final cubit1 = _CounterCubit();
        final cubit2 = _CounterCubit();
        addTearDown(() {
          unawaited(cubit1.close());
          unawaited(cubit2.close());
        });
        final received1 = <int>[];
        final received2 = <int>[];

        await tester.pumpWidget(
          MultiBlocSignalListener(
            listeners: [
              BlocSignalListener<_CounterCubit, int>.debounce(
                bloc: cubit1,
                duration: const Duration(milliseconds: 50),
                listener: (context, state) => received1.add(state),
              ),
              BlocSignalListener<_CounterCubit, int>.throttle(
                bloc: cubit2,
                duration: const Duration(milliseconds: 50),
                listener: (context, state) => received2.add(state),
              ),
            ],
            child: const SizedBox.shrink(),
          ),
        );

        cubit1
          ..set(1)
          ..set(2);
        cubit2
          ..set(10)
          ..set(20);

        expect(received1, isEmpty);
        expect(received2, [10]);

        await tester.pump(const Duration(milliseconds: 50));
        expect(received1, [2]);
      },
    );

    testWidgets(
      'BlocSignalConsumer default, .transition, and .child forward '
      'debounce and throttle',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final defaultEvents = <int>[];
        final transitionEvents = <(int, int)>[];
        final childEvents = <int>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                BlocSignalConsumer<_CounterCubit, int>(
                  bloc: cubit,
                  debounce: const Duration(milliseconds: 50),
                  listener: (context, state) => defaultEvents.add(state),
                  builder: (context, state) => Text('$state'),
                ),
                BlocSignalConsumer<_CounterCubit, int>.transition(
                  bloc: cubit,
                  debounce: const Duration(milliseconds: 50),
                  listener: (context, prev, curr) =>
                      transitionEvents.add((prev, curr)),
                  builder: (context, state) => Text('$state'),
                ),
                BlocSignalConsumer<_CounterCubit, int>.child(
                  bloc: cubit,
                  throttle: const Duration(milliseconds: 50),
                  listener: (context, state) => childEvents.add(state),
                  builder: (context, state, child) => child!,
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );

        cubit
          ..set(1)
          ..set(2);
        expect(defaultEvents, isEmpty);
        expect(transitionEvents, isEmpty);
        expect(childEvents, [1]);

        await tester.pump(const Duration(milliseconds: 50));
        expect(defaultEvents, [2]);
        expect(transitionEvents, [(0, 2)]);
      },
    );

    testWidgets(
      'dispose cancels pending debounce and throttle timers cleanly',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final received = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.debounce(
            bloc: cubit,
            duration: const Duration(milliseconds: 100),
            listener: (context, state) => received.add(state),
          ),
        );

        cubit.set(1);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 150));
        expect(received, isEmpty);
      },
    );

    testWidgets(
      'bloc instance swap cancels pending timer cleanly',
      (tester) async {
        final cubit1 = _CounterCubit();
        final cubit2 = _CounterCubit();
        addTearDown(() {
          unawaited(cubit1.close());
          unawaited(cubit2.close());
        });
        final received = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.debounce(
            bloc: cubit1,
            duration: const Duration(milliseconds: 100),
            listener: (context, state) => received.add(state),
          ),
        );

        cubit1.set(1);

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.debounce(
            bloc: cubit2,
            duration: const Duration(milliseconds: 100),
            listener: (context, state) => received.add(state),
          ),
        );

        await tester.pump(const Duration(milliseconds: 150));
        expect(received, isEmpty);

        cubit2.set(42);
        await tester.pump(const Duration(milliseconds: 100));
        expect(received, [42]);
      },
    );

    testWidgets(
      'didUpdateWidget cancels pending timer when debounce or throttle changes',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final received = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>(
            bloc: cubit,
            debounce: const Duration(milliseconds: 100),
            listener: (context, state) => received.add(state),
          ),
        );

        cubit.set(1);

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>(
            bloc: cubit,
            throttle: const Duration(milliseconds: 100),
            listener: (context, state) => received.add(state),
          ),
        );

        await tester.pump(const Duration(milliseconds: 150));
        expect(received, isEmpty);
      },
    );

    test('assertions and debugFillProperties', () {
      expect(
        () => BlocSignalListener<_CounterCubit, int>(
          debounce: const Duration(milliseconds: 10),
          throttle: const Duration(milliseconds: 10),
          listener: (_, __) {},
        ),
        throwsAssertionError,
      );
      expect(
        () => BlocSignalConsumer<_CounterCubit, int>(
          debounce: const Duration(milliseconds: 10),
          throttle: const Duration(milliseconds: 10),
          listener: (_, __) {},
          builder: (_, __) => const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );

      final listenerBuilder = DiagnosticPropertiesBuilder();
      BlocSignalListener<_CounterCubit, int>(
        debounce: const Duration(milliseconds: 50),
        listener: (_, __) {},
      ).debugFillProperties(listenerBuilder);
      expect(
        listenerBuilder.properties.any((p) => p.name == 'debounce'),
        isTrue,
      );

      final consumerBuilder = DiagnosticPropertiesBuilder();
      BlocSignalConsumer<_CounterCubit, int>(
        throttle: const Duration(milliseconds: 50),
        listener: (_, __) {},
        builder: (_, __) => const SizedBox.shrink(),
      ).debugFillProperties(consumerBuilder);
      expect(
        consumerBuilder.properties.any((p) => p.name == 'throttle'),
        isTrue,
      );
    });

    testWidgets(
      'throttled listener cancels active cooldown timer on dispose, bloc swap, '
      'and didUpdateWidget',
      (tester) async {
        final cubit1 = _CounterCubit();
        final cubit2 = _CounterCubit();
        addTearDown(cubit1.close);
        addTearDown(cubit2.close);
        final received = <int>[];

        // 1. dispose() with active throttle cooldown timer.
        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.throttle(
            bloc: cubit1,
            duration: const Duration(milliseconds: 200),
            listener: (_, state) => received.add(state),
          ),
        );
        cubit1.set(1);
        expect(received, [1]);
        await tester.pumpWidget(const SizedBox.shrink());

        // 2. bloc instance swap (!identical) with active throttle cooldown
        // timer.
        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.throttle(
            bloc: cubit1,
            duration: const Duration(milliseconds: 200),
            listener: (_, state) => received.add(state),
          ),
        );
        cubit1.set(2);
        expect(received, [1, 2]);
        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.throttle(
            bloc: cubit2,
            duration: const Duration(milliseconds: 200),
            listener: (_, state) => received.add(state),
          ),
        );
        cubit2.set(10);
        expect(received, [1, 2, 10]);

        // 3. didUpdateWidget: throttle -> null.
        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>(
            bloc: cubit2,
            listener: (_, state) => received.add(state),
          ),
        );
        cubit2.set(11);
        expect(received, [1, 2, 10, 11]);

        // 4. didUpdateWidget: throttle -> debounce.
        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.throttle(
            bloc: cubit2,
            duration: const Duration(milliseconds: 200),
            listener: (_, state) => received.add(state),
          ),
        );
        cubit2.set(12);
        expect(received, [1, 2, 10, 11, 12]);
        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.debounce(
            bloc: cubit2,
            duration: const Duration(milliseconds: 50),
            listener: (_, state) => received.add(state),
          ),
        );
        cubit2.set(13);
        expect(received, [1, 2, 10, 11, 12]);
        await tester.pump(const Duration(milliseconds: 50));
        expect(received, [1, 2, 10, 11, 12, 13]);
      },
    );

    testWidgets(
      'take + listenWhen rejection under debounce and takeWhile false under '
      'throttle',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final debounced = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.debounce(
            bloc: cubit,
            duration: const Duration(milliseconds: 50),
            take: 1,
            listenWhen: (_, current) => current.isEven,
            listener: (_, state) => debounced.add(state),
          ),
        );

        // Odd state is rejected by listenWhen and does not consume take budget.
        cubit.set(1);
        await tester.pump(const Duration(milliseconds: 50));
        expect(debounced, isEmpty);

        // Even state passes listenWhen, fires after debounce, and exhausts
        // take.
        cubit.set(2);
        await tester.pump(const Duration(milliseconds: 50));
        expect(debounced, [2]);

        cubit.set(4);
        await tester.pump(const Duration(milliseconds: 50));
        expect(debounced, [2]);

        // takeWhile returning false under throttle detaches immediately.
        final throttled = <int>[];
        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.throttle(
            bloc: cubit,
            duration: const Duration(milliseconds: 50),
            takeWhile: (state) => state < 10,
            listener: (_, state) => throttled.add(state),
          ),
        );

        cubit.set(6);
        expect(throttled, [6]);
        await tester.pump(const Duration(milliseconds: 50));

        cubit.set(10);
        expect(throttled, [6]);

        cubit.set(7);
        expect(throttled, [6]);
      },
    );

    test('mutual-exclusion assertions on transition and child constructors',
        () {
      expect(
        () => BlocSignalListener<_CounterCubit, int>.transition(
          debounce: const Duration(milliseconds: 10),
          throttle: const Duration(milliseconds: 10),
          listener: (_, __, ___) {},
        ),
        throwsAssertionError,
      );
      expect(
        () => BlocSignalConsumer<_CounterCubit, int>.transition(
          debounce: const Duration(milliseconds: 10),
          throttle: const Duration(milliseconds: 10),
          listener: (_, __, ___) {},
          builder: (_, __) => const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );
      expect(
        () => BlocSignalConsumer<_CounterCubit, int>.child(
          debounce: const Duration(milliseconds: 10),
          throttle: const Duration(milliseconds: 10),
          listener: (_, __) {},
          builder: (_, __, ___) => const SizedBox.shrink(),
          child: const SizedBox.shrink(),
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'negative Duration throws ArgumentError on BlocSignalListener and '
      'BlocSignalConsumer',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        const neg = Duration(milliseconds: -1);

        final widgets = <Widget>[
          BlocSignalListener<_CounterCubit, int>(
            bloc: cubit,
            debounce: neg,
            listener: (_, __) {},
          ),
          BlocSignalListener<_CounterCubit, int>(
            bloc: cubit,
            throttle: neg,
            listener: (_, __) {},
          ),
          BlocSignalListener<_CounterCubit, int>.debounce(
            bloc: cubit,
            duration: neg,
            listener: (_, __) {},
          ),
          BlocSignalListener<_CounterCubit, int>.throttle(
            bloc: cubit,
            duration: neg,
            listener: (_, __) {},
          ),
          BlocSignalListener<_CounterCubit, int>.transition(
            bloc: cubit,
            debounce: neg,
            listener: (_, __, ___) {},
          ),
          BlocSignalConsumer<_CounterCubit, int>(
            bloc: cubit,
            throttle: neg,
            listener: (_, __) {},
            builder: (_, __) => const SizedBox.shrink(),
          ),
        ];

        for (final widget in widgets) {
          await tester.pumpWidget(widget);
          expect(tester.takeException(), isArgumentError);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );

    testWidgets(
      '(Issue #391: BLOCKER-1) reentrant emit inside throttled listener '
      'respects cooldown and leaks zero timers on dispose',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        final received = <int>[];

        await tester.pumpWidget(
          BlocSignalListener<_CounterCubit, int>.throttle(
            bloc: cubit,
            duration: const Duration(milliseconds: 100),
            listener: (_, state) {
              received.add(state);
              if (state == 1) {
                // Synchronous reentrant emission must be suppressed by the
                // already-armed cooldown timer.
                cubit.set(2);
              }
            },
          ),
        );

        cubit.set(1);
        expect(received, [1]);

        // Dispose while the throttle cooldown timer is active; flutter_test
        // will fail if any timer leaks.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 150));
        expect(received, [1]);
      },
    );

    testWidgets(
      '(Issue #391: BLOCKER-2) didChangeDependencies provider swap with '
      'bloc: null cancels pending debounce timer and observes new cubit',
      (tester) async {
        _providerSwapReceived = <int>[];
        addTearDown(() => _providerSwapReceived = <int>[]);

        final cubit1 = _CounterCubit();
        final cubit2 = _CounterCubit();
        addTearDown(() {
          unawaited(cubit1.close());
          unawaited(cubit2.close());
        });

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>.value(
            value: cubit1,
            child: const _ConstDebouncedSubtree(),
          ),
        );

        // Arm pending debounce timer on cubit1.
        cubit1.set(1);

        // Swap provided cubit beneath const subtree (exercises
        // didChangeDependencies, not didUpdateWidget).
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>.value(
            value: cubit2,
            child: const _ConstDebouncedSubtree(),
          ),
        );

        // Pending timer from cubit1 must have been cancelled without firing.
        await tester.pump(const Duration(milliseconds: 150));
        expect(_providerSwapReceived, isEmpty);

        // Emissions on old cubit1 are ignored; new cubit2 is observed.
        cubit1.set(99);
        cubit2.set(42);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_providerSwapReceived, [42]);

        // Arm another debounce timer and dispose without draining to verify
        // zero leaked timers.
        cubit2.set(43);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      '(Issue #391: BLOCKER-2) didChangeDependencies provider swap with '
      'bloc: null cancels active throttle timer and observes new cubit',
      (tester) async {
        _providerSwapReceived = <int>[];
        addTearDown(() => _providerSwapReceived = <int>[]);

        final cubit1 = _CounterCubit();
        final cubit2 = _CounterCubit();
        addTearDown(() {
          unawaited(cubit1.close());
          unawaited(cubit2.close());
        });

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>.value(
            value: cubit1,
            child: const _ConstThrottledSubtree(),
          ),
        );

        // Fire leading edge on cubit1 and arm 200ms throttle cooldown timer.
        cubit1.set(1);
        expect(_providerSwapReceived, [1]);

        // Swap provided cubit beneath const subtree (exercises
        // didChangeDependencies, not didUpdateWidget).
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>.value(
            value: cubit2,
            child: const _ConstThrottledSubtree(),
          ),
        );

        // Old cubit1 is no longer observed; new cubit2 fires immediately
        // because cubit1's cooldown timer was cancelled on swap.
        cubit1.set(2);
        cubit2.set(10);
        expect(_providerSwapReceived, [1, 10]);

        // Dispose while cubit2's throttle timer is active to verify zero
        // leaked timers.
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
