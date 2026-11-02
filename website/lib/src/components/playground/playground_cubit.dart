import 'dart:async';
import 'dart:convert';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:meta/meta.dart';

import 'playground_scenarios.dart';

/// Represents a captured user interaction or action response in the playground.
@immutable
class const PlaygroundActionEntry({
  required final String actionName,
  required final String surfaceId,
  final String? sourceComponentId,
  final DateTime? timestamp,
  final Map<String, dynamic> formData = const {},
  final Map<String, dynamic> payload = const {},
}) {
  @override
  String toString() =>
      'PlaygroundActionEntry(action: $actionName, surface: $surfaceId, component: $sourceComponentId)';
}

/// Immutable state model for [PlaygroundCubit].
@immutable
class const PlaygroundState({
  required final PlaygroundScenario selectedScenario,
  required final String rawJson,
  final bool isStreaming = false,
  final String? parseError,
  final List<PlaygroundActionEntry> actionLog = const [],
  final String? activeSurfaceId,
}) {
  /// Creates a copy of this state with updated values.
  PlaygroundState copyWith({
    PlaygroundScenario? selectedScenario,
    String? rawJson,
    bool? isStreaming,
    String? parseError,
    bool clearParseError = false,
    List<PlaygroundActionEntry>? actionLog,
    String? activeSurfaceId,
  }) {
    return PlaygroundState(
      selectedScenario: selectedScenario ?? this.selectedScenario,
      rawJson: rawJson ?? this.rawJson,
      isStreaming: isStreaming ?? this.isStreaming,
      parseError: clearParseError ? null : (parseError ?? this.parseError),
      actionLog: actionLog ?? this.actionLog,
      activeSurfaceId: activeSurfaceId ?? this.activeSurfaceId,
    );
  }
}

