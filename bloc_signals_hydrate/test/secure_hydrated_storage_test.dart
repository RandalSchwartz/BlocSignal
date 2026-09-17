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
        key: 'auth_token',
        value: '"secret_jwt_token"',
      );
      await secureStorage.write(
        key: 'user_id',
        value: '12345',
      );
      await secureStorage.write(
        key: 'raw_string',
        value: 'not_json_string',
      );

      final storage = await SecureHydratedStorage.build(secureStorage);

      expect(storage.read('auth_token'), equals('secret_jwt_token'));
      expect(storage.read('user_id'), equals(12345));
      expect(storage.read('raw_string'), equals('not_json_string'));
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

      final storedValue = await secureStorage.read(key: 'session_key');
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
        key: 'TestAuthTokenCubit',
        value: '"pre_existing_session_token"',
      );

      final storage = await SecureHydratedStorage.build(secureStorage);
      final cubit = TestAuthTokenCubit(storage: storage);

      expect(cubit.stateValue, equals('pre_existing_session_token'));

      cubit.setToken('new_updated_token');
      expect(cubit.stateValue, equals('new_updated_token'));

      final updatedInSecureStorage =
          await secureStorage.read(key: 'TestAuthTokenCubit');
      expect(updatedInSecureStorage, equals('"new_updated_token"'));
    });
  });
}
