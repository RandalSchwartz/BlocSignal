import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/secure_storage.dart';
import 'package:test/test.dart';

class FakeFlutterSecureStorage {
  final Map<String, String> _storage = {};

  Future<Map<String, String>> readAll() async => Map.from(_storage);

  Future<String?> read({required String key}) async => _storage[key];

  Future<void> write({required String key, required String value}) async {
    _storage[key] = value;
  }

  Future<void> delete({required String key}) async {
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

void main() {
  late FakeFlutterSecureStorage secureStorage;

  setUp(() {
    secureStorage = FakeFlutterSecureStorage();
  });

  group('SecureHydratedStorage', () {
    test('pre-loads existing storage values via build()', () async {
      await secureStorage.write(key: 'auth_token', value: '"secret_jwt_token"');
      await secureStorage.write(key: 'user_id', value: '12345');
      await secureStorage.write(key: 'raw_string', value: 'not_json_string');

      final storage = await SecureHydratedStorage.build(secureStorage);

      expect(storage.read('auth_token'), equals('secret_jwt_token'));
      expect(storage.read('user_id'), equals(12345));
      expect(storage.read('raw_string'), equals('not_json_string'));
    });

    test('synchronously reads and asynchronously writes new values', () async {
      final storage = await SecureHydratedStorage.build(secureStorage);

      await storage.write('session_key', 'abc-987');
      expect(storage.read('session_key'), equals('abc-987'));

      final storedValue = await secureStorage.read(key: 'session_key');
      expect(storedValue, equals('"abc-987"'));
    });

    test('handles delete and clear across cache and underlying secure storage',
        () async {
      final storage = await SecureHydratedStorage.build(secureStorage);

      await storage.write('k1', 'v1');
      await storage.write('k2', 'v2');

      await storage.delete('k1');
      expect(storage.read('k1'), isNull);
      expect(await secureStorage.read(key: 'k1'), isNull);
      expect(storage.read('k2'), equals('v2'));

      await storage.clear();
      expect(storage.read('k2'), isNull);
      expect(await secureStorage.readAll(), isEmpty);
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
