import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:test/test.dart';

import '../support/a2ui_fixtures.dart';

/// A well-formed `createSurface` envelope for [surfaceId], as a JSON string.
String _createSurface(String surfaceId) => asChunk(createSurface(surfaceId));

/// A chunk that is not JSON at all, so parsing it raises a `FormatException`.
const _unparseable = 'not json';

/// Everything one session produced: the states the bloc emitted, the errors it
/// reported through the observer pipeline, the errors that escaped into the
/// surrounding zone instead, and the events the framework reported as finished.
typedef _Outcome = ({
  List<A2uiSurfaceState> states,
  List<Object> reported,
  List<Object?> completed,
  List<Object> escaped,
});

/// Captures what `A2uiSurfaceBloc` forwards to the global observer slot.
class _RecordingObserver extends BlocSignalObserver {
  final List<Object> errors = <Object>[];
  final List<Object?> completed = <Object?>[];

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
  }

  @override
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) {
    completed.add(event);
  }
}

/// A single-subscription stream the test drives by hand, reporting when the
/// bloc subscribes to it and when that subscription is cancelled.
class _Feed {
  _Feed() {
    controller = StreamController<dynamic>(
      onListen: () {
        if (!_listened.isCompleted) _listened.complete();
      },
      onCancel: () {
        if (!_cancelled.isCompleted) _cancelled.complete();
      },
    );
  }

  late final StreamController<dynamic> controller;
  final Completer<void> _listened = Completer<void>();
  final Completer<void> _cancelled = Completer<void>();

  /// Resolves once the bloc has actually subscribed.
  Future<void> get listened => _listened.future;

  /// Whether the bloc has cancelled its subscription to this stream.
  bool get isCancelled => _cancelled.isCompleted;

  void add(Object? chunk) => controller.add(chunk);

  void addError(Object error) => controller.addError(error);

  Future<void> close() => controller.close();
}

/// A stream whose subscription reports a successful cancel and then keeps
/// delivering anyway.
class _UnstoppableFeed extends Stream<dynamic> {
  void Function(dynamic)? _onData;
  final Completer<void> _listened = Completer<void>();

  /// Whether the bloc asked this subscription to cancel.
  bool cancelled = false;

  /// Resolves once the bloc has subscribed.
  Future<void> get listened => _listened.future;

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _onData = onData;
    if (!_listened.isCompleted) _listened.complete();
    return _DeafSubscription(() => cancelled = true);
  }

  /// Delivers [chunk] to the listener whether or not it was cancelled.
  void push(dynamic chunk) => _onData?.call(chunk);
}

/// The subscription [_UnstoppableFeed] hands out: it records the cancel and
/// then ignores it.
class _DeafSubscription implements StreamSubscription<dynamic> {
  _DeafSubscription(this._onCancel);

  final void Function() _onCancel;

  @override
  Future<void> cancel() async => _onCancel();

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;

  @override
  void onData(void Function(dynamic)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}
}

/// A stream whose *first* cancel is held open until a gate is released, and
/// whose later cancels resolve immediately.
class _SlowCancelFeed extends Stream<dynamic> {
  _SlowCancelFeed(this._cancelGate);

  final Future<void> _cancelGate;
  void Function(dynamic)? _onData;
  final Completer<void> _listened = Completer<void>();

  /// Resolves once the bloc has subscribed.
  Future<void> get listened => _listened.future;

  /// Delivers [chunk] to the listener.
  void add(dynamic chunk) => _onData?.call(chunk);

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    _onData = onData;
    if (!_listened.isCompleted) _listened.complete();
    return _SlowCancelSubscription(_cancelGate);
  }
}

/// The subscription [_SlowCancelFeed] hands out.
class _SlowCancelSubscription implements StreamSubscription<dynamic> {
  _SlowCancelSubscription(this._gate);

  final Future<void> _gate;
  bool _cancelStarted = false;

