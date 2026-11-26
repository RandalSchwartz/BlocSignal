import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _CounterCubit extends CubitSignal<int> {
  _CounterCubit([int initial = 0]) : super(initialState: initial);

  void increment() => emit(stateValue + 1);
}

class _SecondaryCubit extends CubitSignal<String> {
  _SecondaryCubit([String initial = 'init']) : super(initialState: initial);

  void setText(String value) => emit(value);
}

class _CountingCloseCubit extends CubitSignal<int> {
  _CountingCloseCubit([int initial = 0]) : super(initialState: initial);

  int closeCount = 0;

  @override
  Future<void> close() {
    closeCount++;
    return super.close();
  }
}

class _FailingCloseCubit extends CubitSignal<int> {
  _FailingCloseCubit([int initial = 0]) : super(initialState: initial);

  int closeCount = 0;

  @override
  Future<void> close() async {
    closeCount++;
    await super.close();
    throw StateError('close failed');
  }
}

class _ConstCounterReader extends StatelessWidget {
  const _ConstCounterReader();

  static final List<int> observedValues = <int>[];

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<_CounterCubit>();
    observedValues.add(cubit.stateValue);
    return const SizedBox.shrink();
  }
}

void main() {
  tearDown(() async {
    await BlocSignalProvider.clearRetained();
  });

  group('(Issue #392) BlocSignalProvider.retentionPeriod', () {
    testWidgets(
      '(Issue #392: immediate close) closes immediately when retentionPeriod '
      'is null or Duration.zero',
      (tester) async {
        late _CounterCubit nullRetentionCubit;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            create: (_) => nullRetentionCubit = _CounterCubit(),
          ),
        );
        expect(nullRetentionCubit.isClosed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(nullRetentionCubit.isClosed, isTrue);

        late _CounterCubit zeroRetentionCubit;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: Duration.zero,
            create: (_) => zeroRetentionCubit = _CounterCubit(),
          ),
        );
        expect(zeroRetentionCubit.isClosed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(zeroRetentionCubit.isClosed, isTrue);
      },
    );

    testWidgets(
      '(Issue #392: deferred close & remount) retains bloc across unmount '
      'and reclaims exact instance & state within retentionPeriod',
      (tester) async {
        var createCount = 0;
        late _CounterCubit firstInstance;

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              return firstInstance = _CounterCubit();
            },
            child: Builder(
              builder: (context) {
                context.read<_CounterCubit>().increment();
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(createCount, 1);
        expect(firstInstance.stateValue, 1);
        expect(firstInstance.isClosed, isFalse);

        // Unmount provider.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(firstInstance.isClosed, isFalse);

        // Advance time within retention window.
        await tester.pump(const Duration(seconds: 3));
        expect(firstInstance.isClosed, isFalse);

        // Remount provider with same type and key.
        _CounterCubit? reclaimedInstance;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              return _CounterCubit();
            },
            child: Builder(
              builder: (context) {
                reclaimedInstance = context.read<_CounterCubit>();
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(createCount, 1);
        expect(identical(reclaimedInstance, firstInstance), isTrue);
        expect(reclaimedInstance!.stateValue, 1);

        // Advance past original 5s window to confirm timer was cancelled.
        await tester.pump(const Duration(seconds: 5));
        expect(firstInstance.isClosed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: timer expiration) closes bloc and purges pool when '
      'retentionPeriod expires; subsequent mount creates fresh instance',
      (tester) async {
        var createCount = 0;
        late _CounterCubit firstInstance;

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              return firstInstance = _CounterCubit(10);
            },
          ),
        );
        expect(createCount, 1);

        // Unmount and let retention timer expire.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(firstInstance.isClosed, isFalse);

        await tester.pump(const Duration(seconds: 5));
        expect(firstInstance.isClosed, isTrue);

        // Remount should invoke create again and yield a fresh instance.
        late _CounterCubit secondInstance;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              return secondInstance = _CounterCubit();
            },
          ),
        );

        expect(createCount, 2);
        expect(identical(secondInstance, firstInstance), isFalse);
        expect(secondInstance.stateValue, 0);
        expect(secondInstance.isClosed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: lazy reclamation) reclaims retained bloc for both '
      'lazy: true and lazy: false without mid-mount expiration',
      (tester) async {
        var createCount = 0;
        late _CounterCubit original;

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            retentionPeriod: const Duration(seconds: 4),
            create: (_) {
              createCount++;
              return original = _CounterCubit();
            },
            child: Builder(
              builder: (context) {
                context.read<_CounterCubit>().increment();
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(createCount, 1);

        // Unmount.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        expect(original.isClosed, isFalse);

        // Remount with lazy: true; do NOT read yet, advance past 4s total.
        _CounterCubit? readLater;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            retentionPeriod: const Duration(seconds: 4),
            create: (_) {
              createCount++;
              return _CounterCubit();
            },
          ),
        );

        await tester.pump(const Duration(seconds: 3));
        // Timer must have been cancelled eagerly in initState!
        expect(original.isClosed, isFalse);

        // Now read it in a child.
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            retentionPeriod: const Duration(seconds: 4),
            create: (_) {
              createCount++;
              return _CounterCubit();
            },
            child: Builder(
              builder: (context) {
                readLater = context.read<_CounterCubit>();
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(createCount, 1);
        expect(identical(readLater, original), isTrue);
        expect(readLater!.stateValue, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: key & type isolation) isolates by (T, Key?) and evicts '
      'displaced instance on same (T, Key?) collision',
      (tester) async {
        late _CounterCubit keyACubit;
        late _CounterCubit keyBCubit;
        late _SecondaryCubit secondaryCubit;

        await tester.pumpWidget(
          Column(
            children: [
              BlocSignalProvider<_CounterCubit>(
                key: const ValueKey('A'),
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) => keyACubit = _CounterCubit(1),
              ),
              BlocSignalProvider<_CounterCubit>(
                key: const ValueKey('B'),
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) => keyBCubit = _CounterCubit(2),
              ),
              SizedBox(
                child: BlocSignalProvider<_SecondaryCubit>(
                  key: const ValueKey('A'),
                  lazy: false,
                  retentionPeriod: const Duration(seconds: 5),
                  create: (_) => secondaryCubit = _SecondaryCubit('hello'),
                ),
              ),
            ],
          ),
        );

        // Unmount all three into the pool.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(keyACubit.isClosed, isFalse);
        expect(keyBCubit.isClosed, isFalse);
        expect(secondaryCubit.isClosed, isFalse);

        // Reclaim only key A _CounterCubit and _SecondaryCubit.
        _CounterCubit? reclaimedA;
        _SecondaryCubit? reclaimedSecondary;
        await tester.pumpWidget(
          Column(
            children: [
              BlocSignalProvider<_CounterCubit>(
                key: const ValueKey('A'),
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) => _CounterCubit(99),
                child: Builder(
                  builder: (context) {
                    reclaimedA = context.read<_CounterCubit>();
                    return const SizedBox.shrink();
                  },
                ),
              ),
              SizedBox(
                child: BlocSignalProvider<_SecondaryCubit>(
                  key: const ValueKey('A'),
                  lazy: false,
                  retentionPeriod: const Duration(seconds: 5),
                  create: (_) => _SecondaryCubit('new'),
                  child: Builder(
                    builder: (context) {
                      reclaimedSecondary = context.read<_SecondaryCubit>();
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ],
          ),
        );

        expect(identical(reclaimedA, keyACubit), isTrue);
        expect(reclaimedA!.stateValue, 1);
        expect(identical(reclaimedSecondary, secondaryCubit), isTrue);
        expect(reclaimedSecondary!.stateValue, 'hello');

        // Key B is still retained in pool until its timer expires.
        expect(keyBCubit.isClosed, isFalse);

        // Two concurrent providers with the same (T, null) key collide on
        // dispose: the first enters the pool and the second evicts and closes
        // it immediately.
        late _CounterCubit concurrent1;
        late _CounterCubit concurrent2;
        await tester.pumpWidget(
          Column(
            children: [
              BlocSignalProvider<_CounterCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) => concurrent1 = _CounterCubit(11),
              ),
              BlocSignalProvider<_CounterCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) => concurrent2 = _CounterCubit(22),
              ),
            ],
          ),
        );

        // Unmount both concurrently: concurrent1 enters pool, then
        // concurrent2 collides on ( _CounterCubit, null ) and must close
        // concurrent1 immediately!
        await tester.pumpWidget(const SizedBox.shrink());
        expect(concurrent1.isClosed, isTrue);
        expect(concurrent2.isClosed, isFalse);

        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: external close) detects externally closed bloc in pool '
      'and creates a fresh instance on remount',
      (tester) async {
        var createCount = 0;
        late _CounterCubit firstInstance;

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              return firstInstance = _CounterCubit(5);
            },
          ),
        );
        expect(createCount, 1);

        // Unmount into pool.
        await tester.pumpWidget(const SizedBox.shrink());
        expect(firstInstance.isClosed, isFalse);

        // Externally close the retained bloc.
        await firstInstance.close();
        expect(firstInstance.isClosed, isTrue);

        // Remount should NOT reclaim the closed bloc; must create fresh.
        late _CounterCubit secondInstance;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              return secondInstance = _CounterCubit();
            },
          ),
        );

        expect(createCount, 2);
        expect(identical(secondInstance, firstInstance), isFalse);
        expect(secondInstance.isClosed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: MultiBlocSignalProvider) forwards retentionPeriod via '
      'copyWith',
      (tester) async {
        var createCount = 0;
        late _CounterCubit cubit;

        await tester.pumpWidget(
          MultiBlocSignalProvider(
            providers: [
              BlocSignalProvider<_CounterCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) {
                  createCount++;
                  return cubit = _CounterCubit(42);
                },
              ),
            ],
            child: const SizedBox.shrink(),
          ),
        );
        expect(createCount, 1);

        // Unmount and verify retention.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 2));
        expect(cubit.isClosed, isFalse);

        // Remount via MultiBlocSignalProvider and verify reclamation.
        _CounterCubit? reclaimed;
        await tester.pumpWidget(
          MultiBlocSignalProvider(
            providers: [
              BlocSignalProvider<_CounterCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) {
                  createCount++;
                  return _CounterCubit();
                },
              ),
            ],
            child: Builder(
              builder: (context) {
                reclaimed = context.read<_CounterCubit>();
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        expect(createCount, 1);
        expect(identical(reclaimed, cubit), isTrue);
        expect(reclaimed!.stateValue, 42);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: .value mode & transitions) .value never retains or '
      'closes external bloc, and create -> .value closes immediately',
      (tester) async {
        final externalCubit = _CounterCubit(7);
        addTearDown(externalCubit.close);

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>.value(
            value: externalCubit,
          ),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        expect(externalCubit.isClosed, isFalse);

        // create -> .value transition in didUpdateWidget closes immediately.
        late _CounterCubit ownedCubit;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) => ownedCubit = _CounterCubit(1),
          ),
        );
        expect(ownedCubit.isClosed, isFalse);

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>.value(
            value: externalCubit,
          ),
        );
        expect(ownedCubit.isClosed, isTrue);

        // .value -> create: transition reclaims from pool if present.
        late _CounterCubit retainedCubit;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) => retainedCubit = _CounterCubit(99),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(retainedCubit.isClosed, isFalse);

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>.value(
            value: externalCubit,
          ),
        );
        var createCalled = false;
        _CounterCubit? reclaimedAfterValue;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCalled = true;
              return _CounterCubit();
            },
            child: Builder(
              builder: (context) {
                reclaimedAfterValue = context.read<_CounterCubit>();
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(createCalled, isFalse);
        expect(identical(reclaimedAfterValue, retainedCubit), isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: negative duration) throws ArgumentError for negative '
      'retentionPeriod in initState and didUpdateWidget',
      (tester) async {
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            retentionPeriod: const Duration(milliseconds: -1),
            create: (_) => _CounterCubit(),
          ),
        );
        expect(tester.takeException(), isArgumentError);

        // Also test didUpdateWidget transition to negative retentionPeriod.
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            retentionPeriod: const Duration(seconds: 1),
            create: (_) => _CounterCubit(),
          ),
        );
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            retentionPeriod: const Duration(seconds: -5),
            create: (_) => _CounterCubit(),
          ),
        );
        expect(tester.takeException(), isArgumentError);
      },
    );

    testWidgets(
      '(Issue #392: clearRetained) cancels timers, closes retained blocs, '
      'and empties the pool',
      (tester) async {
        late _CounterCubit cubit1;
        late _SecondaryCubit cubit2;

        await tester.pumpWidget(
          Column(
            children: [
              BlocSignalProvider<_CounterCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 10),
                create: (_) => cubit1 = _CounterCubit(1),
              ),
              BlocSignalProvider<_SecondaryCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 10),
                create: (_) => cubit2 = _SecondaryCubit('a'),
              ),
            ],
          ),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        expect(cubit1.isClosed, isFalse);
        expect(cubit2.isClosed, isFalse);

        await BlocSignalProvider.clearRetained();
        expect(cubit1.isClosed, isTrue);
        expect(cubit2.isClosed, isTrue);

        // Subsequent mount must create fresh instances.
        late _CounterCubit freshCubit1;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 10),
            create: (_) => freshCubit1 = _CounterCubit(),
          ),
        );
        expect(identical(freshCubit1, cubit1), isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: debugFillProperties) includes retentionPeriod diagnostic',
      (tester) async {
        final provider = BlocSignalProvider<_CounterCubit>(
          retentionPeriod: const Duration(seconds: 5),
          create: (_) => _CounterCubit(),
        );
        final builder = DiagnosticPropertiesBuilder();
        provider.debugFillProperties(builder);

        final prop = builder.properties.firstWhere(
          (p) => p.name == 'retentionPeriod',
        );
        expect(prop.value, const Duration(seconds: 5));
      },
    );

    testWidgets(
      '(Issue #392: BLOCKER-1 creation failure) lazy: true caches error on '
      'repeat lookup, does not retain null on dispose, and remount creates '
      'fresh instance',
      (tester) async {
        var createCount = 0;
        var shouldThrow = true;

        Widget buildTree(ValueNotifier<int> tick) {
          return ValueListenableBuilder<int>(
            valueListenable: tick,
            builder: (_, __, ___) {
              return BlocSignalProvider<_CounterCubit>(
                retentionPeriod: const Duration(seconds: 5),
                create: (_) {
                  createCount++;
                  if (shouldThrow) {
                    throw StateError('lazy create failed');
                  }
                  return _CounterCubit(7);
                },
                child: Builder(
                  builder: (context) {
                    context.read<_CounterCubit>();
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          );
        }

        final tick = ValueNotifier<int>(0);
        addTearDown(tick.dispose);

        await tester.pumpWidget(buildTree(tick));
        expect(tester.takeException(), isStateError);
        expect(createCount, 1);

        // Repeat lookup on rebuild rethrows cached error without re-invoking
        // create.
        tick.value++;
        await tester.pump();
        expect(tester.takeException(), isStateError);
        expect(createCount, 1);

        // Unmounting neither retains null nor leaks pending timers.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 10));

        // Remounting invokes create fresh.
        shouldThrow = false;
        _CounterCubit? created;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              return _CounterCubit(7);
            },
            child: Builder(
              builder: (context) {
                created = context.read<_CounterCubit>();
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(createCount, 2);
        expect(created?.stateValue, 7);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: BLOCKER-1 creation failure) lazy: false throws on mount, '
      'does not retain null on dispose, and remount creates fresh instance',
      (tester) async {
        var createCount = 0;
        var shouldThrow = true;

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              if (shouldThrow) {
                throw StateError('eager create failed');
              }
              return _CounterCubit(9);
            },
          ),
        );
        expect(tester.takeException(), isStateError);
        expect(createCount, 1);

        // Unmounting neither retains null nor leaks pending timers.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 10));

        // Remounting invokes create fresh.
        shouldThrow = false;
        late _CounterCubit created;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) {
              createCount++;
              return created = _CounterCubit(9);
            },
          ),
        );
        expect(tester.takeException(), isNull);
        expect(createCount, 2);
        expect(created.stateValue, 9);
        expect(created.isClosed, isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: BLOCKER-2 failing close on expiration) removes pool '
      'entry and delegates async close error to enclosing Zone',
      (tester) async {
        final zoneErrors = <Object>[];
        late _FailingCloseCubit failingCubit;

        await runZonedGuarded(
          () async {
            await tester.pumpWidget(
              BlocSignalProvider<_FailingCloseCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 3),
                create: (_) => failingCubit = _FailingCloseCubit(1),
              ),
            );
            await tester.pumpWidget(const SizedBox.shrink());
            expect(failingCubit.closeCount, 0);

            // Timer expiration triggers close(), removes entry, and delegates
            // the async error to the enclosing Zone.
            await tester.pump(const Duration(seconds: 3));
          },
          (error, stack) {
            zoneErrors.add(error);
          },
        );

        expect(failingCubit.closeCount, 1);
        expect(zoneErrors, hasLength(1));
        expect(zoneErrors.single, isStateError);

        // Pool entry was removed; remounting creates a fresh instance.
        late _FailingCloseCubit fresh;
        await tester.pumpWidget(
          BlocSignalProvider<_FailingCloseCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 3),
            create: (_) => fresh = _FailingCloseCubit(2),
          ),
        );
        expect(identical(fresh, failingCubit), isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await expectLater(BlocSignalProvider.clearRetained(), throwsStateError);
      },
    );

    testWidgets(
      '(Issue #392: BLOCKER-2 failing close in clearRetained) empties pool, '
      'cancels timers, and surfaces close failure',
      (tester) async {
        late _FailingCloseCubit failingCubit;

        await tester.pumpWidget(
          BlocSignalProvider<_FailingCloseCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 10),
            create: (_) => failingCubit = _FailingCloseCubit(1),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());

        await expectLater(BlocSignalProvider.clearRetained(), throwsStateError);
        expect(failingCubit.closeCount, 1);

        // Advancing past original retentionPeriod must not fire a second close.
        await tester.pump(const Duration(seconds: 10));
        expect(failingCubit.closeCount, 1);
      },
    );

    testWidgets(
      '(Issue #392: BLOCKER-3 external close skip branches) timer expiration '
      'and clearRetained skip close() on already-closed pool entries',
      (tester) async {
        // (a) Timer expiration without remounting skips close().
        late _CountingCloseCubit cubitA;
        await tester.pumpWidget(
          BlocSignalProvider<_CountingCloseCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 3),
            create: (_) => cubitA = _CountingCloseCubit(1),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await cubitA.close();
        expect(cubitA.closeCount, 1);

        await tester.pump(const Duration(seconds: 3));
        expect(cubitA.closeCount, 1);

        // (b) clearRetained() with an already-closed entry skips close() and
        // purges the pool.
        late _CountingCloseCubit cubitB;
        await tester.pumpWidget(
          BlocSignalProvider<_CountingCloseCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 10),
            create: (_) => cubitB = _CountingCloseCubit(2),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await cubitB.close();
        expect(cubitB.closeCount, 1);

        await BlocSignalProvider.clearRetained();
        expect(cubitB.closeCount, 1);

        // Pool was purged; remounting creates a fresh instance.
        late _CountingCloseCubit fresh;
        await tester.pumpWidget(
          BlocSignalProvider<_CountingCloseCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 10),
            create: (_) => fresh = _CountingCloseCubit(3),
          ),
        );
        expect(identical(fresh, cubitB), isFalse);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: NBO-2 lazy -> eager didUpdateWidget) reclaims from pool '
      'before invoking create',
      (tester) async {
        // Mount an uninitialized lazy: true provider while the pool is empty,
        // alongside a second provider that will populate the pool on unmount.
        var lazyCreateCount = 0;
        late _CounterCubit retained;
        await tester.pumpWidget(
          Column(
            children: [
              BlocSignalProvider<_CounterCubit>(
                create: (_) {
                  lazyCreateCount++;
                  return _CounterCubit(1);
                },
              ),
              BlocSignalProvider<_CounterCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) => retained = _CounterCubit(77),
              ),
            ],
          ),
        );
        expect(lazyCreateCount, 0);

        // Step 1: Unmount the second provider so it enters the pool while
        // the first provider remains mounted and uninitialized (lazy: true).
        await tester.pumpWidget(
          Column(
            children: [
              BlocSignalProvider<_CounterCubit>(
                create: (_) {
                  lazyCreateCount++;
                  return _CounterCubit(1);
                },
              ),
            ],
          ),
        );
        expect(lazyCreateCount, 0);
        expect(retained.isClosed, isFalse);

        // Step 2: Update the first provider from lazy: true to lazy: false;
        // didUpdateWidget must reclaim `retained` from the pool.
        _CounterCubit? reclaimed;
        await tester.pumpWidget(
          Column(
            children: [
              BlocSignalProvider<_CounterCubit>(
                lazy: false,
                retentionPeriod: const Duration(seconds: 5),
                create: (_) {
                  lazyCreateCount++;
                  return _CounterCubit(2);
                },
                child: Builder(
                  builder: (context) {
                    reclaimed = context.read<_CounterCubit>();
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        );

        expect(lazyCreateCount, 0);
        expect(identical(reclaimed, retained), isTrue);
        expect(reclaimed!.stateValue, 77);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );

    testWidgets(
      '(Issue #392: NBO-4 retentionPeriod didUpdateWidget & const subtree) '
      'handles 5s -> null, 5s -> zero, null -> 5s, and .value -> create '
      'reclamation above const child',
      (tester) async {
        // 5s -> null closes immediately on unmount.
        late _CounterCubit cubit5ToNull;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) => cubit5ToNull = _CounterCubit(1),
          ),
        );
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            create: (_) => _CounterCubit(99),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(cubit5ToNull.isClosed, isTrue);

        // 5s -> Duration.zero closes immediately on unmount.
        late _CounterCubit cubit5ToZero;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) => cubit5ToZero = _CounterCubit(2),
          ),
        );
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: Duration.zero,
            create: (_) => _CounterCubit(99),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(cubit5ToZero.isClosed, isTrue);

        // null -> 5s retains on unmount.
        late _CounterCubit cubitNullTo5;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            create: (_) => cubitNullTo5 = _CounterCubit(3),
          ),
        );
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) => _CounterCubit(99),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(cubitNullTo5.isClosed, isFalse);
        await BlocSignalProvider.clearRetained();
        expect(cubitNullTo5.isClosed, isTrue);

        // .value -> create: pool reclamation above an already-mounted const
        // descendant subtree notifies dependents with the reclaimed instance.
        final externalCubit = _CounterCubit(10);
        addTearDown(externalCubit.close);

        late _CounterCubit retainedForConst;
        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) => retainedForConst = _CounterCubit(88),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(retainedForConst.isClosed, isFalse);

        _ConstCounterReader.observedValues.clear();

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>.value(
            value: externalCubit,
            child: const _ConstCounterReader(),
          ),
        );
        expect(_ConstCounterReader.observedValues, [10]);

        await tester.pumpWidget(
          BlocSignalProvider<_CounterCubit>(
            lazy: false,
            retentionPeriod: const Duration(seconds: 5),
            create: (_) => _CounterCubit(),
            child: const _ConstCounterReader(),
          ),
        );
        expect(_ConstCounterReader.observedValues, [10, 88]);

        await tester.pumpWidget(const SizedBox.shrink());
        await BlocSignalProvider.clearRetained();
      },
    );
  });
}
