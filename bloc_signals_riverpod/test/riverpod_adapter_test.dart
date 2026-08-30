import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/riverpod.dart'
    hide AsyncData, AsyncError, AsyncLoading;
import 'package:riverpod/src/internals.dart'
    hide AsyncData, AsyncError, AsyncLoading;
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

class AsyncCounterNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async => 0;

  Future<void> increment() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => (state.value ?? 0) + 1);
  }
}

class CounterStateNotifier extends StateNotifier<int> {
  CounterStateNotifier() : super(0);

  void increment() => state++;
}

class CounterStreamNotifier extends StreamNotifier<int> {
  @override
  Stream<int> build() => Stream.value(42);
}

sealed class CounterEvent {
  const CounterEvent();
}

final class IncrementCounterEvent extends CounterEvent {
  const IncrementCounterEvent();
}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc({super.initialState = 0}) {
    on<IncrementCounterEvent>((event, emit) {
      emit(stateValue + 1);
    });
  }
}

class TestCubit extends CubitSignal<int> {
  TestCubit({super.initialState = 0});

  void increment() => emit(stateValue + 1);
}

class MockWidgetRef {
  MockWidgetRef(this.container);

  final ProviderContainer container;
  void Function()? disposeCallback;

  // Mimics Riverpod WidgetRef interface.
  // ignore: use_setters_to_change_properties
  void onDispose(void Function() cb) {
    disposeCallback = cb;
  }
}

