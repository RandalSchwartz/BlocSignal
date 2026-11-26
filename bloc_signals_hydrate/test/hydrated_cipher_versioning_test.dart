import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:test/test.dart';

class _XorBase64Cipher implements HydratedCipher {
  const _XorBase64Cipher({this.tamperOnDecrypt = false});

  final bool tamperOnDecrypt;

  @override
  dynamic encrypt(dynamic data) {
    return <String, dynamic>{'enc': true, 'payload': data};
  }

  @override
  dynamic decrypt(dynamic data) {
    if (tamperOnDecrypt) {
      throw const FormatException('Tampered ciphertext');
    }
    if (data is Map && data['enc'] == true) {
      return data['payload'];
    }
    throw const FormatException('Invalid cipher envelope');
  }
}

class _EncryptedCounterCubit extends HydratedCubitSignal<int> {
  _EncryptedCounterCubit({
    required HydratedCipher cipher,
    super.storage,
  })  : _cipher = cipher,
        super(initialState: 0);

  final HydratedCipher _cipher;
  final List<Object> errors = <Object>[];

  @override
  HydratedCipher get cipher => _cipher;

  void increment() => emit(stateValue + 1);

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state;

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

class _CappedMapCubit extends HydratedCubitSignal<Map<String, dynamic>> {
  _CappedMapCubit({
    required int maxBytes,
    super.storage,
    HydratedCipher? cipher,
  })  : _maxBytes = maxBytes,
        _cipher = cipher,
        super(initialState: const <String, dynamic>{'text': 'init'});

  final int _maxBytes;
  final HydratedCipher? _cipher;
  final List<Object> errors = <Object>[];

  @override
  int get maxPayloadBytes => _maxBytes;

  @override
  HydratedCipher? get cipher => _cipher;

  void setText(String text) => emit(<String, dynamic>{'text': text});

  @override
  Map<String, dynamic>? fromJson(dynamic json) =>
      (json as Map?)?.cast<String, dynamic>();

  @override
  dynamic toJson(Map<String, dynamic> state) => state;

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

class _VersionedProfileCubit extends HydratedCubitSignal<Map<String, dynamic>> {
  _VersionedProfileCubit({
    required int version,
    super.storage,
    HydratedCipher? cipher,
  })  : _version = version,
        _cipher = cipher,
        super(initialState: const <String, dynamic>{'name': 'anon', 'v': 2});

  final int _version;
  final HydratedCipher? _cipher;
  final List<int> migratedFromVersions = <int>[];

  @override
  int get storageVersion => _version;

  @override
  HydratedCipher? get cipher => _cipher;

  @override
  String get storagePrefix => 'VersionedProfile';

  @override
  dynamic migrate(dynamic json, int fromVersion) {
    migratedFromVersions.add(fromVersion);
    if (json is Map) {
      return <String, dynamic>{
        ...json.cast<String, dynamic>(),
        'migratedFrom': fromVersion,
        'v': _version,
      };
    }
    return json;
  }

  void updateName(String name) =>
      emit(<String, dynamic>{...stateValue, 'name': name});

  @override
  Map<String, dynamic>? fromJson(dynamic json) =>
      (json as Map?)?.cast<String, dynamic>();

  @override
  dynamic toJson(Map<String, dynamic> state) => state;
}

class _NullableWriteCubit extends HydratedCubitSignal<int?> {
  _NullableWriteCubit({
    super.storage,
    HydratedCipher? cipher,
    int? version,
  })  : _cipher = cipher,
        _version = version,
        super(initialState: 1);

  final HydratedCipher? _cipher;
  final int? _version;

  @override
  HydratedCipher? get cipher => _cipher;

  @override
  int? get storageVersion => _version;

  void setVal(int? val) => emit(val);

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int? state) => state;
}

class _NullTrackingCipher implements HydratedCipher {
  int encryptCalls = 0;

  @override
  dynamic encrypt(dynamic data) {
    encryptCalls++;
    return <String, dynamic>{'enc': data};
  }

