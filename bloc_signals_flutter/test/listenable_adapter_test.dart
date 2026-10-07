import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

class TestChangeNotifier extends ChangeNotifier {
  int count = 0;

  bool get isListening => hasListeners;

  void increment() {
    count++;
    notifyListeners();
  }
}

class TestCubit extends CubitSignal<int> {
  TestCubit({super.initialState = 0, super.equals, super.options});

  void increment() => emit(stateValue + 1);
}

class SubscriptionTrackingCubit<T> extends CubitSignal<T> {
  SubscriptionTrackingCubit({
    required super.initialState,
    super.equals,
    super.options,
  });

  int activeListenableSubscriptions = 0;

  late final ReadonlySignal<T> _trackedState = computed<T>(
    () => super.state.value,
    options: ComputedOptions<T>(
      watched: () {
        activeListenableSubscriptions++;
      },
      unwatched: () {
        activeListenableSubscriptions--;
      },
    ),
  );

  @override
  ReadonlySignal<T> get state => _trackedState;

  void setState(T nextState) => emit(nextState);
}

class CustomEqualsCubit<T> extends CubitSignal<T> {
  CustomEqualsCubit({
    required super.initialState,
    super.equals,
  });

  void setState(T nextState) => emit(nextState);
}

@immutable
class AlwaysEqualBox {
  const AlwaysEqualBox(this.value);

  final int value;

  @override
  bool operator ==(Object other) => other is AlwaysEqualBox;

  @override
  int get hashCode => 0;
}

class ErrorCapturingListenableBlocSignal<T> extends ListenableBlocSignal<T> {
  ErrorCapturingListenableBlocSignal(
    super.listenable, {
    required super.readState,
    required this.onErrorCallback,
  });

  final void Function(Object error, StackTrace stackTrace) onErrorCallback;

  @override
  void onError(Object error, StackTrace stackTrace) {
    onErrorCallback(error, stackTrace);
    super.onError(error, stackTrace);
  }
}

