import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

class _RecordingObserver extends BlocSignalObserver {
  final List<String> events = <String>[];

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    events.add('onCreate:${bloc.runtimeType}');
  }
}

class _SimpleCubit extends CubitSignal<int> {
  _SimpleCubit() : super(initialState: 0);
}

void main() {
  tearDown(() {
    BlocSignalObserver.observer = null;
  });

  group('(Issue #479) Observer deduplication and MultiBlocSignalObserver', () {
    test('BlocSignalObserver.addObserver deduplicates identical instances',
        () async {
      final observer = _RecordingObserver();
      BlocSignalObserver.addObserver(observer);
      BlocSignalObserver.addObserver(observer);

      expect(identical(BlocSignalObserver.observer, observer), isTrue);

      final cubit1 = _SimpleCubit();
      expect(observer.events, hasLength(1));
      await cubit1.close();

      final observer2 = _RecordingObserver();
      BlocSignalObserver.addObserver(observer2);
      BlocSignalObserver.addObserver(observer2);
      BlocSignalObserver.addObserver(observer);

      final composite =
          BlocSignalObserver.observer! as CompositeBlocSignalObserver;
      expect(composite.observers, hasLength(2));

      final cubit2 = _SimpleCubit();
      expect(observer.events, hasLength(2));
      expect(observer2.events, hasLength(1));
      await cubit2.close();
    });

    test('CompositeBlocSignalObserver.add deduplicates identical instances',
        () {
      final obs1 = _RecordingObserver();
      final obs2 = _RecordingObserver();
      final multi = MultiBlocSignalObserver([obs1])
        ..add(obs1)
        ..add(obs2)
        ..add(obs2);

      expect(multi, isA<CompositeBlocSignalObserver>());
      expect(multi.observers, hasLength(2));
    });

    test(
        'CompositeBlocSignalObserver constructor deduplicates identical '
        'instances in registration order', () {
      final obs1 = _RecordingObserver();
      final obs2 = _RecordingObserver();
      final multi = CompositeBlocSignalObserver([obs1, obs2, obs1, obs2]);

      expect(multi.observers, hasLength(2));
      expect(identical(multi.observers[0], obs1), isTrue);
      expect(identical(multi.observers[1], obs2), isTrue);
    });
  });
}