  @override
  dynamic decrypt(dynamic data) => (data as Map)['enc'];
}

class _ThrowOnEncryptCipher implements HydratedCipher {
  const _ThrowOnEncryptCipher({this.shouldThrow = false});

  final bool shouldThrow;

  @override
  dynamic encrypt(dynamic data) {
    if (shouldThrow) {
      throw const FormatException('Encrypt failed');
    }
    return data;
  }

  @override
  dynamic decrypt(dynamic data) => data;
}

class _DefaultMigrateCubit extends HydratedCubitSignal<int> {
  _DefaultMigrateCubit({super.storage}) : super(initialState: 0);

  @override
  int get storageVersion => 2;

  @override
  String get storagePrefix => 'DefaultMigrate';

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state;
}

class _StringEnvelopeCipher implements HydratedCipher {
  const _StringEnvelopeCipher();

  @override
  dynamic encrypt(dynamic data) =>
      'enc:${(data as Map)['__bloc_signals_data__']}';

  @override
  dynamic decrypt(dynamic data) {
    if (data is String && data.startsWith('enc:')) {
      return <String, dynamic>{
        '__bloc_signals_version__': 2,
        '__bloc_signals_data__': data.substring(4),
      };
    }
    throw const FormatException('Invalid string cipher');
  }
}

class _StringCappedCipherCubit extends HydratedCubitSignal<String> {
  _StringCappedCipherCubit({
    required int maxBytes,
    super.storage,
  })  : _maxBytes = maxBytes,
        super(initialState: 'a');

  final int _maxBytes;
  final List<Object> errors = <Object>[];

  @override
  int get maxPayloadBytes => _maxBytes;

  @override
  int get storageVersion => 2;

  @override
  HydratedCipher get cipher => const _StringEnvelopeCipher();

  void setValue(String value) => emit(value);

  @override
  String? fromJson(dynamic json) => json as String?;

  @override
  dynamic toJson(String state) => state;

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

class _EncryptErrorCubit extends HydratedCubitSignal<int> {
  _EncryptErrorCubit({
    required this.encryptCipher,
    super.storage,
  }) : super(initialState: 0);

  _ThrowOnEncryptCipher encryptCipher;
  final List<Object> errors = <Object>[];

  @override
  HydratedCipher get cipher => encryptCipher;

  void setVal(int v) => emit(v);

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state;

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

class _VersionedErrorCubit extends _VersionedProfileCubit {
  _VersionedErrorCubit({required super.version, super.storage});

