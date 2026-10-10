import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

class AsyncThrowingStorage extends MemoryHydratedStorage {
  AsyncThrowingStorage({this.throwOnWrite = false, this.throwOnDelete = false});

  final bool throwOnWrite;
  final bool throwOnDelete;

  @override
  Future<void> write(String key, dynamic value) async {
    if (throwOnWrite) {
      throw Exception('Async disk write failure');
    }
    super.write(key, value);
  }

  @override
  Future<void> delete(String key) async {
    if (throwOnDelete) {
      throw Exception('Async disk delete failure');
    }
    super.delete(key);
  }
}

class CountingStorage extends MemoryHydratedStorage {
  int writeCount = 0;
  int deleteCount = 0;
  final List<dynamic> writtenValues = [];

  @override
  void write(String key, dynamic value) {
    writeCount++;
    writtenValues.add(value);
    super.write(key, value);
  }

  @override
  void delete(String key) {
    deleteCount++;
    super.delete(key);
  }
}

class TestReliabilityCubit extends HydratedCubitSignal<int> {
  TestReliabilityCubit({super.id, super.storage, super.equals})
      : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void emitSame() => emit(stateValue);
  void emitCustom(int value) => emit(value);
  void persistState(int state) => persist(state);

  @override
  void onError(Object error, StackTrace stackTrace) {
    capturedErrors.add(error);
    super.onError(error, stackTrace);
  }

  final List<Object> capturedErrors = [];
}

class TestReliabilityBloc extends HydratedBlocSignal<int, int> {
  TestReliabilityBloc({super.id, super.storage}) : super(initialState: 0) {
    on<int>((event, emit) => emit(event));
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    capturedErrors.add(error);
    super.onError(error, stackTrace);
  }

  final List<Object> capturedErrors = [];
}

class UnparseableModelCubit extends HydratedCubitSignal<Map<String, int>> {
  UnparseableModelCubit({super.storage}) : super(initialState: const {});

  @override
  Map<String, int>? fromJson(dynamic json) {
    if (json is Map && json['score'] != null) {
      return {'score': (json['score'] as num).toInt()};
    }
    return null; // Signals invalid schema / decode failure
  }
}

