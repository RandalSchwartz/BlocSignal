import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/secure_storage.dart';
import 'package:test/test.dart';

class FakeFlutterSecureStorage {
  final Map<String, String> _storage = {};
  bool throwOnDelete = false;

  Future<Map<String, String>> readAll() async => Map.from(_storage);

  Future<String?> read({required String key}) async => _storage[key];

  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  Future<void> delete({required String key}) async {
    if (throwOnDelete) {
      throw Exception('Secure storage delete failure');
    }
    _storage.remove(key);
  }

  Future<void> deleteAll() async {
    _storage.clear();
  }
}

class TestAuthTokenCubit extends HydratedCubitSignal<String?> {
  TestAuthTokenCubit({super.storage}) : super(initialState: null);

  void setToken(String token) => emit(token);
}

class _NonEncodableObject {}

void main() {
  late FakeFlutterSecureStorage secureStorage;

  setUp(() {
    secureStorage = FakeFlutterSecureStorage();
  });

  group('SecureHydratedStorage', () {
    test('pre-loads existing storage values via build() with default prefix',
        () async {
      await secureStorage.write(
        key: '${kDefaultHydratedStoragePrefix}auth_token',
        value: '"secret_jwt_token"',
      );
      await secureStorage.write(
        key: '${kDefaultHydratedStoragePrefix}user_id',
        value: '12345',
      );
      await secureStorage.write(
        key: '${kDefaultHydratedStoragePrefix}raw_string',
        value: 'not_json_string',
      );

      final storage = await SecureHydratedStorage.build(secureStorage);

      expect(storage.read('auth_token'), equals('secret_jwt_token'));
      expect(storage.read('user_id'), equals(12345));
      expect(() => storage.read('raw_string'), throwsFormatException);
    });

    test('pre-loads with custom prefix and isolates other keys', () async {
      await secureStorage.write(
        key: 'app_v1_key',
        value: '"scoped_value"',
      );
      await secureStorage.write(
        key: 'unrelated_secret',
        value: 'private_data',
      );

      final storage = await SecureHydratedStorage.build(
        secureStorage,
        prefix: 'app_v1_',
      );

      expect(storage.read('key'), equals('scoped_value'));
      expect(storage.read('unrelated_secret'), isNull);
    });

    test('synchronously reads and asynchronously writes new values', () async {
      final storage = await SecureHydratedStorage.build(secureStorage);

      await storage.write('session_key', 'abc-987');
      expect(storage.read('session_key'), equals('abc-987'));

      final storedValue = await secureStorage.read(
        key: '${kDefaultHydratedStoragePrefix}session_key',
      );
      expect(storedValue, equals('"abc-987"'));
    });

    test('handles delete and clear without purging unrelated secure keys',
        () async {
      await secureStorage.write(
        key: 'unrelated_token',
        value: 'do_not_delete',
      );

      final storage = await SecureHydratedStorage.build(
        secureStorage,
        prefix: 'app_',
      );

      await storage.write('k1', 'v1');
      await storage.write('k2', 'v2');

      await storage.delete('k1');
      expect(storage.read('k1'), isNull);
      expect(await secureStorage.read(key: 'app_k1'), isNull);
      expect(storage.read('k2'), equals('v2'));

      await storage.clear();
      expect(storage.read('k2'), isNull);
      expect(await secureStorage.read(key: 'app_k2'), isNull);
      // Unrelated key is preserved!
      expect(
        await secureStorage.read(key: 'unrelated_token'),
        equals('do_not_delete'),
      );
    });

    test('jsonEncode failure throws and leaves memory cache untouched',
        () async {
      final storage = await SecureHydratedStorage.build(secureStorage);
      await storage.write('valid_key', 'valid_val');
      expect(storage.read('valid_key'), equals('valid_val'));

      expect(
        () => storage.write('corrupt_key', _NonEncodableObject()),
        throwsA(isA<Object>()),
      );

      // Cache should not hold the non-encodable object
      expect(storage.read('corrupt_key'), isNull);
      expect(
        await secureStorage.read(key: 'corrupt_key'),
        isNull,
      );
    });

    test('delete failure preserves key in memory cache', () async {
      final storage = await SecureHydratedStorage.build(secureStorage);
      await storage.write('resilient_key', 'persisted_val');
      expect(storage.read('resilient_key'), equals('persisted_val'));

      secureStorage.throwOnDelete = true;

      expect(
        () => storage.delete('resilient_key'),
        throwsA(isA<Exception>()),
      );

      // Memory cache still retains the value because disk deletion failed
      expect(storage.read('resilient_key'), equals('persisted_val'));
    });

    test(
        'integrates seamlessly with HydratedCubitSignal for zero-flicker reads',
        () async {
      await secureStorage.write(
        key: '${kDefaultHydratedStoragePrefix}TestAuthTokenCubit',
        value: '"pre_existing_session_token"',
      );

      final storage = await SecureHydratedStorage.build(secureStorage);
      final cubit = TestAuthTokenCubit(storage: storage);

      expect(cubit.stateValue, equals('pre_existing_session_token'));

      cubit.setToken('new_updated_token');
      expect(cubit.stateValue, equals('new_updated_token'));

      final updatedInSecureStorage = await secureStorage.read(
        key: '${kDefaultHydratedStoragePrefix}TestAuthTokenCubit',
      );
      expect(updatedInSecureStorage, equals('"new_updated_token"'));
    });

    test(
        '(Issue #417: build() with default prefix ignores foreign/unprefixed keys)',
        () async {
      await secureStorage.write(
        key: 'foreign_oauth_token',
        value: '"do_not_load"',
      );
      await secureStorage.write(
        key: 'bloc_signals_hydrate_session',
        value: '"hydrated_value"',
      );

      final storage = await SecureHydratedStorage.build(secureStorage);

      expect(storage.prefix, equals('bloc_signals_hydrate_'));
      expect(storage.read('foreign_oauth_token'), isNull);
      expect(storage.read('session'), equals('hydrated_value'));
    });

    test(
        '(Issue #417: clear() with default prefix deletes only '
        'bloc_signals_hydrate_* keys)', () async {
      await secureStorage.write(
        key: 'foreign_secret',
        value: 'keep_me',
      );

      final storage = await SecureHydratedStorage.build(secureStorage);
      await storage.write('k1', 'v1');
      await storage.write('k2', 'v2');

      expect(
        await secureStorage.read(key: 'bloc_signals_hydrate_k1'),
        equals('"v1"'),
      );

      await storage.clear();

      expect(storage.read('k1'), isNull);
      expect(storage.read('k2'), isNull);
      expect(await secureStorage.read(key: 'bloc_signals_hydrate_k1'), isNull);
      expect(await secureStorage.read(key: 'bloc_signals_hydrate_k2'), isNull);
      expect(
        await secureStorage.read(key: 'foreign_secret'),
        equals('keep_me'),
      );
    });

    test("(Issue #417: explicit prefix: '' opts in to legacy unprefixed keys)",
        () async {
      await secureStorage.write(
        key: 'legacy_token',
        value: '"legacy_secret"',
      );

      final storage = await SecureHydratedStorage.build(
        secureStorage,
        prefix: '',
      );

      expect(storage.prefix, equals(''));
      expect(storage.read('legacy_token'), equals('legacy_secret'));
    });

    test(
        '(Issue #427: SecureHydratedStorage isolates nested Map and List '
        'mutations across write and read)', () async {
      final storage = await SecureHydratedStorage.build(secureStorage);
      final inputMap = <String, dynamic>{
        'list': <int>[1, 2],
        'nested': <String, dynamic>{'a': 1},
      };
      await storage.write('map_key', inputMap);

      // Mutating input after write must not mutate internal _cache.
      (inputMap['list'] as List<int>).add(3);
      (inputMap['nested'] as Map<String, dynamic>)['a'] = 99;
      inputMap['extra'] = true;

      final read1 = storage.read('map_key') as Map<String, dynamic>;
      expect(
        read1,
        equals(<String, dynamic>{
          'list': <int>[1, 2],
          'nested': <String, dynamic>{'a': 1},
        }),
      );

      // Mutating returned value must not mutate _cache or subsequent reads.
      (read1['list'] as List<dynamic>).add(4);
      (read1['nested'] as Map<String, dynamic>)['a'] = 88;
      read1['injected'] = 'bad';

      final read2 = storage.read('map_key') as Map<String, dynamic>;
      expect(
        read2,
        equals(<String, dynamic>{
          'list': <int>[1, 2],
          'nested': <String, dynamic>{'a': 1},
        }),
      );

      // Top-level List isolation.
      final inputList = <dynamic>[
        <String, dynamic>{'x': 1},
        <int>[2, 3],
      ];
      await storage.write('list_key', inputList);
      (inputList[0] as Map<String, dynamic>)['x'] = 42;
      (inputList[1] as List<int>).add(4);

      final readList1 = storage.read('list_key') as List<dynamic>;
      expect(
        readList1,
        equals(<dynamic>[
          <String, dynamic>{'x': 1},
          <int>[2, 3],
        ]),
      );

      (readList1[0] as Map<String, dynamic>)['x'] = 77;
      (readList1[1] as List<dynamic>).add(99);
      final readList2 = storage.read('list_key') as List<dynamic>;
      expect(
        readList2,
        equals(<dynamic>[
          <String, dynamic>{'x': 1},
          <int>[2, 3],
        ]),
      );
    });

    test(
        '(Issue #469: build() + read() rejects corrupt non-JSON entries with '
        'sanitized FormatException and HydratedCubitSignal falls back to '
        'initialState)', () async {
      const rawSecret = 'corrupt-raw-oauth-secret-999';
      await secureStorage.write(
        key: '${kDefaultHydratedStoragePrefix}_ErrorCapturingStringCubit',
        value: rawSecret,
      );

      final storage = await SecureHydratedStorage.build(secureStorage);

      Object? caught;
      try {
        storage.read('_ErrorCapturingStringCubit');
      } on FormatException catch (e) {
        caught = e;
      }
      expect(caught, isA<FormatException>());
      final formatException = caught! as FormatException;
      expect(formatException.source, isNull);
      expect(formatException.toString(), isNot(contains(rawSecret)));

      final cubit = _ErrorCapturingStringCubit(storage: storage);
      addTearDown(cubit.close);
      expect(cubit.stateValue, equals('default_token'));
      expect(cubit.capturedErrors.single, isA<FormatException>());
    });

    test(
        '(Issue #469: write(), delete(), and clear() clear corrupt key state '
        'and write() isolates _cache via cloneHydratedJsonValue)', () async {
      await secureStorage.write(
        key: '${kDefaultHydratedStoragePrefix}k_write',
        value: '{corrupt-1',
      );
      await secureStorage.write(
        key: '${kDefaultHydratedStoragePrefix}k_delete',
        value: '{corrupt-2',
      );
      await secureStorage.write(
        key: '${kDefaultHydratedStoragePrefix}k_clear',
        value: '{corrupt-3',
      );

      final storage = await SecureHydratedStorage.build(secureStorage);
      expect(() => storage.read('k_write'), throwsFormatException);
      expect(() => storage.read('k_delete'), throwsFormatException);
      expect(() => storage.read('k_clear'), throwsFormatException);

      // write() clears corrupt state and clones mutable collections.
      final mutableMap = <String, dynamic>{
        'nested': <int>[1, 2],
        'meta': <String, dynamic>{'count': 1},
      };
      await storage.write('k_write', mutableMap);
      (mutableMap['nested'] as List<int>).add(3);
      (mutableMap['meta'] as Map<String, dynamic>)['count'] = 999;
      mutableMap['injected'] = true;

      final readBack = storage.read('k_write') as Map<String, dynamic>;
      expect(identical(readBack, mutableMap), isFalse);
      expect(identical(readBack['nested'], mutableMap['nested']), isFalse);
      expect(identical(readBack['meta'], mutableMap['meta']), isFalse);
      expect(
        readBack,
        equals(<String, dynamic>{
          'nested': <int>[1, 2],
          'meta': <String, dynamic>{'count': 1},
        }),
      );

      // delete() clears corrupt state.
      await storage.delete('k_delete');
      expect(storage.read('k_delete'), isNull);

      // clear() clears corrupt state and underlying storage.
      await storage.clear();
      expect(storage.read('k_clear'), isNull);
      expect(
        await secureStorage.read(
          key: '${kDefaultHydratedStoragePrefix}k_clear',
        ),
        isNull,
      );
    });

    test(
        '(Issue #469: write() stores decoded JSON snapshot for '
        'toJson()-encodable objects)', () async {
      final storage = await SecureHydratedStorage.build(secureStorage);
      final payload = _ToJsonPayload(
        tags: <String>['alpha', 'beta'],
        nested: <String, dynamic>{'count': 1},
      );

      await storage.write('obj_key', payload);
      payload.tags.add('gamma');
      payload.nested['count'] = 999;

      final readBack = storage.read('obj_key') as Map<String, dynamic>;
      expect(
        readBack,
        equals(<String, dynamic>{
          'tags': <String>['alpha', 'beta'],
          'nested': <String, dynamic>{'count': 1},
        }),
      );
    });
  });
}

class _ToJsonPayload {
  _ToJsonPayload({required this.tags, required this.nested});

  final List<String> tags;
  final Map<String, dynamic> nested;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tags': tags,
        'nested': nested,
      };
}

class _ErrorCapturingStringCubit extends HydratedCubitSignal<String> {
  _ErrorCapturingStringCubit({super.storage})
      : super(initialState: 'default_token');

  final List<Object> capturedErrors = [];

  @override
  void onError(Object error, StackTrace stackTrace) {
    capturedErrors.add(error);
    super.onError(error, stackTrace);
  }
}