  final List<Object> errors = <Object>[];

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

sealed class _HydratedBlocEvent {}

final class _SetProfileName extends _HydratedBlocEvent {
  _SetProfileName(this.name);
  final String name;
}

class _CombinedHydratedBloc
    extends HydratedBlocSignal<_HydratedBlocEvent, Map<String, dynamic>> {
  _CombinedHydratedBloc({
    required int version,
    required int maxBytes,
    super.storage,
  })  : _version = version,
        _maxBytes = maxBytes,
        super(initialState: const <String, dynamic>{'name': 'anon'}) {
    on<_SetProfileName>(
      (event, emit) => emit(<String, dynamic>{'name': event.name}),
    );
  }

  final int _version;
  final int _maxBytes;
  final List<Object> errors = <Object>[];

  @override
  int get storageVersion => _version;

  @override
  int get maxPayloadBytes => _maxBytes;

  @override
  HydratedCipher get cipher => const _XorBase64Cipher();

  @override
  String get storagePrefix => 'CombinedHydratedBloc';

  @override
  dynamic migrate(dynamic json, int fromVersion) {
    if (json is Map) {
      return <String, dynamic>{
        ...json.cast<String, dynamic>(),
        'migratedFrom': fromVersion,
      };
    }
    return json;
  }

  @override
  Map<String, dynamic>? fromJson(dynamic json) =>
      (json as Map?)?.cast<String, dynamic>();

  @override
  dynamic toJson(Map<String, dynamic> state) => state;

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

void main() {
  late MemoryHydratedStorage storage;

  setUp(() {
    storage = MemoryHydratedStorage();
    HydratedStorage.storage = storage;
  });

  tearDown(HydratedStorage.reset);

  group('(Issue #479) HydratedCipher', () {
    test('encrypts on write and decrypts on hydration round-trip', () async {
      const cipher = _XorBase64Cipher();
      final cubit1 = _EncryptedCounterCubit(cipher: cipher, storage: storage)
        ..increment()
        ..increment();

      final rawStored = storage.read(cubit1.storageToken);
      expect(rawStored, isA<Map<String, dynamic>>());
      expect((rawStored as Map)['enc'], isTrue);
      expect(rawStored['payload'], 2);

      await cubit1.close();

      final cubit2 = _EncryptedCounterCubit(cipher: cipher, storage: storage);
      expect(cubit2.stateValue, 2);
      expect(cubit2.errors, isEmpty);
      await cubit2.close();
    });

    test('falls back to initialState and reports to onError on tamper',
        () async {
      const writeCipher = _XorBase64Cipher();
      final cubit1 =
          _EncryptedCounterCubit(cipher: writeCipher, storage: storage)
            ..increment();
      await cubit1.close();

      const tamperCipher = _XorBase64Cipher(tamperOnDecrypt: true);
      final cubit2 =
          _EncryptedCounterCubit(cipher: tamperCipher, storage: storage);
      expect(cubit2.stateValue, 0);
      expect(cubit2.errors, hasLength(1));
      expect(cubit2.errors.first, isA<FormatException>());
      await cubit2.close();
    });
  });

  group('(Issue #479) maxPayloadBytes', () {
    test('aborts write and reports FormatException when payload exceeds cap',
        () async {
      final cubit = _CappedMapCubit(maxBytes: 20, storage: storage)
        ..setText('ok');
      expect(storage.read(cubit.storageToken), <String, dynamic>{'text': 'ok'});
      expect(cubit.errors, isEmpty);

      cubit.setText('this string is definitely much longer than twenty bytes');
      expect(cubit.errors, hasLength(1));
      expect(cubit.errors.first, isA<FormatException>());
      // Storage retains the previous valid payload; oversized write aborted.
      expect(storage.read(cubit.storageToken), <String, dynamic>{'text': 'ok'});
      await cubit.close();
    });
  });

  group('(Issue #479) storageVersion and migrate', () {
    test('migrates versioned payload v1 -> v2 and skips when same version',
        () async {
      storage.write('VersionedProfile', <String, dynamic>{
        '__bloc_signals_version__': 1,
        '__bloc_signals_data__': <String, dynamic>{'name': 'Alice'},
      });

      final cubitV2 = _VersionedProfileCubit(version: 2, storage: storage);
      expect(cubitV2.migratedFromVersions, <int>[1]);
      expect(cubitV2.stateValue, <String, dynamic>{
        'name': 'Alice',
        'migratedFrom': 1,
        'v': 2,
      });

      cubitV2.updateName('Bob');
      await cubitV2.close();

      final cubitV2Reloaded =
          _VersionedProfileCubit(version: 2, storage: storage);
      expect(cubitV2Reloaded.migratedFromVersions, isEmpty);
      expect(cubitV2Reloaded.stateValue['name'], 'Bob');
      await cubitV2Reloaded.close();
    });

    test('migrates legacy unversioned payload from version 0 -> v2', () async {
      storage.write('VersionedProfile', <String, dynamic>{'name': 'Legacy'});

      final cubit = _VersionedProfileCubit(version: 2, storage: storage);
      expect(cubit.migratedFromVersions, <int>[0]);
      expect(cubit.stateValue, <String, dynamic>{
        'name': 'Legacy',
        'migratedFrom': 0,
        'v': 2,
      });
      await cubit.close();
    });
  });

  group('(Issue #479) toJson null delete bypass', () {
    test('deletes key without wrapping or encrypting null', () async {
      final cipher = _NullTrackingCipher();
      final cubit = _NullableWriteCubit(
        storage: storage,
        cipher: cipher,
        version: 1,
      )..setVal(42);
      expect(cipher.encryptCalls, 1);
      expect(storage.read(cubit.storageToken), isNotNull);

      cubit.setVal(null);
      expect(cipher.encryptCalls, 1);
      expect(storage.read(cubit.storageToken), isNull);
      await cubit.close();
    });
  });

  group('(Issue #479) Edge cases and combined round-trips', () {
    test('BLOCKER-2: default migrate() returns payload unchanged', () async {
      storage.write('DefaultMigrate', 42);
      final cubit = _DefaultMigrateCubit(storage: storage);
      expect(cubit.stateValue, 42);
      await cubit.close();
    });

    test('BLOCKER-3: non-int __bloc_signals_version__ reports FormatException',
        () async {
      storage.write('VersionedProfile', <String, dynamic>{
        '__bloc_signals_version__': '1',
        '__bloc_signals_data__': <String, dynamic>{'name': 'Bad'},
      });

      final cubit = _VersionedErrorCubit(version: 2, storage: storage);
      expect(cubit.stateValue, const <String, dynamic>{'name': 'anon', 'v': 2});
      expect(cubit.errors, hasLength(1));
      expect(cubit.errors.first, isA<FormatException>());
      await cubit.close();
    });

    test('BLOCKER-4: cipher.encrypt() Exception routes to onError and aborts',
        () async {
      final cubit = _EncryptErrorCubit(
        encryptCipher: const _ThrowOnEncryptCipher(),
        storage: storage,
      )..setVal(5);
      expect(storage.read(cubit.storageToken), 5);
      expect(cubit.errors, isEmpty);

      cubit
        ..encryptCipher = const _ThrowOnEncryptCipher(shouldThrow: true)
        ..setVal(99);
      expect(cubit.errors, hasLength(1));
      expect(cubit.errors.first, isA<FormatException>());
      expect(storage.read(cubit.storageToken), 5);
      await cubit.close();
    });

    test(
        'NBO-1: String-returning cipher enforces exact UTF-8 maxPayloadBytes '
        'boundary with multi-byte characters', () async {
      // 'enc:' (4 bytes) + '€' (3 bytes) = 7 bytes -> allowed at maxBytes: 7.
      // 'enc:' (4 bytes) + '🚀' (4 bytes) = 8 bytes -> rejected at maxBytes: 7.
      final cubit = _StringCappedCipherCubit(maxBytes: 7, storage: storage)
        ..setValue('€');
      expect(cubit.errors, isEmpty);
      expect(storage.read(cubit.storageToken), 'enc:€');

      cubit.setValue('🚀');
      expect(cubit.errors, hasLength(1));
      expect(cubit.errors.first, isA<FormatException>());
      expect(storage.read(cubit.storageToken), 'enc:€');

      await cubit.close();

      final reloaded = _StringCappedCipherCubit(maxBytes: 7, storage: storage);
      expect(reloaded.stateValue, '€');
      await reloaded.close();
    });

    test(
        'NBO-2: combined storageVersion + HydratedCipher + maxPayloadBytes '
        'round-trip on HydratedBlocSignal', () async {
      storage.write(
        'CombinedHydratedBloc',
        const _XorBase64Cipher().encrypt(<String, dynamic>{
          '__bloc_signals_version__': 1,
          '__bloc_signals_data__': <String, dynamic>{'name': 'Alice'},
        }),
      );

      final bloc1 = _CombinedHydratedBloc(
        version: 2,
        maxBytes: 256,
        storage: storage,
      );
      expect(bloc1.stateValue, <String, dynamic>{
        'name': 'Alice',
        'migratedFrom': 1,
      });
      expect(bloc1.errors, isEmpty);

      bloc1.add(_SetProfileName('Bob'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc1.stateValue, <String, dynamic>{'name': 'Bob'});
      await bloc1.close();

      final bloc2 = _CombinedHydratedBloc(
        version: 2,
        maxBytes: 256,
        storage: storage,
      );
      expect(bloc2.stateValue, <String, dynamic>{'name': 'Bob'});
      await bloc2.close();
    });
  });
}