  @override
  Future<void> cancel() {
    if (_cancelStarted) return Future<void>.value();
    _cancelStarted = true;
    return _gate;
  }

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;

  @override
  void onData(void Function(dynamic)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}
}

class _SyncThrowStream extends Stream<dynamic> {
  _SyncThrowStream(this.error);
  final Object error;

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    Error.throwWithStackTrace(error, StackTrace.current);
  }
}

class _ThrowingCancelStream extends Stream<dynamic> {
  _ThrowingCancelStream(this.cancelError);
  final Object cancelError;
  final Completer<void> _listened = Completer<void>();

  Future<void> get listened => _listened.future;

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    if (!_listened.isCompleted) _listened.complete();
    return _ThrowingCancelSubscription(cancelError);
  }
}

class _ThrowingCancelSubscription implements StreamSubscription<dynamic> {
  _ThrowingCancelSubscription(this._error);
  final Object _error;

  @override
  Future<void> cancel() async {
    Error.throwWithStackTrace(_error, StackTrace.current);
  }

  @override
  bool get isPaused => false;

  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;

  @override
  void onData(void Function(dynamic)? handleData) {}

  @override
  void onError(Function? handleError) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}
}

/// Lets pending stream callbacks and handler continuations run.
Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Runs [body] against a fresh bloc with the global observer installed, and
/// reports everything that came out.
Future<_Outcome> _session(
  Future<void> Function(A2uiSurfaceBloc bloc, _RecordingObserver observer) body,
) async {
  final observer = _RecordingObserver();
  final states = <A2uiSurfaceState>[];
  final escaped = <Object>[];

  final previousObserver = BlocSignalObserver.observer;
  BlocSignalObserver.observer = observer;

  Object? bodyFailure;
  StackTrace? bodyStackTrace;

  final finished = Completer<void>();
  unawaited(
    runZonedGuarded(
      () async {
        final bloc = A2uiSurfaceBloc();
        final unsubscribe = bloc.state.subscribe(states.add);
        try {
          await body(bloc, observer);
        } on Object catch (error, stackTrace) {
          bodyFailure = error;
          bodyStackTrace = stackTrace;
        } finally {
          unsubscribe();
          if (!bloc.isClosed) await bloc.close();
          if (!finished.isCompleted) finished.complete();
        }
      },
      (error, stackTrace) => escaped.add(error),
    ),
  );

  await finished.future;
  await _settle();
  BlocSignalObserver.observer = previousObserver;

  final failure = bodyFailure;
  if (failure != null) {
    Error.throwWithStackTrace(failure, bodyStackTrace!);
  }

  return (
    states: states,
    reported: observer.errors,
    completed: observer.completed,
    escaped: escaped,
  );
}

/// The two states every ingestion starts with.
const _openingStates = <A2uiSurfaceState>[
  SurfaceInitial(),
  SurfaceStreaming(),
];