void main() {
  group('RiverpodBlocSignal & RiverpodAdapter', () {
    late ProviderContainer container;
    late NotifierProvider<CounterNotifier, int> counterProvider;

    setUp(() {
      container = ProviderContainer();
      counterProvider = NotifierProvider<CounterNotifier, int>(
        CounterNotifier.new,
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('adapts Riverpod provider to BlocSignal using ProviderContainer',
        () async {
      final riverpodBloc = RiverpodBlocSignal<int>(container, counterProvider);

      expect(riverpodBloc.stateValue, equals(0));

      container.read(counterProvider.notifier).increment();

      expect(riverpodBloc.stateValue, equals(1));

      await riverpodBloc.close();
    });

    test('adapts Riverpod provider to BlocSignal via toBlocSignal(container)',
        () async {
      final riverpodBloc = counterProvider.toBlocSignal(container);

      expect(riverpodBloc.stateValue, equals(0));

      container.read(counterProvider.notifier).increment();

      expect(riverpodBloc.stateValue, equals(1));

      await riverpodBloc.close();
    });

    test('toBlocSignal(ref) automatically binds ref.onDispose to close', () {
      late BlocSignalBase<int> adapter;

      final bridgeProvider = Provider.autoDispose<BlocSignalBase<int>>(
        (ref) => adapter = counterProvider.toBlocSignal(ref),
      );

      // Reading the provider initializes the adapter
      container.read(bridgeProvider);

      expect(adapter.stateValue, equals(0));
      expect(adapter.isClosed, isFalse);

      // Trigger autoDispose by creating and invalidating a container scope
      container.invalidate(bridgeProvider);

      expect(adapter.isClosed, isTrue);
    });

    test('toBlocSignal(widgetRef) works with objects exposing onDispose', () {
      final mockRef = MockWidgetRef(container);
      final adapter = counterProvider.toBlocSignal(mockRef);

      expect(adapter.stateValue, equals(0));
      expect(adapter.isClosed, isFalse);

      mockRef.disposeCallback?.call();

      expect(adapter.isClosed, isTrue);
    });

    test('toBlocSignal throws ArgumentError on unsupported object', () {
      expect(
        () => counterProvider.toBlocSignal('invalid_target'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('converts BlocSignal to Riverpod NotifierProvider via toProvider',
        () async {
      final testCubit = TestCubit(initialState: 10);
      final cubitProvider = testCubit.toProvider();

      expect(container.read(cubitProvider), equals(10));

      testCubit.increment();

      expect(container.read(cubitProvider), equals(11));

      testCubit.increment();
      expect(container.read(cubitProvider), equals(12));

      await testCubit.close();
    });

    test('BlocSignal.toProvider unsubscribes when provider is disposed', () {
      final testCubit = TestCubit(initialState: 5);
      final cubitProvider = testCubit.toProvider();

      final sub = container.listen(cubitProvider, (prev, next) {});
      expect(container.read(cubitProvider), equals(5));

      testCubit.increment();
      expect(container.read(cubitProvider), equals(6));

      sub.close();
      container.invalidate(cubitProvider);
    });

    test('converts Riverpod AsyncValue to Signals AsyncState', () {
      const dataValue = AsyncValue.data(42);
      final asyncStateData = dataValue.toAsyncState();
      expect(asyncStateData, isA<AsyncData<int>>());
      expect(asyncStateData.value, equals(42));

      const exception = FormatException('err');
      final stackTrace = StackTrace.current;
      final errorValue = AsyncValue<int>.error(
        exception,
        stackTrace,
      );
      final asyncStateError = errorValue.toAsyncState();
      expect(asyncStateError, isA<AsyncError<int>>());
      expect(asyncStateError.error, equals(exception));

      const loadingValue = AsyncValue<int>.loading();
      final asyncStateLoading = loadingValue.toAsyncState();
      expect(asyncStateLoading, isA<AsyncLoading<int>>());
    });

    test('converts Signals AsyncState to Riverpod AsyncValue', () {
      const dataState = AsyncData<int>(99);
      final asyncValueData = dataState.toAsyncValue();
      expect(asyncValueData, equals(const AsyncValue.data(99)));

      const exception = FormatException('err');
      final stackTrace = StackTrace.current;
      final errorState = AsyncError<int>(
        exception,
        stackTrace,
      );
      final asyncValueError = errorState.toAsyncValue();
      expect(asyncValueError.error, equals(exception));

      const loadingState = AsyncLoading<int>();
      final asyncValueLoading = loadingState.toAsyncValue();
      expect(asyncValueLoading, equals(const AsyncValue<int>.loading()));
    });

    test(
      'RiverpodNotifierBlocSignal exposes typed notifier for '
      'NotifierProvider',
      () async {
        final riverpodBloc = counterProvider.toBlocSignal(container);

        expect(
          riverpodBloc,
          isA<RiverpodNotifierBlocSignal<CounterNotifier, int>>(),
        );
        expect(riverpodBloc.stateValue, equals(0));

        riverpodBloc.notifier.increment();

        expect(riverpodBloc.stateValue, equals(1));
        await riverpodBloc.close();
      },
    );

    test(
      'RiverpodNotifierBlocSignal exposes typed notifier for '
      'AsyncNotifierProvider',
      () async {
        final asyncCounterProvider =
            AsyncNotifierProvider<AsyncCounterNotifier, int>(
          AsyncCounterNotifier.new,
        );
        final riverpodBloc = asyncCounterProvider.toBlocSignal(container);

        expect(
          riverpodBloc,
          isA<
              RiverpodNotifierBlocSignal<AsyncCounterNotifier,
                  AsyncValue<int>>>(),
        );

        // Wait for initial async build
        await container.read(asyncCounterProvider.future);
        expect(riverpodBloc.stateValue.value, equals(0));

        await riverpodBloc.notifier.increment();
        expect(riverpodBloc.stateValue.value, equals(1));

        await riverpodBloc.close();
      },
    );

    test(
      'RiverpodNotifierBlocSignal exposes typed notifier for '
      'StateNotifierProvider',
      () async {
        final stateNotifierProvider =
            StateNotifierProvider<CounterStateNotifier, int>(
          (ref) => CounterStateNotifier(),
        );
        final riverpodBloc = stateNotifierProvider.toBlocSignal(container);

        expect(
          riverpodBloc,
          isA<RiverpodNotifierBlocSignal<CounterStateNotifier, int>>(),
        );
        expect(riverpodBloc.stateValue, equals(0));

        riverpodBloc.notifier.increment();
        expect(riverpodBloc.stateValue, equals(1));

        await riverpodBloc.close();
      },
    );

    test('RiverpodNotifierBlocSignal exposes typed notifier for StateProvider',
        () async {
      final stateProvider = StateProvider<int>((ref) => 0);
      final riverpodBloc = stateProvider.toBlocSignal(container);

      expect(
        riverpodBloc,
        isA<RiverpodNotifierBlocSignal<StateController<int>, int>>(),
      );
      expect(riverpodBloc.stateValue, equals(0));

      riverpodBloc.notifier.state++;
      expect(riverpodBloc.stateValue, equals(1));

      await riverpodBloc.close();
    });

    test('RiverpodNotifierBlocSignal.fromRef creates adapter with dispose hook',
        () {
      final bridgeProvider = Provider.autoDispose<
          RiverpodNotifierBlocSignal<CounterNotifier, int>>(
        (ref) => counterProvider.toBlocSignal(ref),
      );

      final adapter = container.read(bridgeProvider);
      expect(adapter.isClosed, isFalse);
      expect(adapter.stateValue, equals(0));

      adapter.notifier.increment();
      expect(adapter.stateValue, equals(1));

      container.invalidate(bridgeProvider);
      expect(adapter.isClosed, isTrue);
    });

    test(
      'toProvider exposes typed .cubit and .bloc access on BlocSignalNotifier',
      () async {
        final testCubit = TestCubit(initialState: 10);
        final cubitProvider = testCubit.toProvider();

        expect(container.read(cubitProvider), equals(10));

        // Typed access to cubit
        container.read(cubitProvider.notifier).cubit.increment();
        expect(container.read(cubitProvider), equals(11));

        // Typed access to bloc alias
        container.read(cubitProvider.notifier).bloc.increment();
        expect(container.read(cubitProvider), equals(12));

        await testCubit.close();
      },
    );

    test(
      'toProvider exposes typed .bloc on BlocSignalNotifier for event-based '
      'BlocSignal',
      () async {
        final testBloc = CounterBloc(initialState: 20);
        final blocProvider = testBloc.toProvider();

        expect(container.read(blocProvider), equals(20));

        container
            .read(blocProvider.notifier)
            .bloc
            .add(const IncrementCounterEvent());
        expect(container.read(blocProvider), equals(21));

        await testBloc.close();
      },
    );

    test(
      'RiverpodNotifierBlocSignal exposes typed notifier for '
      'StreamNotifierProvider',
      () async {
        final streamProvider =
            StreamNotifierProvider<CounterStreamNotifier, int>(
          CounterStreamNotifier.new,
        );
        final riverpodBloc = streamProvider.toBlocSignal(container);

        expect(
          riverpodBloc,
          isA<
              RiverpodNotifierBlocSignal<CounterStreamNotifier,
                  AsyncValue<int>>>(),
        );

        await container.read(streamProvider.future);
        expect(riverpodBloc.stateValue.value, equals(42));
        expect(riverpodBloc.notifier, isA<CounterStreamNotifier>());

        await riverpodBloc.close();
      },
    );

    test(
      'ProviderListenable.toBlocSignal works for plain Provider with '
      'container, ref, and widgetRef',
      () async {
        final plainProvider = Provider<int>((ref) => 42);

        // ProviderContainer
        final blocFromContainer = plainProvider.toBlocSignal(container);
        expect(blocFromContainer.stateValue, equals(42));
        await blocFromContainer.close();

        // Ref
        final bridge = Provider.autoDispose<BlocSignalBase<int>>(
          plainProvider.toBlocSignal,
        );
        final blocFromRef = container.read(bridge);
        expect(blocFromRef.stateValue, equals(42));
        container.invalidate(bridge);
        expect(blocFromRef.isClosed, isTrue);

        // MockWidgetRef
        final mockRef = MockWidgetRef(container);
        final blocFromWidget = plainProvider.toBlocSignal(mockRef);
        expect(blocFromWidget.stateValue, equals(42));
        mockRef.disposeCallback?.call();
        expect(blocFromWidget.isClosed, isTrue);

        // Invalid target
        expect(
          () => plainProvider.toBlocSignal('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'RiverpodBlocSignal.fromRef creates adapter directly and binds onDispose',
      () {
        final plainProvider = Provider<int>((ref) => 99);
        late RiverpodBlocSignal<int> bloc;
        final bridge = Provider.autoDispose<int>((ref) {
          bloc = RiverpodBlocSignal<int>.fromRef(ref, plainProvider);
          return bloc.stateValue;
        });

        expect(container.read(bridge), equals(99));
        expect(bloc.isClosed, isFalse);

        container.invalidate(bridge);
        expect(bloc.isClosed, isTrue);
      },
    );

    test(
      'RiverpodNotifierBlocSignal.fromRef creates adapter directly and '
      'binds onDispose',
      () {
        late RiverpodNotifierBlocSignal<CounterNotifier, int> bloc;
        final bridge = Provider.autoDispose<int>((ref) {
          final notifier = ref.read(counterProvider.notifier);
          bloc = RiverpodNotifierBlocSignal<CounterNotifier, int>.fromRef(
            notifier,
            ref,
            counterProvider,
          );
          return bloc.stateValue;
        });

        expect(container.read(bridge), equals(0));
        expect(bloc.isClosed, isFalse);

        bloc.notifier.increment();
        expect(bloc.stateValue, equals(1));

        container.invalidate(bridge);
        expect(bloc.isClosed, isTrue);
      },
    );

    test('reading state after close does not throw', () async {
      final riverpodBloc = counterProvider.toBlocSignal(container);
      await riverpodBloc.close();

      expect(riverpodBloc.isClosed, isTrue);
      expect(riverpodBloc.stateValue, equals(0));
    });
  });
}
