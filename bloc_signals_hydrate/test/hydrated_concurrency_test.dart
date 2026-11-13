import 'dart:async';

import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/secure_storage.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:test/test.dart';

class _ControlledHydratedStorage implements HydratedStorage {
  final Map<String, dynamic> data = {};
  final List<String> log = [];

  Completer<void>? nextWriteCompleter;
  Completer<void>? nextDeleteCompleter;
  Completer<void>? nextClearCompleter;
  Exception? nextWriteError;
  Exception? nextDeleteError;

  final List<Completer<void>> writeStarted = [];
  final List<Completer<void>> deleteStarted = [];

  @override
  dynamic read(String key) => data[key];

  @override
  FutureOr<void> write(String key, dynamic value) async {
    log.add('write:$key:$value:start');
    final started = Completer<void>()..complete();
    writeStarted.add(started);

    final gate = nextWriteCompleter;
    nextWriteCompleter = null;
    if (gate != null) {
      await gate.future;
    }

    final error = nextWriteError;
    nextWriteError = null;
    if (error != null) {
      log.add('write:$key:$value:error');
      throw error;
    }

    data[key] = value;
    log.add('write:$key:$value:end');
  }

  @override
  FutureOr<void> delete(String key) async {
    log.add('delete:$key:start');
    final started = Completer<void>()..complete();
    deleteStarted.add(started);

    final gate = nextDeleteCompleter;
    nextDeleteCompleter = null;
    if (gate != null) {
      await gate.future;
    }

    final error = nextDeleteError;
    nextDeleteError = null;
    if (error != null) {
      log.add('delete:$key:error');
      throw error;
    }

    data.remove(key);
    log.add('delete:$key:end');
  }

  @override
  FutureOr<void> clear() async {
    log.add('clear:start');
    final gate = nextClearCompleter;
    nextClearCompleter = null;
    if (gate != null) {
      await gate.future;
    }
    data.clear();
    log.add('clear:end');
  }
}

class _ControlledSecureStorage {
  final Map<String, String> backing = {};
  final List<String> log = [];
  final Map<String, Completer<void>> _writeGates = {};
  final Map<String, Completer<void>> _deleteGates = {};
  Completer<void>? nextWriteStarted;
  Completer<void>? nextDeleteStarted;

  void gateWrite(String prefixedKey, Completer<void> completer) {
    _writeGates[prefixedKey] = completer;
  }

  void gateDelete(String prefixedKey, Completer<void> completer) {
    _deleteGates[prefixedKey] = completer;
  }

  Future<Map<String, String>> readAll() async => Map.from(backing);

  Future<void> write({required String key, required String value}) async {
    log.add('write:$key:$value:start');
    nextWriteStarted?.complete();
    nextWriteStarted = null;
    final gate = _writeGates.remove(key);
    if (gate != null) {
      await gate.future;
    }
    backing[key] = value;
    log.add('write:$key:$value:end');
  }

  Future<void> delete({required String key}) async {
    log.add('delete:$key:start');
    nextDeleteStarted?.complete();
    nextDeleteStarted = null;
    final gate = _deleteGates.remove(key);
    if (gate != null) {
      await gate.future;
    }
    backing.remove(key);
    log.add('delete:$key:end');
  }
}

class _ControlledSharedPreferences {
  final Map<String, String> backing = {};
  final List<String> log = [];
  Completer<void>? nextSetStringGate;
  Completer<void>? nextRemoveGate;
  Completer<void>? nextSetStringStarted;

  String? getString(String key) => backing[key];

  Set<String> getKeys() => backing.keys.toSet();

  Future<bool> setString(String key, String value) async {
    log.add('setString:$key:$value:start');
    nextSetStringStarted?.complete();
    nextSetStringStarted = null;
    final gate = nextSetStringGate;
    nextSetStringGate = null;
    if (gate != null) {
      await gate.future;
    }
    backing[key] = value;
    log.add('setString:$key:$value:end');
    return true;
  }

  Future<bool> remove(String key) async {
    log.add('remove:$key:start');
    final gate = nextRemoveGate;
    nextRemoveGate = null;
    if (gate != null) {
      await gate.future;
    }
    backing.remove(key);
    log.add('remove:$key:end');
    return true;
  }
}

class _AuthCubit extends HydratedCubitSignal<String?> {
  _AuthCubit({
    required HydratedStorage storage,
    this.onErrorCallback,
  }) : super(initialState: null, storage: storage);

  final void Function(Object error, StackTrace stackTrace)? onErrorCallback;

  void login(String token) => emit(token);

  @override
  void onError(Object error, StackTrace stackTrace) {
    onErrorCallback?.call(error, stackTrace);
    super.onError(error, stackTrace);
  }
}

