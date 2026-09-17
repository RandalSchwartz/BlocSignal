import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:test/test.dart';

class FakeSharedPreferences {
  final Map<String, String> _storage = {};

  String? getString(String key) => _storage[key];

  Set<String> getKeys() => _storage.keys.toSet();

  Future<bool> setString(String key, String value) async {
    _storage[key] = value;
    return true;
  }

  Future<bool> remove(String key) async {
    _storage.remove(key);
    return true;
  }

  Future<bool> clear() async {
    _storage.clear();
    return true;
  }
}

class TestCounterCubit extends HydratedCubitSignal<int> {
  TestCounterCubit({super.storage}) : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

class TestListCubit extends HydratedCubitSignal<List<String>> {
  TestListCubit({super.storage}) : super(initialState: const []);

  void add(String item) => emit([...stateValue, item]);
}

void main() {
  late FakeSharedPreferences prefs;
  late SharedPreferencesHydratedStorage storage;

  setUp(() {
    prefs = FakeSharedPreferences();
    storage = SharedPreferencesHydratedStorage(prefs);
  });

  group('SharedPreferencesHydratedStorage', () {
    test('reads and writes primitive values with default prefix', () async {
      await storage.write('counter', 42);
      expect(storage.read('counter'), equals(42));
      expect(prefs.getString('counter'), equals('42'));
    });

    test('supports custom prefix scoping', () async {
      final scopedStorage = SharedPreferencesHydratedStorage(
        prefs,
        prefix: 'scoped_',
      );

      await scopedStorage.write('token', 'abc-123');
      expect(scopedStorage.read('token'), equals('abc-123'));
      expect(prefs.getString('scoped_token'), equals('"abc-123"'));
    });

    test('reads and writes collections (lists & maps)', () async {
      await storage.write('items', ['apple', 'banana']);
      expect(storage.read('items'), equals(['apple', 'banana']));

      await storage.write('scores', {'Alice': 100});
      expect(storage.read('scores'), equals({'Alice': 100}));
    });

    test('deletes values correctly', () async {
      await storage.write('key', 'value');
      expect(storage.read('key'), equals('value'));

      await storage.delete('key');
      expect(storage.read('key'), isNull);
      expect(prefs.getString('key'), isNull);
    });

    test('clears only scoped keys when prefix is configured', () async {
      final scopedStorage = SharedPreferencesHydratedStorage(
        prefs,
        prefix: 'app_',
      );

      // Seed unrelated host app preference
      await prefs.setString('user_theme_preference', 'dark');

      await scopedStorage.write('k1', 'v1');
      await scopedStorage.write('k2', 'v2');

      await scopedStorage.clear();
      expect(scopedStorage.read('k1'), isNull);
      expect(scopedStorage.read('k2'), isNull);
      expect(prefs.getString('app_k1'), isNull);
      expect(prefs.getString('app_k2'), isNull);

      // Unrelated preference is preserved!
      expect(prefs.getString('user_theme_preference'), equals('dark'));
    });

    test('propagates jsonDecode exception on corrupt storage string in read()',
        () async {
      await prefs.setString('corrupt_key', '{invalid_json');
      expect(
        () => storage.read('corrupt_key'),
        throwsA(isA<FormatException>()),
      );
    });

    test('integrates seamlessly with HydratedCubitSignal', () async {
      await prefs.setString('TestCounterCubit', '10');

      final cubit = TestCounterCubit(storage: storage);
      expect(cubit.stateValue, equals(10));

      cubit.increment();
      expect(cubit.stateValue, equals(11));
      expect(prefs.getString('TestCounterCubit'), equals('11'));
    });
  });
}
