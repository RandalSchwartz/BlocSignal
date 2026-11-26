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
}

class _EffectSpyObserver extends SignalsObserver {
  final List<String?> effectNames = <String?>[];
  final List<int> computedHashCodes = <int>[];

  @override
  void onComputedCreated<T>(Computed<T> instance) {}

  @override
  void onComputedUpdated<T>(Computed<T> instance, T value) {
    if (value != null) {
      computedHashCodes.add(value.hashCode);
    }
  }

  @override
  void onEffectCreated(Effect instance) {
    effectNames.add(instance.name);
  }

  @override
  void onSignalCreated<T>(Signal<T> instance, T value) {}

  @override
  void onSignalUpdated<T>(Signal<T> instance, T value) {}
}

class _MissingProviderCaller extends StatelessWidget {
  const _MissingProviderCaller();

  @override
  Widget build(BuildContext context) {
    BlocSignalProvider.of<_CounterCubit>(context);
    return const SizedBox.shrink();
  }
}

void main() {
  group('Issue #481: BlocSignalProvider.maybeOf / maybeRead / maybeWatch', () {
    testWidgets(
      '(Issue #481: maybeOf/maybeRead/maybeWatch) returns null when absent',
      (tester) async {
        _CounterCubit? fromMaybeOf;
        _CounterCubit? fromMaybeOfListen;
        _CounterCubit? fromMaybeRead;
        _CounterCubit? fromMaybeWatch;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                fromMaybeOf =
                    BlocSignalProvider.maybeOf<_CounterCubit>(context);
                fromMaybeOfListen = BlocSignalProvider.maybeOf<_CounterCubit>(
                  context,
                  listen: true,
                );
                fromMaybeRead = context.maybeRead<_CounterCubit>();
                fromMaybeWatch = context.maybeWatch<_CounterCubit>();
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(fromMaybeOf, isNull);
        expect(fromMaybeOfListen, isNull);
        expect(fromMaybeRead, isNull);
        expect(fromMaybeWatch, isNull);
      },
    );

    testWidgets(
      '(Issue #481: maybeOf/maybeRead) triggers lazy _initBloc and returns T',
      (tester) async {
        var createdCount = 0;
        _CounterCubit? fromMaybeRead;
        _CounterCubit? fromMaybeOf;

        await tester.pumpWidget(
          MaterialApp(
            home: BlocSignalProvider<_CounterCubit>(
              create: (_) {
                createdCount++;
                return _CounterCubit(42);
              },
              child: Builder(
                builder: (context) {
                  expect(createdCount, 0);
                  fromMaybeRead = context.maybeRead<_CounterCubit>();
                  fromMaybeOf =
                      BlocSignalProvider.maybeOf<_CounterCubit>(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        expect(createdCount, 1);
        expect(fromMaybeRead, isNotNull);
        expect(fromMaybeRead!.stateValue, 42);
        expect(identical(fromMaybeRead, fromMaybeOf), isTrue);
      },
    );

    testWidgets(
      '(Issue #481: maybeWatch) rebuilds when ancestor provider swaps bloc',
      (tester) async {
        final cubitA = _CounterCubit(1);
        final cubitB = _CounterCubit(2);
        addTearDown(cubitA.close);
        addTearDown(cubitB.close);

        final observedValues = <int?>[];

        Widget buildTree(_CounterCubit cubit) {
          return MaterialApp(
            home: BlocSignalProvider<_CounterCubit>.value(
              value: cubit,
              child: Builder(
                builder: (context) {
                  observedValues.add(
                    context.maybeWatch<_CounterCubit>()?.stateValue,
                  );
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
        }

        await tester.pumpWidget(buildTree(cubitA));
        await tester.pumpWidget(buildTree(cubitB));

        expect(observedValues, <int?>[1, 2]);
      },
    );
  });

  group('Issue #481: BlocSignalProviderNotFoundError', () {
    testWidgets(
      '(Issue #481: ProviderNotFoundError) extends FlutterError, names T and '
      'caller widget, and includes Builder/Navigator hints',
      (tester) async {
        final originalOnError = FlutterError.onError;
        final errors = <FlutterErrorDetails>[];
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = originalOnError);

        await tester.pumpWidget(
          const MaterialApp(home: _MissingProviderCaller()),
        );

        expect(errors, isNotEmpty);
        final err = errors.first.exception;
        expect(err, isA<FlutterError>());
        expect(err, isA<BlocSignalProviderNotFoundError<_CounterCubit>>());

        final message = err.toString();
        expect(message, contains('_CounterCubit'));
        expect(message, contains('_MissingProviderCaller'));
        expect(message, contains('Builder'));
        expect(message, contains('Navigator'));
        expect(message, contains('.value'));
      },
    );

    testWidgets(
      '(Issue #481: ProviderNotFoundError) warns when generic T is omitted '
      '(BlocSignalBase<dynamic>)',
      (tester) async {
        Object? thrown;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                try {
                  BlocSignalProvider.of(context);
                } on Object catch (e) {
                  thrown = e;
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(
          thrown,
          isA<BlocSignalProviderNotFoundError<BlocSignalBase<dynamic>>>(),
        );
        expect(thrown.toString(), contains('BlocSignalBase<dynamic>'));
        expect(thrown.toString(), contains('Builder'));
      },
    );
  });

  group('Issue #481: BlocSignalListener.transition & Consumer.transition', () {
    testWidgets(
      '(Issue #481: Listener.transition) delivers (context, previous, '
      'current), respects listenWhen, supports child, and preserves listener '
      'getter',
      (tester) async {
        final cubit = _CounterCubit(10);
        addTearDown(cubit.close);

        final transitions = <(int, int)>[];
        final listenerWidget =
            BlocSignalListener<_CounterCubit, int>.transition(
          bloc: cubit,
          listenWhen: (previous, current) => current.isEven,
          listener: (context, previous, current) {
            transitions.add((previous, current));
          },
          child: const Text('child-text'),
        );

        await tester.pumpWidget(MaterialApp(home: listenerWidget));
        expect(find.text('child-text'), findsOneWidget);

        cubit
          ..increment() // 10 -> 11 (filtered by listenWhen)
          ..increment() // 11 -> 12 (delivered)
          ..increment() // 12 -> 13 (filtered)
          ..increment(); // 13 -> 14 (delivered)

        expect(transitions, <(int, int)>[(11, 12), (13, 14)]);

        // Non-nullable public listener getter compatibility.
        final legacyListener = listenerWidget.listener;
        final ctx = tester.element(find.text('child-text'));
        legacyListener(ctx, 99);
        expect(transitions.last, (99, 99));

        // copyWith preserves transition listener.
        final copied = listenerWidget.copyWith(const Text('copied-child'));
        await tester.pumpWidget(MaterialApp(home: copied));
        cubit
          ..increment() // 14 -> 15 (filtered)
          ..increment(); // 15 -> 16 (delivered)
        expect(find.text('copied-child'), findsOneWidget);
        expect(transitions.last, (15, 16));
      },
    );

    testWidgets(
      '(Issue #481: Consumer.transition) delivers (context, previous, current),'
      ' respects listenWhen/buildWhen, and preserves listener getter',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);

        final transitions = <(int, int)>[];
        final consumer = BlocSignalConsumer<_CounterCubit, int>.transition(
          bloc: cubit,
          listenWhen: (previous, current) => current > previous,
          buildWhen: (previous, current) => current.isOdd,
          listener: (context, previous, current) {
            transitions.add((previous, current));
          },
          builder: (context, state) => Text('count:$state'),
        );

        await tester.pumpWidget(MaterialApp(home: consumer));
        expect(find.text('count:0'), findsOneWidget);

        cubit.increment(); // 0 -> 1
        await tester.pump();
        expect(find.text('count:1'), findsOneWidget);
        expect(transitions, <(int, int)>[(0, 1)]);

        cubit.emit(0); // 1 -> 0 (filtered by listenWhen & buildWhen)
        await tester.pump();
        expect(find.text('count:1'), findsOneWidget);
        expect(transitions, <(int, int)>[(0, 1)]);

        // Non-nullable public listener getter compatibility.
        final legacyListener = consumer.listener;
        final ctx = tester.element(find.text('count:1'));
        legacyListener(ctx, 42);
        expect(transitions.last, (42, 42));
      },
    );
  });

  group('Issue #481: context.select equals:', () {
    testWidgets(
      '(Issue #481: context.select equals) suppresses rebuilds when custom '
      'equals returns true and reinitializes when equals changes',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);

        var buildCount = 0;
        var useCaseInsensitive = true;

        Widget buildWithEquals() {
          return MaterialApp(
            home: BlocSignalProvider<_CounterCubit>.value(
              value: cubit,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  final selected = context.select<_CounterCubit, int>(
                    (c) => c.stateValue,
                    equals: useCaseInsensitive
                        ? (prev, next) => prev ~/ 10 == next ~/ 10
                        : (prev, next) => prev == next,
                  );
                  return Text('sel:$selected');
                },
              ),
            ),
          );
        }

        await tester.pumpWidget(buildWithEquals());
        expect(buildCount, 1);
        expect(find.text('sel:0'), findsOneWidget);

        // 0 -> 5: same decade (0 ~/ 10 == 5 ~/ 10), suppressed.
        cubit.emit(5);
        await tester.pump();
        expect(buildCount, 1);
        expect(find.text('sel:0'), findsOneWidget);

        // 5 -> 10: different decade, rebuilds.
        cubit.emit(10);
        await tester.pump();
        expect(buildCount, 2);
        expect(find.text('sel:10'), findsOneWidget);

        // Update equals comparator to strict equality.
        useCaseInsensitive = false;
        await tester.pumpWidget(buildWithEquals());
        expect(buildCount, 3);

        // 10 -> 11: now rebuilds because equals was updated.
        cubit.emit(11);
        await tester.pump();
        expect(buildCount, 4);
        expect(find.text('sel:11'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #481: context.select equals) does not throw during initial '
      'build when equals always returns false and exercises _SelectorSlot '
      'hashCode',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);

        final previousObserver = SignalsObserver.instance;
        final spy = _EffectSpyObserver();
        SignalsObserver.instance = spy;
        addTearDown(() => SignalsObserver.instance = previousObserver);

        var buildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: BlocSignalProvider<_CounterCubit>.value(
              value: cubit,
              child: Builder(
                builder: (context) {
                  buildCount++;
                  final selected = context.select<_CounterCubit, int>(
                    (c) => c.stateValue,
                    equals: (_, __) => false,
                  );
                  return Text('always:$selected');
                },
              ),
            ),
          ),
        );

        expect(buildCount, 1);
        expect(find.text('always:0'), findsOneWidget);

        cubit.increment();
        await tester.pump();
        expect(buildCount, 2);
        expect(find.text('always:1'), findsOneWidget);
        expect(spy.computedHashCodes, isNotEmpty);
      },
    );
  });

  group('Issue #481: debugFillProperties & EffectOptions(name:)', () {
    testWidgets(
      '(Issue #481: debugFillProperties) populates diagnostics on all 7 '
      'Flutter widgets',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);

        final widgets = <Widget>[
          BlocSignalProvider<_CounterCubit>.value(
            value: cubit,
          ),
          MultiBlocSignalProvider(
            providers: <BlocSignalProviderSingleChildWidget>[
              BlocSignalProvider<_CounterCubit>.value(value: cubit),
            ],
            child: const SizedBox.shrink(),
          ),
          BlocSignalBuilder<_CounterCubit, int>(
            bloc: cubit,
            buildWhen: (p, c) => p != c,
            builder: (context, state) => const SizedBox.shrink(),
          ),
          BlocSignalListener<_CounterCubit, int>(
            bloc: cubit,
            listenWhen: (p, c) => p != c,
            listener: (context, state) {},
          ),
          MultiBlocSignalListener(
            listeners: <BlocSignalListenerSingleChildWidget>[
              BlocSignalListener<_CounterCubit, int>(
                bloc: cubit,
                listener: (context, state) {},
              ),
            ],
            child: const SizedBox.shrink(),
          ),
          BlocSignalConsumer<_CounterCubit, int>(
            bloc: cubit,
            buildWhen: (p, c) => p != c,
            listenWhen: (p, c) => p != c,
            listener: (context, state) {},
            builder: (context, state) => const SizedBox.shrink(),
          ),
          BlocSignalSelector<_CounterCubit, int, int>(
            bloc: cubit,
            selector: (state) => state,
            equals: (p, c) => p == c,
            options: const ComputedOptions<int>(name: 'sel'),
            builder: (context, value) => const SizedBox.shrink(),
          ),
        ];

        for (final widget in widgets) {
          final builder = DiagnosticPropertiesBuilder();
          widget.debugFillProperties(builder);
          expect(
            builder.properties,
            isNotEmpty,
            reason: '${widget.runtimeType} should populate debugFillProperties',
          );
        }
      },
    );

    testWidgets(
      '(Issue #481: EffectOptions name) sets EffectOptions(name:) on '
      'BlocSignalBuilder and BlocSignalListener',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);

        final previousObserver = SignalsObserver.instance;
        final spy = _EffectSpyObserver();
        SignalsObserver.instance = spy;
        addTearDown(() => SignalsObserver.instance = previousObserver);

        await tester.pumpWidget(
          MaterialApp(
            home: BlocSignalListener<_CounterCubit, int>(
              bloc: cubit,
              listener: (context, state) {},
              child: BlocSignalBuilder<_CounterCubit, int>(
                bloc: cubit,
                builder: (context, state) => Text('$state'),
              ),
            ),
          ),
        );

        expect(
          spy.effectNames,
          containsAll(<String>[
            'BlocSignalListener<_CounterCubit, int>.effect',
            'BlocSignalBuilder<_CounterCubit, int>.effect',
          ]),
        );
      },
    );
  });
}