void main() {
  group('(Issue #416) HydratedMixin & storage concurrency serialization', () {
    test(
      'delayed persist(S1) followed by await clear() does not resurrect S1 '
      'in storage or SecureHydratedStorage cache',
      () async {
        final rawSecure = _ControlledSecureStorage();
        final storage = await SecureHydratedStorage.build(rawSecure);
        final cubit = _AuthCubit(storage: storage);
        addTearDown(cubit.close);

        final tokenKey = '$kDefaultHydratedStoragePrefix${cubit.storageToken}';
        final slowWriteGate = Completer<void>();
        final writeStarted = Completer<void>();
        rawSecure
          ..gateWrite(tokenKey, slowWriteGate)
          ..nextWriteStarted = writeStarted;

        // Trigger S1 persistence that stalls on secure storage I/O.
        cubit.login('S1-secret-token');
        await writeStarted.future;

        // Logout / clear while S1 write is still in-flight.
        var clearCompleted = false;
        final clearFuture = cubit.clear().then((_) {
          clearCompleted = true;
        });

        // Pump microtasks: clear() must wait behind the in-flight write.
        await Future<void>.microtask(() {});
        expect(clearCompleted, isFalse);

        // Release the stalled write; clear() should then run and delete S1.
        slowWriteGate.complete();
        await clearFuture;

        expect(clearCompleted, isTrue);
        expect(cubit.stateValue, isNull);
        expect(storage.read(cubit.storageToken), isNull);
        expect(rawSecure.backing[tokenKey], isNull);
      },
    );

    test(
      'rapid emit(S1) -> emit(S2) -> emit(S3) skips superseded S2 and '
      'persists S3 in order',
      () async {
        final storage = _ControlledHydratedStorage();
        final cubit = _AuthCubit(storage: storage);
        addTearDown(cubit.close);

        final firstWriteGate = Completer<void>();
        storage.nextWriteCompleter = firstWriteGate;

        cubit
          ..login('S1')
          ..login('S2')
          ..login('S3');

        // Let microtasks run so S1 acquires the mutex and stalls on I/O,
        // while S2 and S3 queue behind it.
        await Future<void>.microtask(() {});
        expect(
          storage.log,
          equals(['write:${cubit.storageToken}:S1:start']),
        );

        // Complete S1's write; S2 must be skipped (superseded by S3) and S3
        // must be persisted.
        firstWriteGate.complete();
        await pumpEventQueue();

        expect(storage.data[cubit.storageToken], equals('S3'));
        expect(
          storage.log,
          equals([
            'write:${cubit.storageToken}:S1:start',
            'write:${cubit.storageToken}:S1:end',
            'write:${cubit.storageToken}:S3:start',
            'write:${cubit.storageToken}:S3:end',
          ]),
        );
      },
    );

    test(
      'SecureHydratedStorage concurrent write + delete + clear preserves '
      '_cache and underlying storage consistency',
      () async {
        final rawSecure = _ControlledSecureStorage();
        final storage = await SecureHydratedStorage.build(rawSecure);

        const k1 = '${kDefaultHydratedStoragePrefix}session';
        final writeGate = Completer<void>();
        final writeStarted = Completer<void>();
        rawSecure
          ..gateWrite(k1, writeGate)
          ..nextWriteStarted = writeStarted;

        // Start a slow write for 'session'.
        final writeFuture = Future<void>.value(storage.write('session', 'v1'));
        await writeStarted.future;

        // Concurrently issue delete('session') and clear() while write is
        // still in flight.
        final deleteFuture = Future<void>.value(storage.delete('session'));
        final clearFuture = Future<void>.value(storage.clear());

        await Future<void>.microtask(() {});
        // Delete must not overtake the in-flight write.
        expect(
          rawSecure.log,
          equals(['write:$k1:"v1":start']),
        );

        writeGate.complete();
        await Future.wait([writeFuture, deleteFuture, clearFuture]);

        expect(storage.read('session'), isNull);
        expect(rawSecure.backing, isEmpty);
        expect(
          rawSecure.log,
          equals([
            'write:$k1:"v1":start',
            'write:$k1:"v1":end',
            'delete:$k1:start',
            'delete:$k1:end',
          ]),
        );
      },
    );

    test(
      'SharedPreferencesHydratedStorage concurrent write + delete + clear '
      'serializes operations while preserving const constructor',
      () async {
        const prefsMarker = 'const_supported';
        const constCheck = SharedPreferencesHydratedStorage(prefsMarker);
        expect(constCheck.prefix, equals(kDefaultHydratedStoragePrefix));

        final prefs = _ControlledSharedPreferences();
        final storage = SharedPreferencesHydratedStorage(prefs);

        final writeGate = Completer<void>();
        final writeStarted = Completer<void>();
        prefs
          ..nextSetStringGate = writeGate
          ..nextSetStringStarted = writeStarted;

        final writeFuture = Future<void>.value(storage.write('auth', 'tok1'));
        await writeStarted.future;

        final deleteFuture = Future<void>.value(storage.delete('auth'));
        final clearFuture = Future<void>.value(storage.clear());

        await Future<void>.microtask(() {});
        // Delete must wait for the in-flight write to finish.
        expect(
          prefs.log,
          equals([
            'setString:${kDefaultHydratedStoragePrefix}auth:"tok1":start',
          ]),
        );

        writeGate.complete();
        await Future.wait([writeFuture, deleteFuture, clearFuture]);

        expect(storage.read('auth'), isNull);
        expect(prefs.backing, isEmpty);
        expect(
          prefs.log,
          equals([
            'setString:${kDefaultHydratedStoragePrefix}auth:"tok1":start',
            'setString:${kDefaultHydratedStoragePrefix}auth:"tok1":end',
            'remove:${kDefaultHydratedStoragePrefix}auth:start',
            'remove:${kDefaultHydratedStoragePrefix}auth:end',
          ]),
        );
      },
    );

    test(
      'Exception during serialized persist / clear routes to onError without '
      'deadlocking subsequent operations',
      () async {
        final storage = _ControlledHydratedStorage();
        final errors = <Object>[];
        final cubit = _AuthCubit(
          storage: storage,
          onErrorCallback: (error, _) => errors.add(error),
        );
        addTearDown(cubit.close);

        storage.nextWriteError = Exception('disk full');
        cubit.login('S1');

        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        expect(errors, hasLength(1));
        expect(errors.first.toString(), contains('disk full'));

        // Subsequent persist must succeed without deadlock.
        cubit.login('S2');
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        expect(storage.data[cubit.storageToken], equals('S2'));

        // Exception during clear() must also route to onError and not deadlock.
        storage.nextDeleteError = Exception('delete failed');
        await cubit.clear();
        expect(errors, hasLength(2));
        expect(errors.last.toString(), contains('delete failed'));
        expect(cubit.stateValue, isNull);

        // Subsequent persist after failed clear() still works.
        cubit.login('S3');
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});
        expect(storage.data[cubit.storageToken], equals('S3'));
      },
    );

    test(
      'queued persist(null) and queued persist Exception behind an in-flight '
      'write execute in order and route errors to onError',
      () async {
        final storage = _ControlledHydratedStorage();
        final errors = <Object>[];
        final cubit = _AuthCubit(
          storage: storage,
          onErrorCallback: (error, _) => errors.add(error),
        );
        addTearDown(cubit.close);

        // Stall S1 write, then queue S2 (which will fail) while locked.
        final firstGate = Completer<void>();
        storage.nextWriteCompleter = firstGate;
        cubit.login('S1');
        await Future<void>.microtask(() {});

        final secondGate = Completer<void>();
        storage.nextWriteCompleter = secondGate;
        cubit.login('S2');

        firstGate.complete();
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});

        storage.nextWriteError = Exception('queued write failure');
        secondGate.complete();
        await pumpEventQueue();
        expect(errors, hasLength(1));
        expect(errors.first.toString(), contains('queued write failure'));

        // Stall S3 write, then queue null (toJson -> null -> delete) while
        // locked.
        final thirdGate = Completer<void>();
        storage.nextWriteCompleter = thirdGate;
        cubit.login('S3');
        await Future<void>.microtask(() {});

        cubit.emit(null);
        thirdGate.complete();
        await pumpEventQueue();

        expect(storage.data[cubit.storageToken], isNull);
      },
    );

    test(
      'Exception thrown by toJson() routes to onError without locking storage',
      () async {
        final storage = _ControlledHydratedStorage();
        final errors = <Object>[];
        final cubit = _ThrowingToJsonCubit(
          storage: storage,
          onErrorCallback: (error, _) => errors.add(error),
        );
        addTearDown(cubit.close);

        cubit
          ..shouldThrow = true
          ..emit('bad');
        expect(errors, hasLength(1));
        expect(errors.first.toString(), contains('toJson failed'));

        // Subsequent valid emit still persists cleanly.
        cubit
          ..shouldThrow = false
          ..emit('good');
        await pumpEventQueue();
        expect(storage.data[cubit.storageToken], equals('good'));
      },
    );
  });
}

class _ThrowingToJsonCubit extends HydratedCubitSignal<String?> {
  _ThrowingToJsonCubit({
    required HydratedStorage storage,
    required this.onErrorCallback,
  }) : super(initialState: null, storage: storage);

  final void Function(Object error, StackTrace stackTrace) onErrorCallback;
  bool shouldThrow = false;

  @override
  dynamic toJson(String? state) {
    if (shouldThrow) {
      throw const FormatException('toJson failed');
    }
    return state;
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    onErrorCallback(error, stackTrace);
    super.onError(error, stackTrace);
  }
}