void main() {
  group('a second stream supersedes the first', () {
    test('the superseded stream is cancelled as the replacement subscribes',
        () async {
      late _Feed first;
      await _session((bloc, observer) async {
        first = _Feed();
        final second = _Feed();

        bloc.add(IngestStream(first.controller.stream));
        await first.listened;
        expect(first.isCancelled, isFalse);

        bloc.add(IngestStream(second.controller.stream));
        await second.listened;

        expect(first.isCancelled, isTrue);

        await first.close();
        await second.close();
      });
    });

    test(
        '(Issue #300: F18) a slow cancel on the superseded stream does not '
        'release the replacement', () async {
      late _Feed second;
      await _session((bloc, observer) async {
        final cancelGate = Completer<void>();
        final first = _SlowCancelFeed(cancelGate.future);
        second = _Feed();

        bloc.add(IngestStream(first));
        await first.listened;

        first.add(_unparseable);
        await _settle();

        bloc.add(IngestStream(second.controller.stream));
        await second.listened;

        cancelGate.complete();
        await _settle();
      });

      expect(second.isCancelled, isTrue);
    });

    test('a chunk pushed onto the superseded stream never reaches the surface',
        () async {
      String? activeSurfaceId;
      final outcome = await _session((bloc, observer) async {
        final first = _Feed();
        final second = _Feed();

        bloc.add(IngestStream(first.controller.stream));
        await first.listened;
        bloc.add(IngestStream(second.controller.stream));
        await second.listened;

        first.add(_createSurface('stale'));
        await _settle();

        second.add(_createSurface('live'));
        await _settle();

        activeSurfaceId = bloc.activeSurfaceId;

        await first.close();
        await second.close();
      });

      expect(activeSurfaceId, 'live');
      expect(
        outcome.states.map((s) => s.surfaceId),
        isNot(contains('stale')),
        reason: "no state carries the superseded stream's surface",
      );
      expect(outcome.reported, isEmpty);
      expect(outcome.escaped, isEmpty);
    });

    test('the superseded handler finishes at the restart, not at stream close',
        () async {
      await _session((bloc, observer) async {
        final first = _Feed();
        final second = _Feed();

        bloc.add(IngestStream(first.controller.stream));
        await first.listened;
        await _settle();
        expect(
          observer.completed.whereType<IngestStream>(),
          isEmpty,
          reason: 'the first handler is still waiting on its own stream',
        );

        bloc.add(IngestStream(second.controller.stream));
        await second.listened;
        await _settle();

        expect(
          observer.completed.whereType<IngestStream>(),
          hasLength(1),
          reason:
              'the superseded handler resolved while its stream was still open',
        );

        await first.close();
        await second.close();
      });
    });

    test('the restart re-announces streaming under the previous surface id',
        () async {
      final outcome = await _session((bloc, observer) async {
        final first = _Feed();
        final second = _Feed();

        bloc.add(IngestStream(first.controller.stream));
        await first.listened;
        first.add(_createSurface('s1'));
        await _settle();

        bloc.add(IngestStream(second.controller.stream));
        await second.listened;
        await _settle();

        await first.close();
        await second.close();
      });

      expect(
        outcome.states,
        containsAllInOrder(<A2uiSurfaceState>[
          const SurfaceStreaming(surfaceId: 's1', messageCount: 1),
          const SurfaceStreaming(surfaceId: 's1'),
        ]),
      );
    });
  });

  group('(Issue #300: F18) two streams added in one synchronous turn', () {
    test('both subscribe, and the superseded one is cancelled', () async {
      late _Feed first;
      late _Feed second;
      await _session((bloc, observer) async {
        first = _Feed();
        second = _Feed();

        bloc
          ..add(IngestStream(first.controller.stream))
          ..add(IngestStream(second.controller.stream));
        await _settle();
      });

      expect(
        first.isCancelled,
        isTrue,
        reason:
            'superseded stream added in same synchronous turn must be cancelled',
      );
      expect(second.isCancelled, isTrue);
    });

    test('with an await between them, the superseded one is cancelled',
        () async {
      late _Feed first;
      await _session((bloc, observer) async {
        first = _Feed();
        final second = _Feed();

        bloc.add(IngestStream(first.controller.stream));
        await first.listened;
        bloc.add(IngestStream(second.controller.stream));
        await second.listened;
      });

      expect(first.isCancelled, isTrue);
    });

    test(
        'with three streams in one turn, all superseded streams are cancelled and handlers finish',
        () async {
      late List<_Feed> feeds;
      final outcome = await _session((bloc, observer) async {
        feeds = [_Feed(), _Feed(), _Feed()];
        for (final feed in feeds) {
          bloc.add(IngestStream(feed.controller.stream));
        }
        await _settle();
      });

      expect(feeds[0].isCancelled, isTrue);
      expect(feeds[1].isCancelled, isTrue);
      expect(feeds[2].isCancelled, isTrue);

      expect(outcome.completed.whereType<IngestStream>(), hasLength(3));
    });
  });

  group(
      '(Issue #300: F22) an ingest that starts while close is already running',
      () {
    test('does not orphan stream subscription or leave active listeners',
        () async {
      final feed = _Feed();
      final bloc = A2uiSurfaceBloc();

      final closing = bloc.close();
      bloc.add(IngestStream(feed.controller.stream));
      await closing;
      await _settle();

      expect(
        feed.controller.hasListener,
        isFalse,
        reason:
            'ingest starting while close is running must not leave an active listener',
      );
      expect(bloc.isClosed, isTrue);
    });

    test('close while awaiting cancel of superseded stream cleanly finishes',
        () async {
      final cancelGate = Completer<void>();
      final first = _SlowCancelFeed(cancelGate.future);
      final second = _Feed();

      final bloc = A2uiSurfaceBloc();
      bloc.add(IngestStream(first));
      await first.listened;

      bloc.add(IngestStream(second.controller.stream));
      await second.listened;

      final closing = bloc.close();
      cancelGate.complete();
      await closing;
      await _settle();

      expect(bloc.isClosed, isTrue);
      expect(second.isCancelled, isTrue);
    });
  });

  group('(Issue #300: F21) a reset while a stream is still arriving', () {
    test('cancels active stream and completes handler', () async {
      late _Feed feed;
      var cancelledAtReset = false;
      var completedAtReset = 0;
      final outcome = await _session((bloc, observer) async {
        feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;

        feed.add(_createSurface('s1'));
        await _settle();

        bloc.add(const ResetSurface());
        await _settle();

        cancelledAtReset = feed.isCancelled;
        completedAtReset = observer.completed.whereType<IngestStream>().length;
      });

      expect(
        cancelledAtReset,
        isTrue,
        reason: 'ResetSurface must cancel the active transport',
      );
      expect(
        completedAtReset,
        1,
        reason: 'ResetSurface must complete the in-flight handler completer',
      );
      expect(outcome.states.last, const SurfaceInitial());

      expect(feed.isCancelled, isTrue);
      expect(outcome.completed.whereType<IngestStream>(), hasLength(1));
    });

    test('a chunk pushed after the reset is dropped and does not repopulate',
        () async {
      final outcome = await _session((bloc, observer) async {
        final feed = _UnstoppableFeed();
        bloc.add(IngestStream(feed));
        await feed.listened;

        feed.push(_createSurface('s1'));
        await _settle();

        bloc.add(const ResetSurface());
        await _settle();

        feed.push(_createSurface('s2'));
        await _settle();
      });

      expect(
        outcome.states.map((state) => state.surfaceId).toList(),
        [null, null, 's1', null],
      );
      expect(outcome.states.last, const SurfaceInitial());
      expect(outcome.escaped, isEmpty);
      expect(outcome.reported, isEmpty);
    });

    test('targeted reset of active surface cancels active stream', () async {
      late _Feed feed;
      var cancelledAtReset = false;
      final outcome = await _session((bloc, observer) async {
        feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;

        feed.add(_createSurface('s1'));
        await _settle();

        expect(bloc.activeSurfaceId, 's1');

        bloc.add(const ResetSurface(surfaceId: 's1'));
        await _settle();

        cancelledAtReset = feed.isCancelled;
      });

      expect(cancelledAtReset, isTrue);
      expect(outcome.states.last, const SurfaceInitial());
    });
  });

  group('a chunk that arrives after shutdown', () {
    test('close cancels the live subscription and returns', () async {
      late _Feed feed;
      await _session((bloc, observer) async {
        feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;

        await bloc.close().timeout(
              const Duration(seconds: 5),
              onTimeout: () =>
                  fail('close did not return while a stream was still open'),
            );

        expect(feed.isCancelled, isTrue);
        await feed.close();
      });
    });

    test('a chunk pushed after close changes no state and raises nothing',
        () async {
      final outcome = await _session((bloc, observer) async {
        final feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;
        await bloc.close();

        feed.add(_createSurface('after-close'));
        await _settle();

        await feed.close();
      });

      expect(outcome.states, _openingStates);
      expect(outcome.reported, isEmpty);
      expect(outcome.escaped, isEmpty);
    });

    test('a chunk from an upstream that ignored its cancel is dropped',
        () async {
      final feed = _UnstoppableFeed();
      String? activeSurfaceId;

      final outcome = await _session((bloc, observer) async {
        bloc.add(IngestStream(feed));
        await feed.listened;
        await bloc.close();

        expect(
          feed.cancelled,
          isTrue,
          reason: 'shutdown asked the upstream to stop',
        );

        feed.push(_createSurface('after-close'));
        await _settle();

        activeSurfaceId = bloc.activeSurfaceId;
      });

      expect(activeSurfaceId, isNull);
      expect(outcome.states, _openingStates);
      expect(outcome.reported, isEmpty);
      expect(outcome.escaped, isEmpty);
    });
  });

  group('a chunk that fails mid-stream', () {
    test('a later chunk in the same stream is lost after a parse failure',
        () async {
      late _Feed feed;
      final outcome = await _session((bloc, observer) async {
        feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;

        feed.add(_unparseable);
        await _settle();

        feed.add(_createSurface('s1'));
        await _settle();

        await feed.close();
      });

      expect(feed.isCancelled, isTrue);
      expect(outcome.reported, [isA<FormatException>()]);
      expect(outcome.escaped, isEmpty);
      expect(
        outcome.states,
        [
          ..._openingStates,
          isA<SurfaceError>()
              .having((s) => s.error, 'error', isA<FormatException>()),
        ],
      );
    });

    test('an error delivered by the stream itself becomes SurfaceError',
        () async {
      late _Feed feed;
      const failure = FormatException('upstream failed');
      final outcome = await _session((bloc, observer) async {
        feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;

        feed.addError(failure);
        await _settle();

        feed.add(_createSurface('s1'));
        await _settle();

        await feed.close();
      });

      expect(feed.isCancelled, isTrue);
      expect(outcome.reported, [same(failure)]);
      expect(outcome.escaped, isEmpty);
      expect(outcome.states, [
        ..._openingStates,
        isA<SurfaceError>().having((s) => s.error, 'error', same(failure)),
      ]);
    });

    test('a stream error that is an Error is reported and also escapes',
        () async {
      final failure = StateError('upstream broke');
      final outcome = await _session((bloc, observer) async {
        final feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;

        feed.addError(failure);
        await _settle();

        await feed.close();
      });

      expect(outcome.reported, [same(failure)]);
      expect(outcome.escaped, [same(failure)]);
      expect(outcome.states, [
        ..._openingStates,
        isA<SurfaceError>().having((s) => s.error, 'error', same(failure)),
      ]);
    });

    test('a stream that closes with no chunks settles back to initial',
        () async {
      final outcome = await _session((bloc, observer) async {
        final feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;
        await feed.close();
        await _settle();
      });

      expect(outcome.states, [..._openingStates, const SurfaceInitial()]);
      expect(outcome.reported, isEmpty);
      expect(outcome.escaped, isEmpty);
    });

    test(
        'stream that throws synchronously in listen reports error and cleans up',
        () async {
      final errorStream = _SyncThrowStream(StateError('sync listen error'));
      final outcome = await _session((bloc, observer) async {
        bloc.add(IngestStream(errorStream));
        await _settle();
      });

      expect(outcome.reported, contains(isA<StateError>()));
      expect(outcome.escaped, contains(isA<StateError>()));
    });

    test(
        '(Issue #300: Blocker 3) stream that throws synchronously in listen '
        'cancels pre-existing active stream', () async {
      late _Feed first;
      final errorStream = _SyncThrowStream(StateError('sync listen error'));
      final outcome = await _session((bloc, observer) async {
        first = _Feed();
        bloc.add(IngestStream(first.controller.stream));
        await first.listened;
        expect(first.isCancelled, isFalse);

        bloc.add(IngestStream(errorStream));
        await _settle();
      });

      expect(
        first.isCancelled,
        isTrue,
        reason:
            'pre-existing stream must be cancelled even if replacement throws in listen',
      );
      expect(outcome.reported, contains(isA<StateError>()));
      expect(outcome.escaped, contains(isA<StateError>()));
    });

    test(
        '(Issue #300: Round 3 Blocker 1) late event on superseded stream '
        'during synchronous listen throw is dropped without StateError',
        () async {
      final cancelGate = Completer<void>();
      final first = _SlowCancelFeed(cancelGate.future);
      final syncError = StateError('sync listen error');
      final errorStream = _SyncThrowStream(syncError);

      final outcome = await _session((bloc, observer) async {
        bloc.add(IngestStream(first));
        await first.listened;

        // Ingest a replacement stream that throws synchronously in listen().
        bloc.add(IngestStream(errorStream));
        await _settle();

        // While cancellation of the first stream is suspended awaiting cancelGate,
        // the superseded stream pumps a late chunk.
        first.add(_createSurface('late_stale_surface'));
        await _settle();

        // Release the cancel gate to complete cancellation.
        cancelGate.complete();
        await _settle();
      });

      // Assert that the late chunk never became an active surface.
      expect(
        outcome.states.map((s) => s.surfaceId),
        isNot(contains('late_stale_surface')),
      );
      // Assert that the sync listen error was caught and reported.
      expect(outcome.reported, contains(same(syncError)));
      // Assert that ONLY the expected sync listen error escaped to the zone,
      // proving that no late event on the superseded stream triggered a StateError or unhandled crash.
      expect(
        outcome.escaped,
        [same(syncError)],
        reason:
            'no late event on superseded stream triggered an unhandled StateError or crash',
      );
    });

    test(
        '(Issue #300: Blocker 1) fatal Error in chunk processing resolves '
        'completer and finishes handler', () async {
      late _Feed feed;
      final failure = StateError('fatal chunk error');
      final outcome = await _session((bloc, observer) async {
        feed = _Feed();
        bloc.add(IngestStream(feed.controller.stream));
        await feed.listened;

        feed.addError(failure);
        await _settle();

        await feed.close();
      });

      expect(feed.isCancelled, isTrue);
      expect(outcome.completed.whereType<IngestStream>(), hasLength(1));
    });

    test(
        'stream cancel failure during close is routed to onError and close completes',
        () async {
      final cancelFailure = StateError('cancel failed on close');
      final feed = _ThrowingCancelStream(cancelFailure);
      final outcome = await _session((bloc, observer) async {
        bloc.add(IngestStream(feed));
        await feed.listened;
        await bloc.close();
      });

      expect(outcome.reported, contains(same(cancelFailure)));
      expect(
        outcome.escaped,
        isEmpty,
        reason: 'close must not rethrow cancel error',
      );
    });

    test(
        'stream cancel failure during stream replacement is routed to onError without crashing handler',
        () async {
      final cancelFailure = StateError('cancel failed on superseding');
      final feed1 = _ThrowingCancelStream(cancelFailure);
      final feed2 = _Feed();
      final outcome = await _session((bloc, observer) async {
        bloc.add(IngestStream(feed1));
        await feed1.listened;

        bloc.add(IngestStream(feed2.controller.stream));
        await feed2.listened;
        await _settle();

        await feed2.close();
      });

      expect(outcome.reported, contains(same(cancelFailure)));
      expect(outcome.completed.whereType<IngestStream>(), hasLength(2));
    });
  });
}
