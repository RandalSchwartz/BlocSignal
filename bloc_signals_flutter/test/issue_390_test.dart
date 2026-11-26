import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/foundation.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

class _CounterCubit extends CubitSignal<int> {
  _CounterCubit([int initial = 0]) : super(initialState: initial);

  void increment() => emit(stateValue + 1);

  void setValue(int value) => emit(value);
}

class _EffectSpyObserver extends SignalsObserver {
  final List<String?> effectNames = <String?>[];

  @override
  void onComputedCreated<T>(Computed<T> instance) {}

  @override
  void onComputedUpdated<T>(Computed<T> instance, T value) {}

  @override
  void onEffectCreated(Effect instance) {
    effectNames.add(instance.name);
  }

  @override
  void onSignalCreated<T>(Signal<T> instance, T value) {}

  @override
  void onSignalUpdated<T>(Signal<T> instance, T value) {}
}

void main() {
  group(
    'Issue #390: BlocSignalListener & BlocSignalConsumer execution quotas',
    () {
      testWidgets(
        '(Issue #390: take: 1) fires once and ignores subsequent emissions',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                take: 1,
                listener: (_, state) => observed.add(state),
              ),
            ),
          );

          cubit
            ..increment()
            ..increment()
            ..increment();
          await tester.pump();

          expect(observed, <int>[1]);
        },
      );

      testWidgets(
        '(Issue #390: take: 3) fires 3 times and detaches',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                take: 3,
                listener: (_, state) => observed.add(state),
              ),
            ),
          );

          for (var i = 0; i < 5; i++) {
            cubit.increment();
          }
          await tester.pump();

          expect(observed, <int>[1, 2, 3]);
        },
      );

      testWidgets(
        '(Issue #390: take: 0) fires 0 times and registers no subscription',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          final previousObserver = SignalsObserver.instance;
          final spy = _EffectSpyObserver();
          SignalsObserver.instance = spy;
          addTearDown(() => SignalsObserver.instance = previousObserver);

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                take: 0,
                listener: (_, state) => observed.add(state),
              ),
            ),
          );

          cubit
            ..increment()
            ..increment();
          await tester.pump();

          expect(observed, isEmpty);
          expect(
            spy.effectNames.where(
              (name) => name?.contains('BlocSignalListener') ?? false,
            ),
            isEmpty,
          );
        },
      );

      test(
        '(Issue #390: negative take) throws AssertionError on constructors',
        () {
          expect(
            () => BlocSignalListener<_CounterCubit, int>(
              take: -1,
              listener: (_, __) {},
            ),
            throwsAssertionError,
          );
          expect(
            () => BlocSignalListener<_CounterCubit, int>.transition(
              take: -2,
              listener: (_, __, ___) {},
            ),
            throwsAssertionError,
          );
          expect(
            () => BlocSignalConsumer<_CounterCubit, int>(
              take: -1,
              listener: (_, __) {},
              builder: (_, __) => const SizedBox.shrink(),
            ),
            throwsAssertionError,
          );
          expect(
            () => BlocSignalConsumer<_CounterCubit, int>.transition(
              take: -1,
              listener: (_, __, ___) {},
              builder: (_, __) => const SizedBox.shrink(),
            ),
            throwsAssertionError,
          );
          expect(
            () => BlocSignalConsumer<_CounterCubit, int>.child(
              take: -1,
              listener: (_, __) {},
              builder: (_, __, ___) => const SizedBox.shrink(),
            ),
            throwsAssertionError,
          );
        },
      );

      testWidgets(
        '(Issue #390: take + listenWhen) filtered emissions preserve budget',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                listenWhen: (_, current) => current.isEven,
                take: 2,
                listener: (_, state) => observed.add(state),
              ),
            ),
          );

          // 1 (filtered), 2 (taken 1/2), 3 (filtered), 4 (taken 2/2),
          // 6 (detached)
          cubit
            ..setValue(1)
            ..setValue(2)
            ..setValue(3)
            ..setValue(4)
            ..setValue(6);
          await tester.pump();

          expect(observed, <int>[2, 4]);
        },
      );

      testWidgets(
        '(Issue #390: takeWhile) fires while true and detaches on false',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                takeWhile: (state) => state < 3,
                listener: (_, state) => observed.add(state),
              ),
            ),
          );

          cubit
            ..setValue(1)
            ..setValue(2)
            ..setValue(3) // takeWhile false -> detach
            ..setValue(1); // stays detached even though 1 < 3
          await tester.pump();

          expect(observed, <int>[1, 2]);
        },
      );

      testWidgets(
        '(Issue #390: take + takeWhile) stops on whichever triggers first',
        (tester) async {
          final cubitA = _CounterCubit();
          final cubitB = _CounterCubit();
          addTearDown(cubitA.close);
          addTearDown(cubitB.close);
          final observedA = <int>[];
          final observedB = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Column(
                children: [
                  BlocSignalListener<_CounterCubit, int>(
                    bloc: cubitA,
                    take: 2,
                    takeWhile: (state) => state < 10,
                    listener: (_, state) => observedA.add(state),
                  ),
                  BlocSignalListener<_CounterCubit, int>(
                    bloc: cubitB,
                    take: 5,
                    takeWhile: (state) => state < 3,
                    listener: (_, state) => observedB.add(state),
                  ),
                ],
              ),
            ),
          );

          for (var i = 1; i <= 5; i++) {
            cubitA.setValue(i);
            cubitB.setValue(i);
          }
          await tester.pump();

          expect(observedA, <int>[1, 2]);
          expect(observedB, <int>[1, 2]);
        },
      );

      testWidgets(
        '(Issue #390: synchronous reentrant emit) with take: 1 fires once',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                take: 1,
                listener: (_, state) {
                  observed.add(state);
                  cubit.increment();
                },
              ),
            ),
          );

          cubit.increment();
          await tester.pump();

          expect(observed, <int>[1]);
          expect(cubit.stateValue, 2);
        },
      );

      testWidgets(
        '(Issue #390: MultiBlocSignalListener) preserves take and takeWhile',
        (tester) async {
          final cubitA = _CounterCubit();
          final cubitB = _CounterCubit();
          addTearDown(cubitA.close);
          addTearDown(cubitB.close);
          final observedA = <int>[];
          final observedB = <String>[];

          await tester.pumpWidget(
            MaterialApp(
              home: MultiBlocSignalListener(
                listeners: [
                  BlocSignalListener<_CounterCubit, int>(
                    bloc: cubitA,
                    take: 2,
                    listener: (_, state) => observedA.add(state),
                  ),
                  BlocSignalListener<_CounterCubit, int>.transition(
                    bloc: cubitB,
                    takeWhile: (state) => state <= 2,
                    listener: (_, prev, curr) => observedB.add('$prev->$curr'),
                  ),
                ],
                child: const SizedBox.shrink(),
              ),
            ),
          );

          for (var i = 1; i <= 4; i++) {
            cubitA.setValue(i);
            cubitB.setValue(i);
          }
          await tester.pump();

          expect(observedA, <int>[1, 2]);
          expect(observedB, <String>['0->1', '1->2']);
        },
      );

      testWidgets(
        '(Issue #390: BlocSignalConsumer) forwards take and takeWhile',
        (tester) async {
          final cubitDefault = _CounterCubit();
          final cubitTransition = _CounterCubit();
          final cubitChild = _CounterCubit();
          addTearDown(cubitDefault.close);
          addTearDown(cubitTransition.close);
          addTearDown(cubitChild.close);

          final observedDefault = <int>[];
          final observedTransition = <String>[];
          final observedChild = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Column(
                children: [
                  BlocSignalConsumer<_CounterCubit, int>(
                    bloc: cubitDefault,
                    take: 2,
                    listener: (_, state) => observedDefault.add(state),
                    builder: (_, state) => Text('D:$state'),
                  ),
                  BlocSignalConsumer<_CounterCubit, int>.transition(
                    bloc: cubitTransition,
                    take: 2,
                    takeWhile: (state) => state < 3,
                    listener: (_, prev, curr) =>
                        observedTransition.add('$prev->$curr'),
                    builder: (_, state) => Text('T:$state'),
                  ),
                  BlocSignalConsumer<_CounterCubit, int>.child(
                    bloc: cubitChild,
                    takeWhile: (state) => state < 2,
                    listener: (_, state) => observedChild.add(state),
                    child: const SizedBox.shrink(),
                    builder: (_, state, child) => Column(
                      children: [
                        if (child != null) child,
                        Text('C:$state'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          for (var i = 1; i <= 4; i++) {
            cubitDefault.setValue(i);
            cubitTransition.setValue(i);
            cubitChild.setValue(i);
          }
          await tester.pump();

          expect(observedDefault, <int>[1, 2]);
          expect(observedTransition, <String>['0->1', '1->2']);
          expect(observedChild, <int>[1]);
          expect(find.text('D:4'), findsOneWidget);
          expect(find.text('T:4'), findsOneWidget);
          expect(find.text('C:4'), findsOneWidget);
        },
      );

      testWidgets(
        '(Issue #390: lifecycle) rebuild, quota update, and bloc swap',
        (tester) async {
          final cubit1 = _CounterCubit();
          final cubit2 = _CounterCubit();
          addTearDown(cubit1.close);
          addTearDown(cubit2.close);
          final observed = <int>[];

          Widget buildTree({
            required _CounterCubit bloc,
            required int? take,
            required int parentTick,
          }) {
            return MaterialApp(
              home: Column(
                children: [
                  Text('tick:$parentTick'),
                  BlocSignalListener<_CounterCubit, int>(
                    bloc: bloc,
                    take: take,
                    listener: (_, state) => observed.add(state),
                  ),
                ],
              ),
            );
          }

          await tester.pumpWidget(
            buildTree(bloc: cubit1, take: 1, parentTick: 0),
          );
          cubit1
            ..setValue(1)
            ..setValue(2);
          await tester.pump();
          expect(observed, <int>[1]);

          // Unrelated parent rebuild must NOT resurrect detached listener.
          await tester.pumpWidget(
            buildTree(bloc: cubit1, take: 1, parentTick: 1),
          );
          cubit1.setValue(3);
          await tester.pump();
          expect(observed, <int>[1]);

          // Increasing take from 1 to 2 re-attaches for remaining budget.
          await tester.pumpWidget(
            buildTree(bloc: cubit1, take: 2, parentTick: 2),
          );
          cubit1
            ..setValue(4)
            ..setValue(5);
          await tester.pump();
          expect(observed, <int>[1, 4]);

          // Lowering take below _invocationCount detaches immediately.
          await tester.pumpWidget(
            buildTree(bloc: cubit1, take: 1, parentTick: 3),
          );
          cubit1.setValue(6);
          await tester.pump();
          expect(observed, <int>[1, 4]);

          // Swapping bloc resets quota and attaches to new bloc.
          await tester.pumpWidget(
            buildTree(bloc: cubit2, take: 2, parentTick: 4),
          );
          cubit2
            ..setValue(10)
            ..setValue(20)
            ..setValue(30);
          await tester.pump();
          expect(observed, <int>[1, 4, 10, 20]);
        },
      );

      testWidgets(
        '(Issue #390: dispose) cleans up before quota completion',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                take: 5,
                listener: (_, state) => observed.add(state),
              ),
            ),
          );

          cubit.increment();
          await tester.pump();
          expect(observed, <int>[1]);

          // Dispose listener before quota completes.
          await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          cubit
            ..increment()
            ..increment();
          await tester.pump();

          expect(observed, <int>[1]);
        },
      );

      test(
        '(Issue #390: debugFillProperties) includes take and takeWhile',
        () {
          bool predicate(int s) => s < 5;

          final listener = BlocSignalListener<_CounterCubit, int>(
            take: 3,
            takeWhile: predicate,
            listener: (_, __) {},
          );
          final listenerBuilder = DiagnosticPropertiesBuilder();
          listener.debugFillProperties(listenerBuilder);
          final listenerProps =
              listenerBuilder.properties.map((p) => p.name).toList();
          expect(listenerProps, containsAll(<String>['take', 'takeWhile']));

          final consumer = BlocSignalConsumer<_CounterCubit, int>(
            take: 2,
            takeWhile: predicate,
            listener: (_, __) {},
            builder: (_, __) => const SizedBox.shrink(),
          );
          final consumerBuilder = DiagnosticPropertiesBuilder();
          consumer.debugFillProperties(consumerBuilder);
          final consumerProps =
              consumerBuilder.properties.map((p) => p.name).toList();
          expect(consumerProps, containsAll(<String>['take', 'takeWhile']));
        },
      );

      testWidgets(
        '(Issue #390: takeWhile) stays permanently detached across unrelated '
        'parent rebuilds with new inline closure',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          Widget buildTree({required int parentTick}) {
            return MaterialApp(
              home: Column(
                children: [
                  Text('tick:$parentTick'),
                  BlocSignalListener<_CounterCubit, int>(
                    bloc: cubit,
                    // Capturing parentTick forces a distinct closure instance
                    // on every parent rebuild.
                    takeWhile: (state) => parentTick >= 0 && state < 3,
                    listener: (_, state) => observed.add(state),
                  ),
                ],
              ),
            );
          }

          await tester.pumpWidget(buildTree(parentTick: 0));
          cubit
            ..setValue(1)
            ..setValue(2)
            ..setValue(3); // takeWhile false -> permanent detach
          await tester.pump();
          expect(observed, <int>[1, 2]);

          // Parent rebuilds with a fresh closure instance; must stay detached.
          await tester.pumpWidget(buildTree(parentTick: 1));
          cubit.setValue(1);
          await tester.pump();
          expect(observed, <int>[1, 2]);
        },
      );

      testWidgets(
        '(Issue #390: takeWhile) stays detached when take expands or is '
        'removed, and re-activates only when takeWhile is explicitly null',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];

          Widget buildTree({
            required int? take,
            required bool Function(int state)? takeWhile,
          }) {
            return MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                take: take,
                takeWhile: takeWhile,
                listener: (_, state) => observed.add(state),
              ),
            );
          }

          await tester.pumpWidget(
            buildTree(take: 5, takeWhile: (state) => state < 3),
          );
          cubit
            ..setValue(1)
            ..setValue(2)
            ..setValue(3); // takeWhile false -> detach
          await tester.pump();
          expect(observed, <int>[1, 2]);

          // Expanding take while takeWhile remains must keep listener detached.
          await tester.pumpWidget(
            buildTree(take: 10, takeWhile: (state) => state < 3),
          );
          cubit.setValue(1);
          await tester.pump();
          expect(observed, <int>[1, 2]);

          // Removing take while takeWhile remains must keep listener detached.
          await tester.pumpWidget(
            buildTree(take: null, takeWhile: (state) => state < 3),
          );
          cubit.setValue(1);
          await tester.pump();
          expect(observed, <int>[1, 2]);

          // Explicitly removing takeWhile (null) re-activates if take allows.
          await tester.pumpWidget(
            buildTree(take: 5, takeWhile: null),
          );
          cubit
            ..setValue(4)
            ..setValue(5);
          await tester.pump();
          expect(observed, <int>[1, 2, 4, 5]);
        },
      );

      testWidgets(
        '(Issue #390: takeWhile + listenWhen) filtered emissions do not '
        'evaluate or detach takeWhile',
        (tester) async {
          final cubit = _CounterCubit();
          addTearDown(cubit.close);
          final observed = <int>[];
          final evaluatedTakeWhile = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                listenWhen: (_, current) => current.isEven,
                takeWhile: (state) {
                  evaluatedTakeWhile.add(state);
                  return state < 5;
                },
                listener: (_, state) => observed.add(state),
              ),
            ),
          );

          // 7 is odd (listenWhen false -> must not evaluate takeWhile or
          // detach), 2 and 4 are even and < 5 (taken), 6 is even and >= 5
          // (evaluates takeWhile -> false -> detach), 2 is ignored.
          cubit
            ..setValue(7)
            ..setValue(2)
            ..setValue(9)
            ..setValue(4)
            ..setValue(6)
            ..setValue(2);
          await tester.pump();

          expect(evaluatedTakeWhile, <int>[2, 4, 6]);
          expect(observed, <int>[2, 4]);
        },
      );

      testWidgets(
        '(Issue #390: dispose) cleans up cleanly after take exhaustion and '
        'after takeWhile detachment',
        (tester) async {
          final cubitTake = _CounterCubit();
          final cubitTakeWhile = _CounterCubit();
          addTearDown(cubitTake.close);
          addTearDown(cubitTakeWhile.close);
          final observedTake = <int>[];
          final observedTakeWhile = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: Column(
                children: [
                  BlocSignalListener<_CounterCubit, int>(
                    bloc: cubitTake,
                    take: 1,
                    listener: (_, state) => observedTake.add(state),
                  ),
                  BlocSignalListener<_CounterCubit, int>(
                    bloc: cubitTakeWhile,
                    takeWhile: (state) => state < 2,
                    listener: (_, state) => observedTakeWhile.add(state),
                  ),
                ],
              ),
            ),
          );

          cubitTake.setValue(1); // take exhausted -> #Detached
          cubitTakeWhile
            ..setValue(1)
            ..setValue(2); // takeWhile false -> #Detached
          await tester.pump();

          expect(observedTake, <int>[1]);
          expect(observedTakeWhile, <int>[1]);

          // #Detached -> #Disposed
          await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          cubitTake.setValue(2);
          cubitTakeWhile.setValue(1);
          await tester.pump();

          expect(tester.takeException(), isNull);
          expect(observedTake, <int>[1]);
          expect(observedTakeWhile, <int>[1]);
        },
      );
    },
  );
}
