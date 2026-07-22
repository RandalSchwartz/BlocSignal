import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/src/internals.dart';
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

    test('adapts Riverpod provider to BlocSignal using ProviderContainer', () {
      final riverpodBloc = RiverpodBlocSignal<int>(container, counterProvider);

      expect(riverpodBloc.stateValue, equals(0));

      container.read(counterProvider.notifier).increment();

      expect(riverpodBloc.stateValue, equals(1));

      riverpodBloc.close();
    });

    test('adapts Riverpod provider to BlocSignal via toBlocSignal(container)',
        () {
      final riverpodBloc = counterProvider.toBlocSignal(container);

      expect(riverpodBloc.stateValue, equals(0));

      container.read(counterProvider.notifier).increment();

      expect(riverpodBloc.stateValue, equals(1));

      riverpodBloc.close();
    });

    test('toBlocSignal(ref) automatically binds ref.onDispose to close', () {
      late BlocSignalBase<int> adapter;

      final bridgeProvider = Provider.autoDispose<BlocSignalBase<int>>((ref) {
        adapter = counterProvider.toBlocSignal(ref);
        return adapter;
      });

      // Reading the provider initializes the adapter
      container.read(bridgeProvider);

      expect(adapter.stateValue, equals(0));
      expect(adapter.isClosed, isFalse);

      container.read(counterProvider.notifier).increment();
      expect(adapter.stateValue, equals(1));

      // Disposing the container/provider triggers ref.onDispose
      container.dispose();

      expect(adapter.isClosed, isTrue);
    });

    test('toBlocSignal supports duck-typed WidgetRef objects', () {
      final mockRef = MockWidgetRef(container);
      final adapter = counterProvider.toBlocSignal(mockRef);

      expect(adapter.stateValue, equals(0));
      expect(mockRef.disposeCallback, isNotNull);

      container.read(counterProvider.notifier).increment();
      expect(adapter.stateValue, equals(1));

      mockRef.disposeCallback!();
      expect(adapter.isClosed, isTrue);
    });

    test('toBlocSignal throws ArgumentError on invalid argument', () {
      expect(
        () => counterProvider.toBlocSignal(12345),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('adapts BlocSignal to Riverpod Provider via toProvider()', () {
      final testCubit = TestCubit(initialState: 10);
      final cubitProvider = testCubit.toProvider();

      expect(container.read(cubitProvider), equals(10));

      testCubit.increment();

      expect(container.read(cubitProvider), equals(11));

      testCubit.increment();
      expect(container.read(cubitProvider), equals(12));

      testCubit.close();
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

    test('reading state after close does not throw', () async {
      final riverpodBloc = counterProvider.toBlocSignal(container);
      await riverpodBloc.close();

      expect(riverpodBloc.isClosed, isTrue);
      expect(riverpodBloc.stateValue, equals(0));
    });
  });
}
