import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

sealed class CounterEvent {}

class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent event) {
    switch (event) {
      case Increment():
        emit(stateValue + 1);
    }
  }
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
  });
}
