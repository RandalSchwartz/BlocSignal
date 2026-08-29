import 'dart:async';

import 'package:bloc/bloc.dart' as bloc_lib;
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

// --- Classic Bloc & Cubit fixtures ---

sealed class CounterEvent {
  const CounterEvent();
}

final class IncrementEvent extends CounterEvent {
  const IncrementEvent();
}

final class DecrementEvent extends CounterEvent {
  const DecrementEvent();
}

class ClassicCounterBloc extends bloc_lib.Bloc<CounterEvent, int> {
  ClassicCounterBloc({int initialState = 0}) : super(initialState) {
    on<IncrementEvent>((event, emit) => emit(state + 1));
    on<DecrementEvent>((event, emit) => emit(state - 1));
  }
}

class ErrorMockBloc extends bloc_lib.Bloc<CounterEvent, int> {
  ErrorMockBloc() : super(0);

  final _controller = StreamController<int>.broadcast();

  @override
  Stream<int> get stream => _controller.stream;

  void emitStreamError(Object error) {
    _controller.addError(error);
  }

  @override
  Future<void> close() async {
    await _controller.close();
    await super.close();
  }
}

class ClassicCounterCubit extends bloc_lib.Cubit<int> {
  ClassicCounterCubit({int initialState = 0}) : super(initialState);

  void increment() => emit(state + 1);
  void decrement() => emit(state - 1);
}

class ErrorMockCubit extends bloc_lib.Cubit<int> {
  ErrorMockCubit() : super(0);

  final _controller = StreamController<int>.broadcast();

  @override
  Stream<int> get stream => _controller.stream;

  void emitStreamError(Object error) {
    _controller.addError(error);
  }

  @override
  Future<void> close() async {
    await _controller.close();
    await super.close();
  }
}

// --- Modern BlocSignal & CubitSignal fixtures ---

class ModernCounterBloc extends BlocSignal<CounterEvent, int> {
  ModernCounterBloc({super.initialState = 0}) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
    on<DecrementEvent>((event, emit) => emit(stateValue - 1));
  }
}

class ModernCounterCubit extends CubitSignal<int> {
  ModernCounterCubit({super.initialState = 0});

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}

class TestObserver extends BlocSignalObserver {
  final List<Object?> events = [];
  final List<Change<dynamic>> changes = [];
  final List<Object> errors = [];
  final List<BlocSignalBase<dynamic>> created = [];
  final List<BlocSignalBase<dynamic>> closed = [];

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    created.add(bloc);
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    events.add(event);
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    changes.add(change);
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    closed.add(bloc);
  }
}

