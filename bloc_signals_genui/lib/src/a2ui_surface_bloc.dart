import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/src/a2ui_action_response.dart';
import 'package:bloc_signals_genui/src/a2ui_surface_event.dart';
import 'package:bloc_signals_genui/src/a2ui_surface_state.dart';

/// A pure-Dart reactive state container that bridges Google's A2UI declarative
/// protocol with [BlocSignal] architecture.
///
/// Features:
/// - Ingests streaming A2UI JSON chunks outside the UI layer with `restartable()`
///   concurrency protection.
/// - Emits synchronous, sealed [A2uiSurfaceState]s for glitch-free UI rendering.
/// - Provides 0ms synchronous form updates directly against `a2ui_core`'s [DataModel].
/// - Validates form inputs before submitting and packaging structured [A2uiActionResponse]
///   tool call results for agent context turns.
class A2uiSurfaceBloc extends BlocSignal<A2uiSurfaceEvent, A2uiSurfaceState> {
  /// Creates an [A2uiSurfaceBloc].
  ///
  /// If [catalogs] is omitted, defaults to registering the standard [MinimalCatalog].
  A2uiSurfaceBloc({
    List<Catalog<ComponentApi>>? catalogs,
  })  : catalogs = catalogs ?? [MinimalCatalog()],
        super(initialState: const SurfaceInitial()) {
    _processor = MessageProcessor<ComponentApi>(
      catalogs: this.catalogs,
      onAction: _handleClientAction,
    );

    on<IngestStream>(
      _onIngestStream,
      transformer: restartable(),
    );
    on<ProcessMessage>(_onProcessMessage);
    on<ProcessJsonMessage>(_onProcessJsonMessage);
    on<ProcessMessages>(_onProcessMessages);
    on<StreamCompleted>(_onStreamCompleted);
    on<UpdateFormField>(_onUpdateFormField);
    on<SubmitAction>(_onSubmitAction);
    on<ResetSurface>(_onResetSurface);
  }

  /// The active component catalogs registered with this surface bloc.
  final List<Catalog<ComponentApi>> catalogs;

  late final MessageProcessor<ComponentApi> _processor;

  /// The primary active surface ID being tracked by this bloc.
  String? _activeSurfaceId;

  /// Stream controller broadcasting validated user action responses back
  /// to external agent orchestrators.
  final StreamController<A2uiActionResponse> _actionResponsesController =
      StreamController<A2uiActionResponse>.broadcast();

  /// Stream of validated [A2uiActionResponse] objects ready for upstream tool calls.
  Stream<A2uiActionResponse> get actionResponses =>
      _actionResponsesController.stream;

  /// The underlying [MessageProcessor] maintaining the A2UI surface graph.
  MessageProcessor<ComponentApi> get processor => _processor;

  StreamSubscription<dynamic>? _activeStreamSubscription;
  Completer<void>? _activeStreamCompleter;
  int _surfaceVersion = 0;

