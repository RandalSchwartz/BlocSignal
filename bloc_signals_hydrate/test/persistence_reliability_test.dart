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
      '(Issue #340) fatal Error (AssertionError / StateError) in synchronous '
      'hydrate, persist, and clear is NOT swallowed and fails fast',
      () async {
        final fatalReadStorage = _ConfigurableThrowingStorage(
          onRead: () => throw AssertionError('fatal read bug'),
        );
        expect(
          () => TestReliabilityCubit(storage: fatalReadStorage),
          throwsA(isA<AssertionError>()),
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

    test(
      '(Issue #469: initHydratedState recovers from TypeError, ArgumentError, '
      'RangeError, StateError, UnsupportedError, and non-Error platform '
      'objects while propagating AssertionError)',
      () async {
        final recoverableErrors = <Object>[
          TypeError(),
          ArgumentError('bad arg'),
          RangeError('bad range'),
          StateError('bad state'),
          UnsupportedError('unsupported'),
          _FakeDomException('QuotaExceededError'),
        ];

        for (final err in recoverableErrors) {
          final cubitStorage = MemoryHydratedStorage()
            ..write('_FromJsonThrowingCubit', 99);
          final cubit = _FromJsonThrowingCubit(
            storage: cubitStorage,
            errorToThrow: err,
          );
          addTearDown(cubit.close);
          expect(cubit.stateValue, equals(0));
          expect(cubit.capturedErrors.single, same(err));

          final blocStorage = MemoryHydratedStorage()
            ..write('_FromJsonThrowingBloc', 99);
          final bloc = _FromJsonThrowingBloc(
            storage: blocStorage,
            errorToThrow: err,
          );
          addTearDown(bloc.close);
          expect(bloc.stateValue, equals(0));
          expect(bloc.capturedErrors.single, same(err));
        }

        final fatalStorage = MemoryHydratedStorage()
          ..write('_FromJsonThrowingCubit', 99);
        expect(
          () => _FromJsonThrowingCubit(
            storage: fatalStorage,
            errorToThrow: AssertionError('fatal invariant'),
          ),
          throwsA(isA<AssertionError>()),
        );
      },
    );

    test(
      '(Issue #469: persist() and clear() isolate non-Error platform objects '
      'via onError while Dart Error and toJson() Error fail fast)',
      () async {
        // Sync non-Error platform object on storage.write & storage.delete.
        final syncPlatformError = _FakeDomException('DOMException sync');
        final syncStorage = _ConfigurableThrowingStorage(
          // Simulates Web DOMException which does not extend Exception/Error.
          // ignore: only_throw_errors
          onWrite: () => throw syncPlatformError,
          // Simulates Web DOMException which does not extend Exception/Error.
          // ignore: only_throw_errors
          onDelete: () => throw syncPlatformError,
        );
        final syncCubit = TestReliabilityCubit(storage: syncStorage);
        addTearDown(syncCubit.close);
        syncCubit.increment();
        expect(syncCubit.capturedErrors.length, equals(1));
        expect(syncCubit.capturedErrors.last, same(syncPlatformError));

        await syncCubit.clear();
        expect(syncCubit.capturedErrors.length, equals(2));
        expect(syncCubit.capturedErrors.last, same(syncPlatformError));

        // Async Future.error non-Error platform object on write & delete.
        final asyncPlatformError = _FakeDomException('QuotaExceededError');
        final asyncStorage = _ConfigurableThrowingStorage(
          onWrite: () => Future<void>.error(asyncPlatformError),
          onDelete: () => Future<void>.error(asyncPlatformError),
        );
        final asyncCubit = TestReliabilityCubit(storage: asyncStorage);
        addTearDown(asyncCubit.close);
        asyncCubit.increment();
        await Future<void>.delayed(Duration.zero);
        expect(asyncCubit.capturedErrors.length, equals(1));
        expect(asyncCubit.capturedErrors.last, same(asyncPlatformError));

        await asyncCubit.clear();
        expect(asyncCubit.capturedErrors.length, equals(2));
        expect(asyncCubit.capturedErrors.last, same(asyncPlatformError));

        // Queued mutex path when storage.write is in-flight.
        final firstWriteCompleter = Completer<void>();
        var writeCount = 0;
        final queuedStorage = _ConfigurableThrowingStorage(
          onWrite: () {
            writeCount++;
            if (writeCount == 1) return firstWriteCompleter.future;
            return Future<void>.error(asyncPlatformError);
          },
        );
        final queuedCubit = TestReliabilityCubit(storage: queuedStorage);
        addTearDown(queuedCubit.close);
        queuedCubit
          ..increment() // holds _storageMutex
          ..increment(); // queued in _storageMutex.protect
        firstWriteCompleter.complete();
        await Future<void>.delayed(Duration.zero);
        expect(queuedCubit.capturedErrors.single, same(asyncPlatformError));

        // toJson() Error still fails fast.
        final toJsonErrorCubit = _ToJsonThrowingCubit(
          storage: MemoryHydratedStorage(),
        );
        addTearDown(toJsonErrorCubit.close);
        expect(
          toJsonErrorCubit.increment,
          throwsStateError,
        );
      },
    );

    test(
      '(Issue #469: queued persist() Dart Error inside _storageMutex bypasses '
      'onError, surfaces as unhandled zone error, and releases _storageMutex)',
      () async {
        final parentZone = Zone.current;
        final uncaughtCompleter = Completer<Object>();
        final firstWriteCompleter = Completer<void>();
        var writeCalls = 0;
        final writesSucceeded = <int>[];

        final storage = _ConfigurableThrowingStorage(
          onWrite: () {
            writeCalls++;
            if (writeCalls == 1) return firstWriteCompleter.future;
            if (writeCalls == 2) throw StateError('queued fatal write');
            writesSucceeded.add(writeCalls);
            return null;
          },
        );
        final cubit = TestReliabilityCubit(storage: storage);
        addTearDown(cubit.close);

        runZonedGuarded(
          () {
            cubit
              ..increment() // holds _storageMutex
              ..increment(); // queued in _storageMutex.protect
            firstWriteCompleter.complete();
          },
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

        // Verify _storageMutex was released and subsequent persist() succeeds.
        cubit.increment();
        await Future<void>.delayed(Duration.zero);
        expect(writesSucceeded, equals(<int>[3]));
      },
    );

    test(
      '(Issue #469: persist(null) storage.delete path isolates non-Error '
      'platform objects and rethrows Error; storage.read TypeError recovers)',
      () async {
        // storage.read directly throwing TypeError recovers to initialState.
        final typeErrorReadStorage = _ConfigurableThrowingStorage(
          onRead: () => throw TypeError(),
        );
        final readCubit = TestReliabilityCubit(storage: typeErrorReadStorage);
        addTearDown(readCubit.close);
        expect(readCubit.stateValue, equals(0));
        expect(readCubit.capturedErrors.single, isA<TypeError>());

        // persist(null) -> storage.delete isolating _FakeDomException.
        final domException = _FakeDomException('DOMException delete');
        final domDeleteStorage = _ConfigurableThrowingStorage(
          // Simulates Web DOMException which does not extend Exception/Error.
          // ignore: only_throw_errors
          onDelete: () => throw domException,
        );
        final domDeleteCubit = _NullableJsonCubit(storage: domDeleteStorage);
        addTearDown(domDeleteCubit.close);
        domDeleteCubit.emitNullJson();
        expect(domDeleteCubit.capturedErrors.single, same(domException));

        // persist(null) -> storage.delete rethrowing Dart Error.
        final errorDeleteStorage = _ConfigurableThrowingStorage(
          onDelete: () => throw StateError('fatal delete in persist'),
        );
        final errorDeleteCubit =
            _NullableJsonCubit(storage: errorDeleteStorage);
        addTearDown(errorDeleteCubit.close);
        expect(errorDeleteCubit.emitNullJson, throwsStateError);
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

class _FakeDomException {
  _FakeDomException(this.name);
  final String name;
  @override
  String toString() => 'DOMException: $name';
}

class _FromJsonThrowingCubit extends HydratedCubitSignal<int> {
  _FromJsonThrowingCubit({
    required this.errorToThrow,
    super.storage,
  }) : super(initialState: 0);

  final Object errorToThrow;
  final List<Object> capturedErrors = [];

  @override
  int? fromJson(dynamic json) {
    // Throws parameterized test objects including non-Error platform fakes.
    // ignore: only_throw_errors
    throw errorToThrow;
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    capturedErrors.add(error);
    super.onError(error, stackTrace);
  }
}

class _FromJsonThrowingBloc extends HydratedBlocSignal<int, int> {
  _FromJsonThrowingBloc({
    required this.errorToThrow,
    super.storage,
  }) : super(initialState: 0);

  final Object errorToThrow;
  final List<Object> capturedErrors = [];

  @override
  int? fromJson(dynamic json) {
    // Throws parameterized test objects including non-Error platform fakes.
    // ignore: only_throw_errors
    throw errorToThrow;
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    capturedErrors.add(error);
    super.onError(error, stackTrace);
  }
}

class _ToJsonThrowingCubit extends HydratedCubitSignal<int> {
  _ToJsonThrowingCubit({super.storage}) : super(initialState: 0);

  void increment() => emit(stateValue + 1);

  @override
  dynamic toJson(int state) => throw StateError('toJson bug');
}

class _NullableJsonCubit extends HydratedCubitSignal<int> {
  _NullableJsonCubit({super.storage}) : super(initialState: 0);

  final List<Object> capturedErrors = [];

  void emitNullJson() => emit(stateValue + 1);

  @override
  dynamic toJson(int state) => null;

  @override
  void onError(Object error, StackTrace stackTrace) {
    capturedErrors.add(error);
    super.onError(error, stackTrace);
  }
}