void main() {
  group('Classic Bloc -> BlocSignal (ClassicBlocSignal)', () {
    late ClassicCounterBloc classicBloc;

    setUp(() {
      classicBloc = ClassicCounterBloc();
    });

    tearDown(() async {
      await classicBloc.close();
    });

    test('initial state and reactive signal read', () async {
      final blocSignal = classicBloc.toBlocSignal();
      expect(blocSignal.stateValue, equals(0));
      expect(blocSignal.state.value, equals(0));
      expect(blocSignal.bloc, same(classicBloc));

      classicBloc.add(const IncrementEvent());
      await Future<void>.delayed(Duration.zero);

      expect(blocSignal.stateValue, equals(1));
      await blocSignal.close();
    });

    test('bidirectional mutation via adapter add(event)', () async {
      final blocSignal = classicBloc.toBlocSignal()
        ..add(const IncrementEvent());
      await Future<void>.delayed(Duration.zero);

      expect(classicBloc.state, equals(1));
      expect(blocSignal.stateValue, equals(1));

      blocSignal.add(const DecrementEvent());
      await Future<void>.delayed(Duration.zero);

      expect(classicBloc.state, equals(0));
      expect(blocSignal.stateValue, equals(0));

      await blocSignal.close();
    });

    test('custom equals and SignalOptions', () async {
      final blocSignal = classicBloc.toBlocSignal(
        equals: (prev, curr) => prev == curr,
        options: const SignalOptions<int>(name: 'custom_classic_bloc'),
      );

      expect(blocSignal.state.name, equals('custom_classic_bloc'));
      await blocSignal.close();
    });

    test('stream error forwards to onError and observer', () async {
      final observer = TestObserver();
      BlocSignalObserver.observer = observer;

      final mockBloc = ErrorMockBloc();
      final blocSignal = mockBloc.toBlocSignal();

      mockBloc.emitStreamError(Exception('stream failure'));
      await Future<void>.delayed(Duration.zero);

      expect(observer.errors, isNotEmpty);
      expect(observer.errors.first.toString(), contains('stream failure'));

      BlocSignalObserver.observer = null;
      await blocSignal.close();
      await mockBloc.close();
    });

    test('autoClose = true closes underlying classic bloc', () async {
      final blocSignal = classicBloc.toBlocSignal(autoClose: true);
      expect(classicBloc.isClosed, isFalse);

      await blocSignal.close();
      expect(classicBloc.isClosed, isTrue);
      expect(blocSignal.isClosed, isTrue);
    });

    test('autoClose = false preserves underlying classic bloc', () async {
      final blocSignal = classicBloc.toBlocSignal(autoClose: false);
      expect(classicBloc.isClosed, isFalse);

      await blocSignal.close();
      expect(classicBloc.isClosed, isFalse);
      expect(blocSignal.isClosed, isTrue);
    });

    test('add dropped after close', () async {
      final blocSignal = classicBloc.toBlocSignal();
      await blocSignal.close();

      blocSignal.add(const IncrementEvent());
      await Future<void>.delayed(Duration.zero);

      expect(classicBloc.state, equals(0));
    });

    test('observer onEvent and onChange tracking', () async {
      final observer = TestObserver();
      BlocSignalObserver.observer = observer;

      final blocSignal = classicBloc.toBlocSignal()
        ..add(const IncrementEvent());
      await Future<void>.delayed(Duration.zero);

      expect(observer.events, contains(isA<IncrementEvent>()));
      expect(observer.changes.any((c) => c.nextState == 1), isTrue);

      BlocSignalObserver.observer = null;
      await blocSignal.close();
    });

    test('classic bloc close closes adapter', () async {
      final blocSignal = classicBloc.toBlocSignal();
      await classicBloc.close();
      await Future<void>.delayed(Duration.zero);

      expect(blocSignal.isClosed, isTrue);
    });
  });

  group('Classic Cubit -> CubitSignal (ClassicCubitSignal)', () {
    late ClassicCounterCubit classicCubit;

    setUp(() {
      classicCubit = ClassicCounterCubit();
    });

    tearDown(() async {
      await classicCubit.close();
    });

    test('initial state, typed .cubit access and signal updates', () async {
      final cubitSignal = classicCubit.toBlocSignal();
      expect(cubitSignal.stateValue, equals(0));
      expect(cubitSignal.cubit, same(classicCubit));

      cubitSignal.cubit.increment();
      await Future<void>.delayed(Duration.zero);

      expect(cubitSignal.stateValue, equals(1));
      expect(classicCubit.state, equals(1));

      await cubitSignal.close();
    });

    test('custom equals and SignalOptions', () async {
      final cubitSignal = classicCubit.toBlocSignal(
        equals: (prev, curr) => false,
        options: const SignalOptions<int>(name: 'custom_classic_cubit'),
      );

      expect(cubitSignal.state.name, equals('custom_classic_cubit'));
      await cubitSignal.close();
    });

    test('stream error forwards to cubitSignal.onError and observer', () async {
      final observer = TestObserver();
      BlocSignalObserver.observer = observer;

      final mockCubit = ErrorMockCubit();
      final cubitSignal = mockCubit.toBlocSignal();

      mockCubit.emitStreamError(Exception('cubit boom'));
      await Future<void>.delayed(Duration.zero);

      expect(observer.errors, isNotEmpty);
      expect(observer.errors.first.toString(), contains('cubit boom'));

      BlocSignalObserver.observer = null;
      await cubitSignal.close();
      await mockCubit.close();
    });

    test('autoClose = true closes underlying classic cubit', () async {
      final cubitSignal = classicCubit.toBlocSignal(autoClose: true);
      expect(classicCubit.isClosed, isFalse);

      await cubitSignal.close();
      expect(classicCubit.isClosed, isTrue);
      expect(cubitSignal.isClosed, isTrue);
    });

    test('autoClose = false preserves underlying classic cubit', () async {
      final cubitSignal = classicCubit.toBlocSignal(autoClose: false);
      expect(classicCubit.isClosed, isFalse);

      await cubitSignal.close();
      expect(classicCubit.isClosed, isFalse);
      expect(cubitSignal.isClosed, isTrue);
    });

    test('classic cubit close closes adapter', () async {
      final cubitSignal = classicCubit.toBlocSignal();
      await classicCubit.close();
      await Future<void>.delayed(Duration.zero);

      expect(cubitSignal.isClosed, isTrue);
    });
  });

  group('Modern BlocSignal -> Classic Bloc (BlocSignalToClassicBloc)', () {
    late ModernCounterBloc modernBloc;

    setUp(() {
      modernBloc = ModernCounterBloc();
    });

    tearDown(() async {
      await modernBloc.close();
    });

    test('initial state and stream propagation', () async {
      final classicAdapter = modernBloc.toClassicBloc();
      expect(classicAdapter.state, equals(0));
      expect(classicAdapter.blocSignal, same(modernBloc));

      final emittedStates = <int>[];
      final sub = classicAdapter.stream.listen(emittedStates.add);

      modernBloc.add(const IncrementEvent());
      await Future<void>.delayed(Duration.zero);

      expect(classicAdapter.state, equals(1));
      expect(emittedStates, contains(1));

      await sub.cancel();
      await classicAdapter.close();
    });

    test('reverse mutation: classicAdapter.add(event) forwards to modernBloc',
        () async {
      final classicAdapter = modernBloc.toClassicBloc()
        ..add(const IncrementEvent());
      await Future<void>.delayed(Duration.zero);

      expect(modernBloc.stateValue, equals(1));
      expect(classicAdapter.state, equals(1));

      classicAdapter.add(const DecrementEvent());
      await Future<void>.delayed(Duration.zero);

      expect(modernBloc.stateValue, equals(0));
      expect(classicAdapter.state, equals(0));

      await classicAdapter.close();
    });

    test('autoClose = true closes modernBloc', () async {
      final classicAdapter = modernBloc.toClassicBloc(autoClose: true);
      expect(modernBloc.isClosed, isFalse);

      await classicAdapter.close();
      expect(classicAdapter.isClosed, isTrue);
      expect(modernBloc.isClosed, isTrue);
    });

    test('autoClose = false preserves modernBloc', () async {
      final classicAdapter = modernBloc.toClassicBloc(autoClose: false);
      expect(modernBloc.isClosed, isFalse);

      await classicAdapter.close();
      expect(classicAdapter.isClosed, isTrue);
      expect(modernBloc.isClosed, isFalse);
    });
  });

  group('Modern CubitSignal -> Classic Cubit (BlocSignalToClassicCubit)', () {
    late ModernCounterCubit modernCubit;

    setUp(() {
      modernCubit = ModernCounterCubit();
    });

    tearDown(() async {
      await modernCubit.close();
    });

    test('initial state, typed getters and stream updates', () async {
      final classicCubit = modernCubit.toClassicCubit();
      expect(classicCubit.state, equals(0));
      expect(classicCubit.blocSignal, same(modernCubit));
      expect(classicCubit.cubit, same(modernCubit));

      final emittedStates = <int>[];
      final sub = classicCubit.stream.listen(emittedStates.add);

      modernCubit.increment();
      await Future<void>.delayed(Duration.zero);

      expect(classicCubit.state, equals(1));
      expect(emittedStates, contains(1));

      await sub.cancel();
      await classicCubit.close();
    });

    test('toClassicBloc on CubitSignal returns classic cubit adapter',
        () async {
      final classicCubit = modernCubit.toClassicBloc();
      expect(classicCubit.state, equals(0));

      modernCubit.increment();
      await Future<void>.delayed(Duration.zero);

      expect(classicCubit.state, equals(1));
      await classicCubit.close();
    });

    test('autoClose = true closes modernCubit', () async {
      final classicCubit = modernCubit.toClassicCubit(autoClose: true);
      expect(modernCubit.isClosed, isFalse);

      await classicCubit.close();
      expect(classicCubit.isClosed, isTrue);
      expect(modernCubit.isClosed, isTrue);
    });

    test('autoClose = false preserves modernCubit', () async {
      final classicCubit = modernCubit.toClassicCubit(autoClose: false);
      expect(modernCubit.isClosed, isFalse);

      await classicCubit.close();
      expect(classicCubit.isClosed, isTrue);
      expect(modernCubit.isClosed, isFalse);
    });
  });

  group('Generic BlocSignalBase toClassicBloc and toClassicCubit', () {
    test('toClassicBloc and toClassicCubit on BlocSignalBase', () async {
      final BlocSignalBase<int> base = ModernCounterCubit(initialState: 10);
      final classicCubit = base.toClassicCubit();
      final classicBloc = base.toClassicBloc();

      expect(classicCubit.state, equals(10));
      expect(classicBloc.state, equals(10));

      await classicCubit.close();
      await classicBloc.close();
      await base.close();
    });
  });
}