void main() {
  group('ListenableBlocSignal & ListenableAdapter', () {
    test('adapts ChangeNotifier to BlocSignal using readState', () async {
      final changeNotifier = TestChangeNotifier();
      addTearDown(changeNotifier.dispose);
      final blocSignal = changeNotifier.toBlocSignal<int>(
        readState: () => changeNotifier.count,
      );

      expect(blocSignal.stateValue, equals(0));

      changeNotifier.increment();
      expect(blocSignal.stateValue, equals(1));

      await blocSignal.close();
    });

    test('adapts ValueNotifier to BlocSignal via valueNotifier.toBlocSignal()',
        () async {
      final valueNotifier = ValueNotifier<int>(10);
      addTearDown(valueNotifier.dispose);
      final blocSignal = valueNotifier.toBlocSignal();

      expect(blocSignal.stateValue, equals(10));

      valueNotifier.value = 20;
      expect(blocSignal.stateValue, equals(20));

      await blocSignal.close();
    });

    test('closing ListenableBlocSignal removes listener from Listenable',
        () async {
      final changeNotifier = TestChangeNotifier();
      addTearDown(changeNotifier.dispose);
      final blocSignal = changeNotifier.toBlocSignal<int>(
        readState: () => changeNotifier.count,
      );

      expect(changeNotifier.isListening, isTrue);

      await blocSignal.close();

      expect(changeNotifier.isListening, isFalse);
    });

    test('routes exception thrown by readState to onError', () async {
      Object? capturedError;
      final changeNotifier = TestChangeNotifier();
      addTearDown(changeNotifier.dispose);
      var shouldThrow = false;

      final blocSignal = ErrorCapturingListenableBlocSignal<int>(
        changeNotifier,
        readState: () {
          if (shouldThrow) {
            throw const FormatException('readState exception');
          }
          return changeNotifier.count;
        },
        onErrorCallback: (error, stackTrace) {
          capturedError = error;
        },
      );

      shouldThrow = true;
      changeNotifier.increment();

      expect(capturedError, isA<FormatException>());
      await blocSignal.close();
    });

    test('adapts BlocSignal to ValueListenable via toValueListenable()',
        () async {
      final testCubit = TestCubit(initialState: 5);
      final valueListenable = testCubit.toValueListenable();

      expect(valueListenable.value, equals(5));

      var notifiedValue = 0;
      void listener() {
        notifiedValue = valueListenable.value;
      }

      valueListenable.addListener(listener);
      addTearDown(() => valueListenable.removeListener(listener));

      testCubit.increment();
      expect(valueListenable.value, equals(6));
      expect(notifiedValue, equals(6));

      await testCubit.close();
    });

    test('ValueListenable.dispose unsubscribes from BlocSignal state',
        () async {
      final testCubit = TestCubit(initialState: 100);
      final valueListenable = testCubit.toValueListenable();

      expect(valueListenable.value, equals(100));

      if (valueListenable is ValueNotifier<int>) {
        valueListenable.dispose();
      }

      // Incrementing cubit post-dispose does not throw or crash
      testCubit.increment();
      expect(testCubit.stateValue, equals(101));

      await testCubit.close();
    });

    test('reading state after close does not throw', () async {
      final valueNotifier = ValueNotifier<int>(42);
      addTearDown(valueNotifier.dispose);
      final blocSignal = valueNotifier.toBlocSignal();

      await blocSignal.close();

      expect(blocSignal.isClosed, isTrue);
      expect(blocSignal.stateValue, equals(42));
    });

    test(
      'propagates custom SignalOptions to ListenableBlocSignal state',
      () async {
        final valueNotifier = ValueNotifier<int>(42);
        addTearDown(valueNotifier.dispose);
        final blocSignal = valueNotifier.toBlocSignal(
          options: const SignalOptions<int>(name: 'custom_listenable_signal'),
        );

        expect(blocSignal.state.name, equals('custom_listenable_signal'));
        await blocSignal.close();
      },
    );
  });

  group('toValueListenable lazy subscription lifecycle (Issue #316: R2)', () {
    test(
      'creates zero eager signal subscriptions and always reads live state '
      'value (Issue #316: R2)',
      () async {
        final cubit = SubscriptionTrackingCubit<int>(initialState: 10);
        addTearDown(cubit.close);

        final listenable = cubit.toValueListenable();

        expect(cubit.activeListenableSubscriptions, equals(0));
        expect(listenable.value, equals(10));

        cubit.setState(25);
        expect(listenable.value, equals(25));
        expect(cubit.activeListenableSubscriptions, equals(0));
      },
    );

    testWidgets(
      'mounts and unmounts ValueListenableBuilder without leaking signal '
      'subscriptions (Issue #316: R2)',
      (tester) async {
        final cubit = SubscriptionTrackingCubit<int>(initialState: 0);
        addTearDown(cubit.close);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<int>(
              valueListenable: cubit.toValueListenable(),
              builder: (context, value, _) => Text('Count: $value'),
            ),
          ),
        );

        expect(cubit.activeListenableSubscriptions, equals(1));
        expect(find.text('Count: 0'), findsOneWidget);

        cubit.setState(1);
        await tester.pump();
        expect(find.text('Count: 1'), findsOneWidget);
        expect(cubit.activeListenableSubscriptions, equals(1));

        await tester.pumpWidget(const SizedBox.shrink());
        expect(cubit.activeListenableSubscriptions, equals(0));

        cubit.setState(2);
        expect(cubit.stateValue, equals(2));
        expect(cubit.activeListenableSubscriptions, equals(0));
      },
    );

    test(
      'reference-counts multiple listeners without synchronous invocation '
      'during addListener and supports re-subscription (Issue #316: R2)',
      () async {
        final cubit = SubscriptionTrackingCubit<int>(initialState: 0);
        addTearDown(cubit.close);

        final listenable = cubit.toValueListenable();
        expect(cubit.activeListenableSubscriptions, equals(0));

        // Mutate before adding any listener
        cubit.setState(5);
        expect(listenable.value, equals(5));
        expect(cubit.activeListenableSubscriptions, equals(0));

        final l1Calls = <int>[];
        final l2Calls = <int>[];
        final l3Calls = <int>[];

        void l1() => l1Calls.add(listenable.value);
        void l2() => l2Calls.add(listenable.value);
        void l3() => l3Calls.add(listenable.value);

        listenable.addListener(l1);
        expect(cubit.activeListenableSubscriptions, equals(1));
        expect(l1Calls, isEmpty);

        listenable.addListener(l2);
        expect(cubit.activeListenableSubscriptions, equals(1));
        expect(l1Calls, isEmpty);
        expect(l2Calls, isEmpty);

        cubit.setState(6);
        expect(l1Calls, equals(<int>[6]));
        expect(l2Calls, equals(<int>[6]));

        listenable.removeListener(l1);
        expect(cubit.activeListenableSubscriptions, equals(1));

        cubit.setState(7);
        expect(l1Calls, equals(<int>[6]));
        expect(l2Calls, equals(<int>[6, 7]));

        listenable.removeListener(l2);
        expect(cubit.activeListenableSubscriptions, equals(0));

        cubit.setState(8);
        expect(listenable.value, equals(8));
        expect(l2Calls, equals(<int>[6, 7]));

        // Re-subscribe after dropping to 0 listeners
        listenable.addListener(l3);
        expect(cubit.activeListenableSubscriptions, equals(1));
        expect(l3Calls, isEmpty);

        cubit.setState(9);
        expect(l3Calls, equals(<int>[9]));

        listenable.removeListener(l3);
        expect(cubit.activeListenableSubscriptions, equals(0));
      },
    );

    test(
      'notifies listeners on custom bloc.equals transitions even when '
      'operator == returns true (Issue #316: R2)',
      () async {
        final cubit = CustomEqualsCubit<AlwaysEqualBox>(
          initialState: const AlwaysEqualBox(1),
          equals: identical,
        );
        addTearDown(cubit.close);

        final listenable = cubit.toValueListenable();
        final observedValues = <int>[];
        void listener() => observedValues.add(listenable.value.value);

        listenable.addListener(listener);
        addTearDown(() => listenable.removeListener(listener));

        // Non-identical instance with operator == returning true
        // ignore: prefer_const_constructors
        final nextBox = AlwaysEqualBox(2);
        expect(nextBox == cubit.stateValue, isTrue);

        cubit.setState(nextBox);
        expect(listenable.value.value, equals(2));
        expect(observedValues, equals(<int>[2]));
      },
    );

    test(
      'safely disposes with zero or active listeners (Issue #316: R2)',
      () async {
        final cubit = SubscriptionTrackingCubit<int>(initialState: 0);
        addTearDown(cubit.close);

        // Case 1: dispose() when no listeners were ever added
        final untouchedListenable =
            cubit.toValueListenable() as ValueNotifier<int>;
        expect(cubit.activeListenableSubscriptions, equals(0));
        expect(untouchedListenable.dispose, returnsNormally);
        expect(cubit.activeListenableSubscriptions, equals(0));

        // Case 2: dispose() while listeners are actively attached
        final activeListenable =
            cubit.toValueListenable() as ValueNotifier<int>;
        var callCount = 0;
        void listener() => callCount++;

        activeListenable.addListener(listener);
        expect(cubit.activeListenableSubscriptions, equals(1));

        expect(activeListenable.dispose, returnsNormally);
        expect(cubit.activeListenableSubscriptions, equals(0));

        cubit.setState(42);
        expect(callCount, equals(0));
      },
    );
  });
}