void main() {
  tearDown(HydratedStorage.reset);

  group('Issue #264 Persistence Reliability & Error Handling', () {
    test('async storage.write failures are routed to onError', () async {
      final storage = AsyncThrowingStorage(throwOnWrite: true);
      final cubit = TestReliabilityCubit(storage: storage)..increment();

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.capturedErrors, hasLength(1));
      expect(cubit.capturedErrors.first, isA<Exception>());
      expect(
        (cubit.capturedErrors.first as Exception).toString(),
        contains('Async disk write failure'),
      );
    });

    test('async storage.delete failures in clear() route to onError', () async {
      final storage = AsyncThrowingStorage(throwOnDelete: true);
      final cubit = TestReliabilityCubit(storage: storage)..persistState(0);
      await cubit.clear();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.capturedErrors, isNotEmpty);
      expect(
        cubit.capturedErrors.any(
          (e) => e.toString().contains('Async disk delete failure'),
        ),
        isTrue,
      );
    });

    test('emitting equal state does not invoke storage.write', () {
      final storage = CountingStorage();
      final cubit = TestReliabilityCubit(storage: storage);

      expect(storage.writeCount, equals(0));

      cubit.emitSame();
      expect(storage.writeCount, equals(0));

      cubit.increment();
      expect(storage.writeCount, equals(1));

      cubit.emitCustom(1); // Same state
      expect(storage.writeCount, equals(1));
    });

    test('emitting on closed container does not invoke storage.write',
        () async {
      final storage = CountingStorage();
      final cubit = TestReliabilityCubit(storage: storage)..increment();
      expect(storage.writeCount, equals(1));

      await cubit.close();
      cubit.increment();
      expect(storage.writeCount, equals(1));
    });

    test(
        'constructor hydration does not rewrite restored state back to storage',
        () {
      final storage = CountingStorage()..write('TestReliabilityCubit', 42);
      expect(storage.writeCount, equals(1));

      final cubit = TestReliabilityCubit(storage: storage);
      expect(cubit.stateValue, equals(42));
      // Should not have triggered another write during hydration
      expect(storage.writeCount, equals(1));
    });

    test('nested emits preserve monotonic state order in storage', () {
      final storage = CountingStorage();
      final cubit = TestReliabilityCubit(storage: storage);

      // Attach a synchronous effect triggering nested emit when state is 1
      void Function()? cleanup;
      cleanup = effect(() {
        final val = cubit.state.value;
        if (val == 1) {
          cubit.emitCustom(2);
        }
      });

      cubit.increment(); // Emits 1, effect synchronously emits 2

      expect(cubit.stateValue, equals(2));
      // Storage must hold final state 2
      expect(storage.read('TestReliabilityCubit'), equals(2));
      expect(storage.writtenValues.last, equals(2));

      cleanup();
    });

    test(
        'uninitialized HydratedStorage.storage reports StateError to onError '
        'without silent drop in production', () {
      expect(HydratedStorage.isInitialized, isFalse);

      final cubit = TestReliabilityCubit(); // Uses uninitialized global storage

      expect(cubit.capturedErrors, isNotEmpty);
      expect(cubit.capturedErrors.first, isA<StateError>());
      expect(
        (cubit.capturedErrors.first as StateError).message,
        contains('HydratedStorage.storage must be initialized'),
      );
    });

    test(
        'fromJson returning null for non-null stored JSON routes '
        'FormatException to onError', () {
      final storage = MemoryHydratedStorage()
        ..write('UnparseableModelCubit', {'corrupted': 'schema'});

      Object? capturedError;
      final observer = _TestObserver(
        onErrorCallback: (bloc, error, stackTrace) {
          capturedError = error;
        },
      );
      BlocSignalObserver.observer = observer;

      final cubit = UnparseableModelCubit(storage: storage);

      expect(cubit.stateValue, equals(const <String, int>{}));
      expect(capturedError, isA<FormatException>());
      expect(
        capturedError.toString(),
        contains('Failed to deserialize stored JSON'),
      );

      BlocSignalObserver.observer = null;
    });

    test('HydratedBlocSignal gates equal state and closed state emits',
        () async {
      final storage = CountingStorage();
      final bloc = TestReliabilityBloc(storage: storage)..add(1);
      expect(bloc.stateValue, equals(1));
      expect(storage.writeCount, equals(1));

      bloc.add(1); // Equal state
      expect(storage.writeCount, equals(1));

      await bloc.close();
      bloc.add(2);
      expect(storage.writeCount, equals(1));
    });

    test(
      '(Issue #340) synchronous Exception in storage.read, write, and delete '
      'is caught and routed to onError',
      () async {
        final readStorage = _ConfigurableThrowingStorage(
          onRead: () => throw const FormatException('sync read exception'),
        );
        final readCubit = TestReliabilityCubit(storage: readStorage);
        addTearDown(readCubit.close);
        expect(readCubit.capturedErrors, hasLength(1));
        expect(readCubit.capturedErrors.first, isA<FormatException>());

        final writeStorage = _ConfigurableThrowingStorage(
          onWrite: () => throw Exception('sync write exception'),
          onDelete: () => throw Exception('sync delete exception'),
        );
        final writeCubit = TestReliabilityCubit(storage: writeStorage)
          ..increment();
        addTearDown(writeCubit.close);
        expect(writeCubit.capturedErrors, hasLength(1));
        expect(
          writeCubit.capturedErrors.first.toString(),
          contains('sync write exception'),
        );

        await writeCubit.clear();
        expect(writeCubit.capturedErrors, hasLength(2));
        expect(
          writeCubit.capturedErrors.last.toString(),
          contains('sync delete exception'),
        );
      },
    );

    test(
      '(Issue #340) fatal Error (StateError / AssertionError) in synchronous '
      'hydrate, persist, and clear is NOT swallowed and fails fast',
      () async {
        final fatalReadStorage = _ConfigurableThrowingStorage(
          onRead: () => throw StateError('fatal read bug'),
        );
        expect(
          () => TestReliabilityCubit(storage: fatalReadStorage),
          throwsStateError,
        );

        final fatalWriteStorage = _ConfigurableThrowingStorage(
          onWrite: () => throw AssertionError('fatal write assertion'),
        );
        final writeCubit = TestReliabilityCubit(storage: fatalWriteStorage);
        addTearDown(writeCubit.close);
        expect(
          writeCubit.increment,
          throwsA(isA<AssertionError>()),
        );
        expect(writeCubit.capturedErrors, isEmpty);

        final fatalDeleteStorage = _ConfigurableThrowingStorage(
          onDelete: () => throw StateError('fatal delete bug'),
        );
        final deleteCubit = TestReliabilityCubit(storage: fatalDeleteStorage);
        addTearDown(deleteCubit.close);
        await expectLater(
          deleteCubit.clear(),
          throwsStateError,
        );
        expect(deleteCubit.capturedErrors, isEmpty);
      },
    );

    test(
      '(Issue #340) async StateError in storage.write is NOT swallowed by '
      'catchError(onError, test: (e) => e is Exception) and surfaces as '
      'uncaught zone error',
      () async {
        final parentZone = Zone.current;
        final uncaughtCompleter = Completer<Object>();
        final asyncFatalStorage = _ConfigurableThrowingStorage(
          onWrite: () => Future<void>.error(StateError('async fatal write')),
        );
        final cubit = TestReliabilityCubit(storage: asyncFatalStorage);
        addTearDown(cubit.close);

        runZonedGuarded(
          cubit.increment,
          (error, stackTrace) {
            if (uncaughtCompleter.isCompleted) {
              parentZone.handleUncaughtError(error, stackTrace);
              return;
            }
            uncaughtCompleter.complete(error);
          },
        );

        final uncaught = await uncaughtCompleter.future.timeout(
          const Duration(milliseconds: 200),
        );
        expect(uncaught, isA<StateError>());
        expect(cubit.capturedErrors, isEmpty);
      },
    );
  });
}

class _ConfigurableThrowingStorage extends MemoryHydratedStorage {
  _ConfigurableThrowingStorage({
    this.onRead,
    this.onWrite,
    this.onDelete,
  });

  final dynamic Function()? onRead;
  final FutureOr<void> Function()? onWrite;
  final FutureOr<void> Function()? onDelete;

  @override
  dynamic read(String key) {
    if (onRead != null) return onRead!();
    return super.read(key);
  }

  @override
  FutureOr<void> write(String key, dynamic value) {
    if (onWrite != null) return onWrite!();
    super.write(key, value);
  }

  @override
  FutureOr<void> delete(String key) {
    if (onDelete != null) return onDelete!();
    super.delete(key);
  }
}

class _TestObserver extends BlocSignalObserver {
  _TestObserver({this.onErrorCallback});

  final void Function(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  )? onErrorCallback;

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);
    onErrorCallback?.call(bloc, error, stackTrace);
  }
}