/// Reactive state container managing the Live A2UI Generative UI Playground.
class PlaygroundCubit({final PlaygroundScenario? initialScenario})
    extends CubitSignal<PlaygroundState> {
  this
    : surfaceBloc = A2uiSurfaceBloc(),
      super(
        initialState: PlaygroundState(
          selectedScenario:
              initialScenario ?? PlaygroundScenarios.flightBooking,
          rawJson: (initialScenario ?? PlaygroundScenarios.flightBooking)
              .jsonPayload,
          activeSurfaceId:
              (initialScenario ?? PlaygroundScenarios.flightBooking).id,
        ),
      ) {
    _initActionSubscription();
    // Render initial scenario synchronously
    _renderInstantInternal();
  }

  /// The underlying A2UI surface bloc orchestrating DOM components.
  final A2uiSurfaceBloc surfaceBloc;

  StreamSubscription<A2uiActionResponse>? _actionSub;
  Completer<void>? _activeStreamingCompleter;
  bool _isCanceled = false;

  void _initActionSubscription() {
    _actionSub = surfaceBloc.actionResponses.listen((response) {
      recordAction(
        PlaygroundActionEntry(
          actionName: response.actionName,
          surfaceId: response.surfaceId,
          sourceComponentId: response.sourceComponentId,
          timestamp: response.timestamp,
          formData: response.formData,
          payload: response.toToolResult(),
        ),
      );
    });
  }

  /// Selects a new [scenario], updating the JSON buffer and re-rendering.
  void selectScenario(PlaygroundScenario scenario) {
    cancelStreaming();
    emit(
      stateValue.copyWith(
        selectedScenario: scenario,
        rawJson: scenario.jsonPayload,
        clearParseError: true,
        actionLog: const [],
        activeSurfaceId: scenario.id,
      ),
    );
    _renderInstantInternal();
  }

  /// Updates the raw JSON buffer, evaluating syntax validity.
  void updateJson(String newJson) {
    String? error;
    try {
      final decoded = jsonDecode(newJson);
      if (decoded is! List) {
        error = 'JSON root must be an array of A2UI message objects.';
      }
    } on FormatException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    }

    emit(
      stateValue.copyWith(
        rawJson: newJson,
        parseError: error,
        clearParseError: error == null,
      ),
    );
  }

  /// Parses the raw JSON buffer and instantly hydrates the [surfaceBloc].
  Future<void> renderInstant() async {
    cancelStreaming();
    _renderInstantInternal();
  }

  void _renderInstantInternal() {
    List<dynamic> messages;
    try {
      final decoded = jsonDecode(stateValue.rawJson);
      if (decoded is! List) {
        emit(
          stateValue.copyWith(
            parseError: 'JSON root must be an array of A2UI message objects.',
          ),
        );
        return;
      }
      messages = decoded;
    } on FormatException catch (e) {
      emit(stateValue.copyWith(parseError: e.message));
      return;
    } catch (e) {
      emit(stateValue.copyWith(parseError: e.toString()));
      return;
    }

    emit(stateValue.copyWith(clearParseError: true));

    // Reset surface bloc to clean slate before reapplying
    surfaceBloc.add(ResetSurface());

    for (final item in messages) {
      if (item is Map) {
        final msgMap = Map<String, dynamic>.from(item);
        surfaceBloc.add(ProcessJsonMessage(msgMap));
      }
    }
  }

  /// Simulates token chunk streaming arrival over Server-Sent Events (SSE).
  Future<void> startStreaming({
    Duration chunkDelay = const Duration(milliseconds: 50),
  }) async {
    cancelStreaming();

    List<dynamic> messages;
    try {
      final decoded = jsonDecode(stateValue.rawJson);
      if (decoded is! List) {
        emit(
          stateValue.copyWith(
            parseError: 'JSON root must be an array of A2UI message objects.',
          ),
        );
        return;
      }
      messages = decoded;
    } on FormatException catch (e) {
      emit(stateValue.copyWith(parseError: e.message));
      return;
    } catch (e) {
      emit(stateValue.copyWith(parseError: e.toString()));
      return;
    }

    _isCanceled = false;
    final completer = Completer<void>();
    _activeStreamingCompleter = completer;

    emit(stateValue.copyWith(isStreaming: true, clearParseError: true));

    // Reset surface bloc to start fresh stream
    surfaceBloc.add(ResetSurface());

    // Stream each message envelope with simulated network delay
    () async {
      try {
        for (final item in messages) {
          if (_isCanceled || isClosed) break;
          if (chunkDelay > Duration.zero) {
            await Future<void>.delayed(chunkDelay);
          }
          if (_isCanceled || isClosed) break;

          if (item is Map) {
            final msgMap = Map<String, dynamic>.from(item);
            surfaceBloc.add(ProcessJsonMessage(msgMap));
          }
        }
      } finally {
        if (!_isCanceled && !isClosed) {
          emit(stateValue.copyWith(isStreaming: false));
        }
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }();

    return completer.future;
  }

  /// Cancels in-flight simulated streaming.
  void cancelStreaming() {
    _isCanceled = true;
    if (_activeStreamingCompleter != null &&
        !_activeStreamingCompleter!.isCompleted) {
      _activeStreamingCompleter!.complete();
    }
    _activeStreamingCompleter = null;
    if (stateValue.isStreaming) {
      emit(stateValue.copyWith(isStreaming: false));
    }
  }

  /// Records an action dispatch into [PlaygroundState.actionLog].
  void recordAction(PlaygroundActionEntry action) {
    final updatedLog = [action, ...stateValue.actionLog];
    emit(stateValue.copyWith(actionLog: updatedLog));
  }

  /// Resets the playground to the active scenario's default state.
  Future<void> reset() async {
    cancelStreaming();
    emit(
      stateValue.copyWith(
        rawJson: stateValue.selectedScenario.jsonPayload,
        actionLog: const [],
        clearParseError: true,
        isStreaming: false,
      ),
    );
    _renderInstantInternal();
  }

  /// Switches active surface in the underlying bloc.
  void selectSurface(String surfaceId) {
    surfaceBloc.add(SelectSurface(surfaceId: surfaceId));
    emit(stateValue.copyWith(activeSurfaceId: surfaceId));
  }

  @override
  Future<void> close() async {
    cancelStreaming();
    await _actionSub?.cancel();
    _actionSub = null;
    await surfaceBloc.close();
    return super.close();
  }
}
