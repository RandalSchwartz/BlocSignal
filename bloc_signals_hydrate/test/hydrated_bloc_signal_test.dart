import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:test/test.dart';

class PrimitiveCounterCubit extends HydratedCubitSignal<int> {
  PrimitiveCounterCubit({super.id, super.storage}) : super(initialState: 0);

  void increment() => emit(stateValue + 1);

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state;
}

class ListTodoListCubit extends HydratedCubitSignal<List<String>> {
  ListTodoListCubit({super.id, super.storage})
      : super(initialState: const []);

  void addTodo(String item) => emit([...stateValue, item]);

  @override
  List<String>? fromJson(dynamic json) =>
      (json as List?)?.map((e) => e.toString()).toList();

  @override
  dynamic toJson(List<String> state) => state;
}

class MapUserProfileCubit extends HydratedCubitSignal<Map<String, dynamic>> {
  MapUserProfileCubit({super.id, super.storage})
      : super(initialState: const {'name': 'Guest'});

  void updateName(String name) => emit({...stateValue, 'name': name});

  @override
  Map<String, dynamic>? fromJson(dynamic json) =>
      (json as Map?)?.cast<String, dynamic>();

  @override
  dynamic toJson(Map<String, dynamic> state) => state;
}

sealed class CounterEvent {}

class IncrementEvent extends CounterEvent {}

class HydratedCounterBloc extends HydratedBlocSignal<CounterEvent, int> {
  HydratedCounterBloc({super.id, super.storage}) : super(initialState: 0) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
  }

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state;
}

class ErrorProneCubit extends HydratedCubitSignal<int> {
  ErrorProneCubit({super.storage}) : super(initialState: 0);

  @override
  int? fromJson(dynamic json) {
    throw FormatException('Invalid JSON payload');
  }

  @override
  dynamic toJson(int state) => state;
}

void main() {
  late MemoryHydratedStorage storage;

  setUp(() {
    storage = MemoryHydratedStorage();
    HydratedStorage.storage = storage;
  });

  tearDown(() {
    HydratedStorage.storage = null;
  });

  group('HydratedCubitSignal & HydratedBlocSignal', () {
    test('hydrates primitive int state directly without map wrapping', () {
      storage.write('PrimitiveCounterCubit', 42);

      final cubit = PrimitiveCounterCubit();
      expect(cubit.stateValue, equals(42));
    });

    test('persists state change automatically on emit', () {
      final cubit = PrimitiveCounterCubit();
      expect(cubit.stateValue, equals(0));

      cubit.increment();
      expect(cubit.stateValue, equals(1));
      expect(storage.read('PrimitiveCounterCubit'), equals(1));
    });

    test('hydrates List collection state directly', () {
      storage.write('ListTodoListCubit', ['Buy milk', 'Walk dog']);

      final cubit = ListTodoListCubit();
      expect(cubit.stateValue, equals(['Buy milk', 'Walk dog']));

      cubit.addTodo('Code Dart');
      expect(
        storage.read('ListTodoListCubit'),
        equals(['Buy milk', 'Walk dog', 'Code Dart']),
      );
    });

    test('hydrates Map state correctly', () {
      storage.write('MapUserProfileCubit', {'name': 'Alice'});

      final cubit = MapUserProfileCubit();
      expect(cubit.stateValue, equals({'name': 'Alice'}));

      cubit.updateName('Bob');
      expect(storage.read('MapUserProfileCubit'), equals({'name': 'Bob'}));
    });

    test('isolates storage keys by instance id', () {
      storage.write('PrimitiveCounterCubit_user_1', 10);
      storage.write('PrimitiveCounterCubit_user_2', 20);

      final cubit1 = PrimitiveCounterCubit(id: 'user_1');
      final cubit2 = PrimitiveCounterCubit(id: 'user_2');

      expect(cubit1.stateValue, equals(10));
      expect(cubit2.stateValue, equals(20));

      cubit1.increment();
      expect(storage.read('PrimitiveCounterCubit_user_1'), equals(11));
      expect(storage.read('PrimitiveCounterCubit_user_2'), equals(20));
    });

    test('supports HydratedBlocSignal event handling and persistence', () {
      storage.write('HydratedCounterBloc', 99);

      final bloc = HydratedCounterBloc();
      expect(bloc.stateValue, equals(99));

      bloc.add(IncrementEvent());
      expect(bloc.stateValue, equals(100));
      expect(storage.read('HydratedCounterBloc'), equals(100));
    });

    test('clears storage and resets state to initialState on clear()',
        () async {
      storage.write('PrimitiveCounterCubit', 50);

      final cubit = PrimitiveCounterCubit();
      expect(cubit.stateValue, equals(50));

      await cubit.clear();
      expect(cubit.stateValue, equals(0));
      expect(storage.read('PrimitiveCounterCubit'), isNull);
    });

    test('handles fromJson exception gracefully via onError', () {
      Object? capturedError;
      BlocSignalObserver.observer = _TestObserver(
        onErrorCallback: (bloc, error, stackTrace) {
          capturedError = error;
        },
      );

      storage.write('ErrorProneCubit', 'invalid_payload');

      final cubit = ErrorProneCubit();
      expect(cubit.stateValue, equals(0)); // Falls back to initialState
      expect(capturedError, isA<FormatException>());
    });
  });
}

class _TestObserver extends BlocSignalObserver {
  _TestObserver({this.onErrorCallback});

  final void Function(BlocSignalBase bloc, Object error, StackTrace stackTrace)?
      onErrorCallback;

  @override
  void onError(BlocSignalBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    onErrorCallback?.call(bloc, error, stackTrace);
  }
}
