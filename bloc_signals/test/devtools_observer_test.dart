import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

sealed class TestCounterEvent {}

class IncrementEvent extends TestCounterEvent {}

class ErrorEvent extends TestCounterEvent {}

class TestCounterBloc extends BlocSignal<TestCounterEvent, int> {
  TestCounterBloc({super.initialState = 0}) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
    on<ErrorEvent>(
      (event, emit) => throw const FormatException('Test failure'),
    );
  }
}

class TestCubit extends CubitSignal<int> {
  TestCubit({super.initialState = 0});

  void increment() => emit(stateValue + 1);
}

class RecordingObserver extends BlocSignalObserver {
  final List<String> calls = [];

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    super.onCreate(bloc);
    calls.add('onCreate');
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    calls.add('onEvent');
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);
    calls.add('onTransition');
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    calls.add('onChange');
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);
    calls.add('onError');
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    super.onClose(bloc);
    calls.add('onClose');
  }
}

void main() {
  group('DevToolsBlocSignalObserver', () {
    late RecordingObserver recordingObserver;
    late DevToolsBlocSignalObserver devToolsObserver;

    setUp(() {
      recordingObserver = RecordingObserver();
      devToolsObserver = DevToolsBlocSignalObserver(
        previousObserver: recordingObserver,
      );
      BlocSignalObserver.observer = devToolsObserver;
    });

    tearDown(() {
      BlocSignalObserver.observer = null;
    });

    test('captures onCreate and forwards to previousObserver', () async {
      final cubit = TestCubit(initialState: 10);
      expect(recordingObserver.calls, contains('onCreate'));
      await cubit.close();
    });

    test('captures state changes on cubit emit', () async {
      final cubit = TestCubit()..increment();

      expect(cubit.stateValue, equals(1));
      expect(recordingObserver.calls, contains('onChange'));
      await cubit.close();
    });

    test('captures events and transitions on bloc add', () async {
      final bloc = TestCounterBloc()..add(IncrementEvent());

      expect(bloc.stateValue, equals(1));
      expect(
        recordingObserver.calls,
        containsAll(['onEvent', 'onTransition', 'onChange']),
      );
      await bloc.close();
    });

    test('captures onError on operational exceptions', () async {
      final bloc = TestCounterBloc()..add(ErrorEvent());

      expect(recordingObserver.calls, contains('onError'));
      await bloc.close();
    });

    test('captures onClose when container is closed', () async {
      final bloc = TestCounterBloc();
      await bloc.close();

      expect(recordingObserver.calls, contains('onClose'));
    });
  });
}