  Future<void> _onIngestStream(
    IngestStream event,
    void Function(A2uiSurfaceState) emit,
  ) async {
    if (isClosed) return;

    var messageCount = 0;
    emit(
      SurfaceStreaming(
        surfaceId: _activeSurfaceId,
        messageCount: messageCount,
      ),
    );

    final oldSub = _activeStreamSubscription;
    _activeStreamSubscription = null;
    final oldCompleter = _activeStreamCompleter;
    _activeStreamCompleter = null;
    if (oldCompleter != null && !oldCompleter.isCompleted) {
      oldCompleter.complete();
    }
    await oldSub?.cancel();

    if (isClosed) return;

    final completer = Completer<void>();
    _activeStreamCompleter = completer;

    _activeStreamSubscription = event.stream.listen(
      (chunk) async {
        if (isClosed) {
          await _activeStreamSubscription?.cancel();
          _activeStreamSubscription = null;
          if (!completer.isCompleted) completer.complete();
          return;
        }

        try {
          final messages = _parseChunkToMessages(chunk);
          if (messages.isNotEmpty) {
            _processor.processMessages(messages);
            messageCount += messages.length;
            _surfaceVersion++;

            for (final msg in messages) {
              if (msg is CreateSurfaceMessage) {
                _activeSurfaceId = msg.surfaceId;
              }
            }

            _emitSurfaceSnapshot(emit, messageCount: messageCount);
          }
        } catch (error, stackTrace) {
          if (!isClosed) {
            emit(
              SurfaceError(
                error: error,
                stackTrace: stackTrace,
                surfaceId: _activeSurfaceId,
              ),
            );
          }
          await _activeStreamSubscription?.cancel();
          _activeStreamSubscription = null;
          if (!completer.isCompleted) completer.complete();
        }
      },
      onError: (Object error, StackTrace stackTrace) async {
        if (!isClosed) {
          emit(
            SurfaceError(
              error: error,
              stackTrace: stackTrace,
              surfaceId: _activeSurfaceId,
            ),
          );
        }
        await _activeStreamSubscription?.cancel();
        _activeStreamSubscription = null;
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        _activeStreamSubscription = null;
        if (!isClosed) {
          _emitFinalReadyOrInitial(emit);
        }
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
  }

  FutureOr<void> _onProcessMessage(
    ProcessMessage event,
    void Function(A2uiSurfaceState) emit,
  ) {
    try {
      if (event.message is CreateSurfaceMessage) {
        _activeSurfaceId = (event.message as CreateSurfaceMessage).surfaceId;
      }
      _processor.processMessages([event.message]);
      _surfaceVersion++;
      _emitFinalReadyOrInitial(emit);
    } catch (error, stackTrace) {
      emit(
        SurfaceError(
          error: error,
          stackTrace: stackTrace,
          surfaceId: _activeSurfaceId,
        ),
      );
    }
  }

  FutureOr<void> _onProcessJsonMessage(
    ProcessJsonMessage event,
    void Function(A2uiSurfaceState) emit,
  ) {
    try {
      final message = A2uiMessage.fromJson(event.json);
      if (message is CreateSurfaceMessage) {
        _activeSurfaceId = message.surfaceId;
      }
      _processor.processMessages([message]);
      _surfaceVersion++;
      _emitFinalReadyOrInitial(emit);
    } catch (error, stackTrace) {
      emit(
        SurfaceError(
          error: error,
          stackTrace: stackTrace,
          surfaceId: _activeSurfaceId,
        ),
      );
    }
  }

  FutureOr<void> _onProcessMessages(
    ProcessMessages event,
    void Function(A2uiSurfaceState) emit,
  ) {
    try {
      for (final msg in event.messages) {
        if (msg is CreateSurfaceMessage) {
          _activeSurfaceId = msg.surfaceId;
        }
      }
      _processor.processMessages(event.messages);
      _surfaceVersion++;
      _emitFinalReadyOrInitial(emit);
    } catch (error, stackTrace) {
      emit(
        SurfaceError(
          error: error,
          stackTrace: stackTrace,
          surfaceId: _activeSurfaceId,
        ),
      );
    }
  }

  void _onStreamCompleted(
    StreamCompleted event,
    void Function(A2uiSurfaceState) emit,
  ) {
    if (event.surfaceId != null) {
      _activeSurfaceId = event.surfaceId;
    }
    _surfaceVersion++;
    _emitFinalReadyOrInitial(emit);
  }

  void _onUpdateFormField(
    UpdateFormField event,
    void Function(A2uiSurfaceState) emit,
  ) {
    final surfaceId = event.surfaceId ?? _activeSurfaceId;
    if (surfaceId == null) return;

    final surface = _processor.groupModel.getSurface(surfaceId);
    if (surface == null) return;

    // Synchronous data model mutation with batching
    batch(() {
      surface.dataModel.set(event.path, event.value);
    });
    _surfaceVersion++;

    _emitFinalReadyOrInitial(emit);
  }

  void _onSubmitAction(
    SubmitAction event,
    void Function(A2uiSurfaceState) emit,
  ) {
    final surfaceId = event.surfaceId ?? _activeSurfaceId;
    if (surfaceId == null) {
      emit(
        SurfaceError(
          error: StateError('Cannot submit action: no surface is active.'),
        ),
      );
      return;
    }

    final surface = _processor.groupModel.getSurface(surfaceId);
    if (surface == null) {
      emit(
        SurfaceError(
          error: StateError(
            'Cannot submit action: surface "$surfaceId" not found.',
          ),
          surfaceId: surfaceId,
        ),
      );
      return;
    }

    // Capture form values
    final formValues = _extractFormData(surface);

    final response = A2uiActionResponse(
      actionName: event.actionName,
      surfaceId: surfaceId,
      sourceComponentId: event.sourceComponentId,
      timestamp: DateTime.now(),
      formData: formValues,
      context: event.context,
    );

    emit(
      SurfaceSubmitting(
        surfaceId: surfaceId,
        actionName: event.actionName,
        sourceComponentId: event.sourceComponentId,
        payload: response.toToolResult(),
      ),
    );

    _actionResponsesController.add(response);
  }

  void _onResetSurface(
    ResetSurface event,
    void Function(A2uiSurfaceState) emit,
  ) {
    final surfaceId = event.surfaceId ?? _activeSurfaceId;
    if (surfaceId != null) {
      _processor.groupModel.deleteSurface(surfaceId);
      if (surfaceId == _activeSurfaceId) {
        _activeSurfaceId = null;
      }
    }
    emit(const SurfaceInitial());
  }

  void _handleClientAction(A2uiClientAction action) {
    add(
      SubmitAction(
        actionName: action.name,
        sourceComponentId: action.sourceComponentId,
        surfaceId: action.surfaceId,
        context: action.context,
      ),
    );
  }

  List<A2uiMessage> _parseChunkToMessages(dynamic chunk) {
    if (chunk is A2uiMessage) {
      return [chunk];
    }
    if (chunk is Map<String, dynamic>) {
      return [A2uiMessage.fromJson(chunk)];
    }
    if (chunk is String) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) return const [];
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .cast<Map<String, dynamic>>()
            .map(A2uiMessage.fromJson)
            .toList();
      } else if (decoded is Map<String, dynamic>) {
        return [A2uiMessage.fromJson(decoded)];
      }
    }
    return const [];
  }

  void _emitSurfaceSnapshot(
    void Function(A2uiSurfaceState) emit, {
    required int messageCount,
  }) {
    if (_activeSurfaceId != null) {
      final surface = _processor.groupModel.getSurface(_activeSurfaceId!);
      if (surface != null && surface.componentsModel.all.isNotEmpty) {
        final formValues = _extractFormData(surface);
        emit(
          SurfaceReady(
            surfaceId: _activeSurfaceId!,
            surface: surface,
            formValues: formValues,
            version: _surfaceVersion,
          ),
        );
        return;
      }
    }

    emit(
      SurfaceStreaming(
        surfaceId: _activeSurfaceId,
        messageCount: messageCount,
      ),
    );
  }

  void _emitFinalReadyOrInitial(void Function(A2uiSurfaceState) emit) {
    if (_activeSurfaceId != null) {
      final surface = _processor.groupModel.getSurface(_activeSurfaceId!);
      if (surface != null) {
        final formValues = _extractFormData(surface);
        emit(
          SurfaceReady(
            surfaceId: _activeSurfaceId!,
            surface: surface,
            formValues: formValues,
            version: _surfaceVersion,
          ),
        );
        return;
      }
    }

    final allSurfaces = _processor.groupModel.allSurfaces;
    if (allSurfaces.isNotEmpty) {
      final first = allSurfaces.first;
      _activeSurfaceId = first.id;
      final formValues = _extractFormData(first);
      emit(
        SurfaceReady(
          surfaceId: first.id,
          surface: first,
          formValues: formValues,
          version: _surfaceVersion,
        ),
      );
      return;
    }

    emit(const SurfaceInitial());
  }

  Map<String, dynamic> _extractFormData(SurfaceModel<ComponentApi> surface) {
    final raw = surface.dataModel.get('/');
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    } else if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  @override
  Future<void> close() async {
    final oldCompleter = _activeStreamCompleter;
    _activeStreamCompleter = null;
    if (oldCompleter != null && !oldCompleter.isCompleted) {
      oldCompleter.complete();
    }
    await _activeStreamSubscription?.cancel();
    _activeStreamSubscription = null;
    await _actionResponsesController.close();
    await super.close();
  }
}
