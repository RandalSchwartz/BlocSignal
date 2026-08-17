import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:test/test.dart';

class FakeSharedPreferences {
  final Map<String, String> _storage = {};

  String? getString(String key) => _storage[key];

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
    test('reads and writes primitive values', () async {
      await storage.write('counter', 42);
      expect(storage.read('counter'), equals(42));
      expect(prefs.getString('counter'), equals('42'));
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

    test('clears all storage', () async {
      await storage.write('k1', 'v1');
      await storage.write('k2', 'v2');

      await storage.clear();
      expect(storage.read('k1'), isNull);
      expect(storage.read('k2'), isNull);
    });

    test('handles exceptions and non-json raw strings gracefully in read()',
        () async {
      final throwingPrefs = _ThrowingSharedPreferences();
      final throwingStorage = SharedPreferencesHydratedStorage(throwingPrefs);
      expect(throwingStorage.read('key'), isNull);
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

class _ThrowingSharedPreferences {
  String? getString(String key) => throw Exception('Storage failure');
}
