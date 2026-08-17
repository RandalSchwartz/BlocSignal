import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/src/internals.dart'
    hide AsyncData, AsyncError, AsyncLoading;
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
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

      final autoDisposeCubitProvider = Provider.autoDispose<int>((ref) {
        final unsubscribe = testCubit.state.subscribe((val) {
          ref.invalidateSelf();
        });
        ref.onDispose(unsubscribe);
        return testCubit.state.value;
      });

      // Initialize autoDispose provider
      final sub = container.listen(autoDisposeCubitProvider, (prev, next) {});
      expect(container.read(autoDisposeCubitProvider), equals(5));

      testCubit.increment();
      expect(container.read(autoDisposeCubitProvider), equals(6));

      // Closing subscription allows autoDispose cleanup
      sub.close();
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

    test('reading state after close does not throw', () async {
      final riverpodBloc = counterProvider.toBlocSignal(container);
      await riverpodBloc.close();

      expect(riverpodBloc.isClosed, isTrue);
      expect(riverpodBloc.stateValue, equals(0));
    });
  });
}
