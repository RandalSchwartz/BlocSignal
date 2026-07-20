import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

sealed class CounterEvent {}

class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent event) {
    unawaited(Future.value(super.onEvent(event)));
    switch (event) {
      case Increment():
        emit(stateValue + 1);
    }
  }
}

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

void main() {
  group('BlocSignal Flutter Bindings Tests', () {
    testWidgets('BlocSignalProvider injects and disposes BlocSignal', (
      tester,
    ) async {
      late CounterBloc bloc;

      final widget = BlocSignalProvider<CounterBloc>(
        create: (context) => bloc = CounterBloc(),
        child: Builder(
          builder: (context) {
            final retrievedBloc = context.read<CounterBloc>();
            expect(retrievedBloc, equals(bloc));
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(MaterialApp(home: widget));

      // Ensure the widget builds
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('BlocSignalBuilder rebuilds dynamically on state change', (
      tester,
    ) async {
      final bloc = CounterBloc();

      final widget = MaterialApp(
        home: Scaffold(
          body: BlocSignalBuilder<CounterBloc, int>(
            bloc: bloc,
            builder: (context, state) {
              return Text('Count: $state');
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('Count: 0'), findsOneWidget);

      bloc.add(Increment());
      await tester.pump(); // Pump frame to trigger watch rebuild

      expect(find.text('Count: 1'), findsOneWidget);
      bloc.close();
    });

    testWidgets(
      'BlocSignalBuilder reacts to provided bloc changes',
      (tester) async {
        final bloc1 = CounterBloc();
        final bloc2 = CounterBloc()..emit(42);

        final builderWidget = BlocSignalBuilder<CounterBloc, int>(
          builder: (context, state) {
            return Text('Count: $state');
          },
        );

        Widget buildWidget(CounterBloc bloc) {
          return BlocSignalProvider<CounterBloc>.value(
            value: bloc,
            child: builderWidget,
          );
        }

        await tester.pumpWidget(MaterialApp(home: buildWidget(bloc1)));
        expect(find.text('Count: 0'), findsOneWidget);

        // Rebuild with bloc2
        await tester.pumpWidget(MaterialApp(home: buildWidget(bloc2)));
        expect(find.text('Count: 42'), findsOneWidget);

        bloc1.close();
        bloc2.close();
      },
    );

    testWidgets('MultiBlocSignalProvider provides multiple blocs', (
      tester,
    ) async {
      final bloc = CounterBloc();
      final widget = MaterialApp(
        home: MultiBlocSignalProvider(
          providers: [
            BlocSignalProvider<CounterBloc>(
              create: (_) => CounterBloc(),
              child: const SizedBox(),
            ),
            BlocSignalProvider<CounterBloc>.value(
              value: bloc,
              child: const SizedBox(),
            ),
          ],
          child: Builder(
            builder: (context) {
              final counterBloc = context.read<CounterBloc>();
              expect(counterBloc, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.byType(SizedBox), findsOneWidget);
      bloc.close();
    });

    testWidgets(
      'BlocSignalProvider.value injects existing bloc without closing it',
      (tester) async {
        final bloc = CounterBloc();

        final widget = BlocSignalProvider<CounterBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) {
              final retrievedBloc = context.read<CounterBloc>();
              expect(retrievedBloc, equals(bloc));
              return const SizedBox();
            },
          ),
        );

        await tester.pumpWidget(MaterialApp(home: widget));
        expect(find.byType(SizedBox), findsOneWidget);

        // Verify that disposing the provider does not close the bloc
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        bloc.add(Increment());
        expect(bloc.stateValue, equals(1));
        bloc.close();
      },
    );

    testWidgets(
      'context.watch listens and rebuilds when the bloc instance changes',
      (tester) async {
        final bloc1 = CounterBloc();
        final bloc2 = CounterBloc()..emit(42);

        final widget1 = BlocSignalProvider<CounterBloc>.value(
          value: bloc1,
          child: Builder(
            builder: (context) {
              final watchedBloc = context.watch<CounterBloc>();
              return Text('Value: ${watchedBloc.stateValue}');
            },
          ),
        );

        await tester.pumpWidget(MaterialApp(home: widget1));
        expect(find.text('Value: 0'), findsOneWidget);

        final widget2 = BlocSignalProvider<CounterBloc>.value(
          value: bloc2,
          child: Builder(
            builder: (context) {
              final watchedBloc = context.watch<CounterBloc>();
              return Text('Value: ${watchedBloc.stateValue}');
            },
          ),
        );

        await tester.pumpWidget(MaterialApp(home: widget2));
        expect(find.text('Value: 42'), findsOneWidget);

        bloc1.close();
        bloc2.close();
      },
    );

    testWidgets(
      'BlocSignalProvider.of throws FlutterError when not found in context',
      (tester) async {
        final widget = MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => context.read<CounterBloc>(),
                throwsA(isA<FlutterError>()),
              );
              return const SizedBox();
            },
          ),
        );

        await tester.pumpWidget(widget);
        expect(find.byType(SizedBox), findsOneWidget);
      },
    );

    testWidgets(
        'CubitSignal works with BlocSignalProvider and BlocSignalBuilder', (
      tester,
    ) async {
      final cubit = CounterCubit();

      final widget = MaterialApp(
        home: BlocSignalProvider<CounterCubit>.value(
          value: cubit,
          child: Scaffold(
            body: BlocSignalBuilder<CounterCubit, int>(
              builder: (context, state) {
                final readCubit = context.read<CounterCubit>();
                expect(readCubit, equals(cubit));
                return Text('Count: $state');
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('Count: 0'), findsOneWidget);

      cubit.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
      cubit.close();
    });

    testWidgets('BlocSignalListener triggers callback on state changes', (
      tester,
    ) async {
      final bloc = CounterBloc();
      final states = <int>[];

      final widget = MaterialApp(
        home: BlocSignalListener<CounterBloc, int>(
          bloc: bloc,
          listener: (context, state) {
            states.add(state);
          },
          child: const SizedBox(),
        ),
      );

      await tester.pumpWidget(widget);
      // Under the hood, SignalListener runs the effect immediately on mount.
      expect(states, equals([0]));

      bloc.add(Increment());
      await tester.pump();
      expect(states, equals([0, 1]));

      bloc.close();
    });

    testWidgets('BlocSignalConsumer both builds and listens', (
      tester,
    ) async {
      final bloc = CounterBloc();
      final states = <int>[];

      final widget = MaterialApp(
        home: BlocSignalConsumer<CounterBloc, int>(
          bloc: bloc,
          listener: (context, state) {
            states.add(state);
          },
          builder: (context, state) {
            return Text('Consumer Count: $state');
          },
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('Consumer Count: 0'), findsOneWidget);
      expect(states, equals([0]));

      bloc.add(Increment());
      await tester.pump();

      expect(find.text('Consumer Count: 1'), findsOneWidget);
      expect(states, equals([0, 1]));

      bloc.close();
    });

    testWidgets(
        'BlocSignalSelector only rebuilds when selected sub-state changes', (
      tester,
    ) async {
      final cubit = CounterCubit();
      var builds = 0;

      final widget = MaterialApp(
        home: BlocSignalSelector<CounterCubit, int, bool>(
          bloc: cubit,
          selector: (state) => state >= 2,
          builder: (context, isGreaterOrEqualTwo) {
            builds++;
            return Text('GEQ2: $isGreaterOrEqualTwo');
          },
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('GEQ2: false'), findsOneWidget);
      expect(builds, equals(1));

      // Change state from 0 to 1 -> isGreaterOrEqualTwo is still false
      cubit.increment();
      await tester.pump();
      expect(find.text('GEQ2: false'), findsOneWidget);
      expect(builds, equals(1)); // No rebuild: selection didn't change

      // Change state from 1 to 2 -> isGreaterOrEqualTwo becomes true
      cubit.increment();
      await tester.pump();
      expect(find.text('GEQ2: true'), findsOneWidget);
      expect(builds, equals(2)); // Rebuilt!

      cubit.close();
    });

    testWidgets(
      'BlocSignalListener reacts to provided bloc changes',
      (tester) async {
        final bloc1 = CounterBloc();
        final bloc2 = CounterBloc()..emit(42);
        final states = <int>[];

        Widget buildWidget(CounterBloc bloc) {
          return BlocSignalProvider<CounterBloc>.value(
            value: bloc,
            child: BlocSignalListener<CounterBloc, int>(
              listener: (context, state) {
                states.add(state);
              },
              child: const SizedBox(),
            ),
          );
        }

        await tester.pumpWidget(MaterialApp(home: buildWidget(bloc1)));
        expect(states, equals([0]));

        // Rebuild with bloc2
        await tester.pumpWidget(MaterialApp(home: buildWidget(bloc2)));
        expect(states, equals([0, 42]));

        // Trigger change on bloc2
        bloc2.add(Increment());
        await tester.pump();
        expect(states, equals([0, 42, 43]));

        // Verify that changing bloc1 doesn't trigger anymore
        bloc1.add(Increment());
        await tester.pump();
        expect(states, equals([0, 42, 43]));

        bloc1.close();
        bloc2.close();
      },
    );

    testWidgets(
      'BlocSignalSelector rebuilds when selector function changes',
      (tester) async {
        final cubit = CounterCubit()..emit(1);
        var builds = 0;

        Widget buildWidget(bool Function(int) selector) {
          return BlocSignalSelector<CounterCubit, int, bool>(
            bloc: cubit,
            selector: selector,
            builder: (context, val) {
              builds++;
              return Text('Val: $val');
            },
          );
        }

        await tester
            .pumpWidget(MaterialApp(home: buildWidget((state) => state >= 2)));
        expect(find.text('Val: false'), findsOneWidget);
        expect(builds, equals(1));

        // Rebuild with new selector: state >= 1
        await tester
            .pumpWidget(MaterialApp(home: buildWidget((state) => state >= 1)));
        expect(find.text('Val: true'), findsOneWidget);
        expect(builds, equals(2));

        cubit.close();
      },
    );
  });
}
