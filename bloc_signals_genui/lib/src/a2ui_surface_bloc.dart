import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/src/a2ui_action_response.dart';
import 'package:bloc_signals_genui/src/a2ui_surface_event.dart';
import 'package:bloc_signals_genui/src/a2ui_surface_state.dart';
import 'package:bloc_signals_genui/src/standard_catalog.dart';
import 'package:meta/meta.dart';

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
  /// If [catalogs] is omitted, defaults to registering the standard [StandardCatalog].
  /// If [maxSurfaces] is provided (must be greater than `0`), enforces bounded
  /// Least-Recently-Used (LRU) eviction of inactive surfaces when the number of
  /// tracked surfaces exceeds [maxSurfaces].
  /// [maxResponseHistory] (defaults to `100`, must be greater than or equal to
  /// `0`) bounds the number of submitted [A2uiActionResponse] items buffered in
  /// memory for replay to late [actionResponses] subscribers.
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc(
  ///   maxSurfaces: 10,
  ///   maxResponseHistory: 50,
  /// );
  /// ```
  A2uiSurfaceBloc({
    List<Catalog<ComponentApi, FunctionImplementation>>? catalogs,
    this.maxSurfaces,
    this.maxResponseHistory = 100,
  })  : assert(
          maxSurfaces == null || maxSurfaces > 0,
          'maxSurfaces must be null or greater than 0.',
        ),
        assert(
          maxResponseHistory >= 0,
          'maxResponseHistory must be greater than or equal to 0.',
        ),
        catalogs = catalogs ??
            [
              StandardCatalog(),
              StandardCatalog(
                id: 'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json',
              ),
            ],
        super(initialState: const SurfaceInitial()) {
    _processor = MessageProcessor<ComponentApi>(
      catalogs: this.catalogs,
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
    on<CancelSubmission>(_onCancelSubmission);
    on<CompleteAction>(_onCompleteAction);
    on<SelectSurface>(_onSelectSurface);
    on<CloseSurface>(_onCloseSurface);
    on<ResetSurface>(_onResetSurface);
  }

  /// The active component catalogs registered with this surface bloc.
  final List<Catalog<ComponentApi, FunctionImplementation>> catalogs;

  /// Optional maximum number of surfaces to retain in memory before evicting
  /// the least-recently-used inactive surface.
  ///
  /// When `null`, surface count is unbounded.
  final int? maxSurfaces;

  /// Maximum number of submitted [A2uiActionResponse] instances retained in
  /// memory for replay to late subscribers on [actionResponses].
  ///
  /// Defaults to `100`. When set to `0`, historical replay buffering is
  /// disabled while live broadcast delivery remains active.
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc(maxResponseHistory: 25);
  /// print(bloc.maxResponseHistory); // 25
  /// ```
  final int maxResponseHistory;

  late final MessageProcessor<ComponentApi> _processor;

  /// Internal reactive signal tracking the primary active surface ID.
  final Signal<String?> _activeSurfaceIdSignal = signal<String?>(null);

  /// Reactive read-only signal exposing the currently active surface identifier.
  ///
  /// Updates synchronously in 0ms whenever a surface is created, selected via
  /// [SelectSurface], closed via [CloseSurface], deleted via
  /// [DeleteSurfaceMessage], or reset via [ResetSurface].
  ///
  /// ```dart
  /// final activeId = surfaceBloc.activeSurfaceId.value;
  /// ```
  ReadonlySignal<String?> get activeSurfaceId => _activeSurfaceIdSignal;

  /// Convenience getter returning the current raw value of [activeSurfaceId].
  ///
  /// ```dart
  /// final currentId = surfaceBloc.activeSurfaceIdValue;
  /// ```
  String? get activeSurfaceIdValue => _activeSurfaceIdSignal.value;

  String? get _activeSurfaceId => _activeSurfaceIdSignal.value;

  set _activeSurfaceId(String? value) {
    _activeSurfaceIdSignal.value = value;
  }

  /// Per-surface monotonically increasing content revision counters.
  final Map<String, int> _surfaceVersions = <String, int>{};

  /// Least-Recently-Used (LRU) surface access order from oldest to most recent.
  final List<String> _surfaceAccessOrder = <String>[];

  void _touchSurface(String surfaceId) {
    _surfaceAccessOrder
      ..remove(surfaceId)
      ..add(surfaceId);
  }

  int _bumpSurfaceVersion(String surfaceId) {
    final next = (_surfaceVersions[surfaceId] ?? 0) + 1;
    _surfaceVersions[surfaceId] = next;
    return next;
  }

  void _pruneSurfaceMetadata(String surfaceId) {
    _responseHistory.removeWhere((r) => r.surfaceId == surfaceId);
    _surfaceVersions.remove(surfaceId);
    _surfaceAccessOrder.remove(surfaceId);
  }

  String? _selectSurvivingSurfaceId() {
    for (var i = _surfaceAccessOrder.length - 1; i >= 0; i--) {
      final candidate = _surfaceAccessOrder[i];
      if (_processor.groupModel.getSurface(candidate) != null) {
        return candidate;
      }
    }
    final allSurfaces = _processor.groupModel.allSurfaces;
    if (allSurfaces.isNotEmpty) {
      return allSurfaces.first.id;
    }
    return null;
  }

  void _enforceMaxSurfacesBound() {
    final limit = maxSurfaces;
    if (limit == null) return;

    while (_processor.groupModel.allSurfaces.length > limit) {
      String? victimId;
      for (final id in _surfaceAccessOrder) {
        if (id != _activeSurfaceId &&
            _processor.groupModel.getSurface(id) != null) {
          victimId = id;
          break;
        }
      }
      victimId ??= _processor.groupModel.allSurfaces
          .map((s) => s.id)
          .firstWhere((id) => id != _activeSurfaceId);

      _processor.groupModel.deleteSurface(victimId);
      _pruneSurfaceMetadata(victimId);
    }
  }

  void _preProcessMessages(List<A2uiMessage> messages) {
    for (final msg in messages) {
      if (msg is CreateSurfaceMessage) {
        if (_processor.groupModel.getSurface(msg.surfaceId) != null) {
          _processor.groupModel.deleteSurface(msg.surfaceId);
        }
        _activeSurfaceId = msg.surfaceId;
        _touchSurface(msg.surfaceId);
        _bumpSurfaceVersion(msg.surfaceId);
      } else if (msg is UpdateComponentsMessage) {
        _touchSurface(msg.surfaceId);
        _bumpSurfaceVersion(msg.surfaceId);
      } else if (msg is UpdateDataModelMessage) {
        _touchSurface(msg.surfaceId);
        _bumpSurfaceVersion(msg.surfaceId);
      } else if (msg is DeleteSurfaceMessage) {
        _pruneSurfaceMetadata(msg.surfaceId);
        if (_activeSurfaceId == msg.surfaceId) {
          _activeSurfaceId = null;
        }
      }
    }
  }

  @override
  void onChange(Change<A2uiSurfaceState> change) {
    final nextState = change.nextState;
    if (nextState is SurfaceInitial) {
      _activeSurfaceId = null;
    } else if (nextState.surfaceId != null) {
      _activeSurfaceId = nextState.surfaceId;
    }
    super.onChange(change);
  }

  /// Returns an unmodifiable list of all surface identifiers currently discovered
  /// and registered in the underlying message processor.
  List<String> get availableSurfaceIds => List<String>.unmodifiable(
        _processor.groupModel.allSurfaces.map((s) => s.id),
      );

  /// Returns a [SurfaceReady] snapshot for [surfaceId] if it exists in the
  /// message processor, or `null` if the surface has not been created.
  SurfaceReady? getSurfaceReady(String surfaceId) {
    final surface = _processor.groupModel.getSurface(surfaceId);
    if (surface == null) return null;
    final formValues = _extractFormData(surface);
    final validationErrors = _validateForm(surface, formValues);
    return SurfaceReady(
      surfaceId: surfaceId,
      surface: surface,
      availableSurfaceIds: availableSurfaceIds,
      formValues: formValues,
      isValid: validationErrors.isEmpty,
      validationErrors: validationErrors,
      version: _surfaceVersions[surfaceId] ?? 0,
    );
  }

  final List<A2uiActionResponse> _responseHistory = [];

  /// Stream controller broadcasting validated user action responses back
  /// to external agent orchestrators.
  final StreamController<A2uiActionResponse> _actionResponsesController =
      StreamController<A2uiActionResponse>.broadcast();

  /// Stream of validated [A2uiActionResponse] objects ready for upstream tool calls.
  ///
  /// Buffers past responses so that subscribers attaching after an action is dispatched
  /// still receive previously emitted action responses without races.
  Stream<A2uiActionResponse> get actionResponses {
    late final StreamController<A2uiActionResponse> controller;
    StreamSubscription<A2uiActionResponse>? sub;
    controller = StreamController<A2uiActionResponse>(
      onListen: () {
        sub = _actionResponsesController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );

        List<A2uiActionResponse>.of(_responseHistory).forEach(controller.add);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// The underlying [MessageProcessor] maintaining the A2UI surface graph.
  MessageProcessor<ComponentApi> get processor => _processor;

  bool _isClosing = false;
  StreamSubscription<dynamic>? _activeStreamSubscription;
  Completer<void>? _activeStreamCompleter;
  int _messageCount = 0;

  Future<void> _onIngestStream(
    IngestStream event,
    void Function(A2uiSurfaceState) emit,
  ) async {
    if (isClosed || _isClosing) return;

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

    final completer = Completer<void>();
    _activeStreamCompleter = completer;

    late final StreamSubscription<dynamic> subscription;
    try {
      subscription = event.stream.listen(
        (chunk) async {
          if (isClosed ||
              _isClosing ||
              !identical(_activeStreamSubscription, subscription)) {
            await _safeCancel(subscription);
            if (!completer.isCompleted) completer.complete();
            return;
          }

          try {
            final messages = _parseChunkToMessages(chunk);
            if (messages.isNotEmpty) {
              _preProcessMessages(messages);
              _processor.processMessages(messages);
              _enforceMaxSurfacesBound();
              messageCount += messages.length;
              _messageCount += messages.length;

              _emitSurfaceSnapshot(emit, messageCount: messageCount);
            }
          } catch (error, stackTrace) {
            onError(error, stackTrace);
            if (!isClosed &&
                !_isClosing &&
                identical(_activeStreamSubscription, subscription)) {
              emit(
                SurfaceError(
                  error: error,
                  stackTrace: stackTrace,
                  surfaceId: _activeSurfaceId,
                ),
              );
            }
            await _safeCancel(subscription);
            if (identical(_activeStreamSubscription, subscription)) {
              _activeStreamSubscription = null;
            }
            if (!completer.isCompleted) completer.complete();
            if (error is Error) rethrow;
          }
        },
        onError: (Object error, StackTrace stackTrace) async {
          onError(error, stackTrace);
          if (!isClosed &&
              !_isClosing &&
              identical(_activeStreamSubscription, subscription)) {
            emit(
              SurfaceError(
                error: error,
                stackTrace: stackTrace,
                surfaceId: _activeSurfaceId,
              ),
            );
          }
          await _safeCancel(subscription);
          if (identical(_activeStreamSubscription, subscription)) {
            _activeStreamSubscription = null;
          }
          if (!completer.isCompleted) completer.complete();
          if (error is Error) throw error;
        },
        onDone: () {
          if (identical(_activeStreamSubscription, subscription)) {
            _activeStreamSubscription = null;
            if (!isClosed && !_isClosing) {
              _emitSurfaceSnapshot(emit, messageCount: messageCount);
            }
          }
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      _activeStreamSubscription = subscription;
    } catch (e, st) {
      if (!completer.isCompleted) completer.complete();
      _activeStreamCompleter = null;
      onError(e, st);
      rethrow;
    } finally {
      await _safeCancel(oldSub);
    }

    if (isClosed ||
        _isClosing ||
        !identical(_activeStreamSubscription, subscription)) {
      return;
    }

    await completer.future;
  }

  FutureOr<void> _onProcessMessage(
    ProcessMessage event,
    void Function(A2uiSurfaceState) emit,
  ) {
    try {
      final message = _normalizeMessage(event.message);
      _preProcessMessages([message]);
      _processor.processMessages([message]);
      _enforceMaxSurfacesBound();
      _messageCount++;
      _emitSurfaceSnapshot(emit);
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      if (error is Error) rethrow;
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
      final message = A2uiMessage.fromJson(_normalizeJson(event.json));
      _preProcessMessages([message]);
      _processor.processMessages([message]);
      _enforceMaxSurfacesBound();
      _messageCount++;
      _emitSurfaceSnapshot(emit);
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      if (error is Error) rethrow;
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
      final normalizedMessages = event.messages.map(_normalizeMessage).toList();
      _preProcessMessages(normalizedMessages);
      _processor.processMessages(normalizedMessages);
      _enforceMaxSurfacesBound();
      _messageCount += normalizedMessages.length;
      _emitSurfaceSnapshot(emit);
    } catch (error, stackTrace) {
      onError(error, stackTrace);
      if (error is Error) rethrow;
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
      _touchSurface(event.surfaceId!);
    }
    final targetId = _activeSurfaceId;
    if (targetId != null) {
      _bumpSurfaceVersion(targetId);
    }
    _emitSurfaceSnapshot(emit);
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
    _touchSurface(surfaceId);
    _bumpSurfaceVersion(surfaceId);

    _emitSurfaceSnapshot(emit);
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

    _touchSurface(surfaceId);

    // Capture form values and enforce validation contract
    final formValues = _extractFormData(surface);
    final validationErrors = _validateForm(surface, formValues);
    if (validationErrors.isNotEmpty) {
      final version = _bumpSurfaceVersion(surfaceId);
      emit(
        SurfaceReady(
          surfaceId: surfaceId,
          surface: surface,
          availableSurfaceIds: availableSurfaceIds,
          formValues: formValues,
          isValid: false,
          validationErrors: validationErrors,
          version: version,
        ),
      );
      return;
    }

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

    _responseHistory.add(response);
    if (_responseHistory.length > maxResponseHistory) {
      _responseHistory.removeRange(
        0,
        _responseHistory.length - maxResponseHistory,
      );
    }
    _actionResponsesController.add(response);
  }

  void _onCancelSubmission(
    CancelSubmission event,
    void Function(A2uiSurfaceState) emit,
  ) {
    _emitRecoveredSubmissionState(
      surfaceId: event.surfaceId,
      error: event.error,
      emit: emit,
    );
  }

  void _onCompleteAction(
    CompleteAction event,
    void Function(A2uiSurfaceState) emit,
  ) {
    _emitRecoveredSubmissionState(
      surfaceId: event.surfaceId,
      error: event.error,
      emit: emit,
    );
  }

  void _emitRecoveredSubmissionState({
    required String? surfaceId,
    required String? error,
    required void Function(A2uiSurfaceState) emit,
  }) {
    final targetSurfaceId = surfaceId ?? activeSurfaceIdValue;
    if (targetSurfaceId == null) return;

    final surface = _processor.groupModel.getSurface(targetSurfaceId);
    if (surface == null) return;

    _touchSurface(targetSurfaceId);
    final formValues = _extractFormData(surface);
    final formErrors = _validateForm(surface, formValues);
    final validationErrors = List<String>.from(formErrors);
    if (error != null && error.trim().isNotEmpty) {
      final trimmed = error.trim();
      if (!validationErrors.contains(trimmed)) {
        validationErrors.add(trimmed);
      }
    }

    final version = _bumpSurfaceVersion(targetSurfaceId);
    emit(
      SurfaceReady(
        surfaceId: targetSurfaceId,
        surface: surface,
        availableSurfaceIds: availableSurfaceIds,
        formValues: formValues,
        isValid: validationErrors.isEmpty,
        validationErrors: validationErrors,
        version: version,
      ),
    );
  }

  void _onSelectSurface(
    SelectSurface event,
    void Function(A2uiSurfaceState) emit,
  ) {
    final surface = _processor.groupModel.getSurface(event.surfaceId);
    if (surface == null) {
      final error =
          ArgumentError('Surface "${event.surfaceId}" does not exist.');
      onError(error, StackTrace.current);
      emit(
        SurfaceError(
          error: error,
          surfaceId: event.surfaceId,
        ),
      );
      return;
    }

    _activeSurfaceId = event.surfaceId;
    _touchSurface(event.surfaceId);
    _emitSurfaceSnapshot(emit);
  }

  void _onCloseSurface(
    CloseSurface event,
    void Function(A2uiSurfaceState) emit,
  ) {
    _evictAndEmitSurface(targetId: event.surfaceId, emit: emit);
  }

  void _onResetSurface(
    ResetSurface event,
    void Function(A2uiSurfaceState) emit,
  ) {
    final surfaceId = event.surfaceId;
    if (surfaceId == null) {
      _cancelActiveStream();
      for (final surface in _processor.groupModel.allSurfaces.toList()) {
        _processor.groupModel.deleteSurface(surface.id);
      }
      _responseHistory.clear();
      _surfaceVersions.clear();
      _surfaceAccessOrder.clear();
      _activeSurfaceId = null;
      _messageCount = 0;
      emit(const SurfaceInitial());
      return;
    }

    _evictAndEmitSurface(targetId: surfaceId, emit: emit);
  }

  void _cancelActiveStream() {
    final oldCompleter = _activeStreamCompleter;
    _activeStreamCompleter = null;
    if (oldCompleter != null && !oldCompleter.isCompleted) {
      oldCompleter.complete();
    }
    final oldSub = _activeStreamSubscription;
    _activeStreamSubscription = null;
    if (oldSub != null) {
      unawaited(_safeCancel(oldSub));
    }
  }

  void _evictAndEmitSurface({
    required String targetId,
    required void Function(A2uiSurfaceState) emit,
  }) {
    if (targetId == _activeSurfaceId) {
      _cancelActiveStream();
    }

    _pruneSurfaceMetadata(targetId);

    final surface = _processor.groupModel.getSurface(targetId);
    if (surface == null) {
      if (_activeSurfaceId == targetId) {
        _activeSurfaceId = null;
        _emitSurfaceSnapshot(emit);
      }
      return;
    }

    _processor.groupModel.deleteSurface(targetId);
    if (_activeSurfaceId == targetId) {
      _activeSurfaceId = null;
    }
    _emitSurfaceSnapshot(emit);
  }

  List<A2uiMessage> _parseChunkToMessages(dynamic chunk) {
    if (chunk is A2uiMessage) {
      return [_normalizeMessage(chunk)];
    }
    if (chunk is Map<String, dynamic>) {
      return [A2uiMessage.fromJson(_normalizeJson(chunk))];
    }
    if (chunk is String) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) return const [];
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .cast<Map<String, dynamic>>()
            .map((c) => A2uiMessage.fromJson(_normalizeJson(c)))
            .toList();
      } else if (decoded is Map<String, dynamic>) {
        return [A2uiMessage.fromJson(_normalizeJson(decoded))];
      }
    }
    return const [];
  }

  A2uiMessage _normalizeMessage(A2uiMessage msg) {
    if (msg is UpdateComponentsMessage) {
      final normalizedComps =
          msg.components.map(_normalizeComponentMap).toList();
      return UpdateComponentsMessage(
        surfaceId: msg.surfaceId,
        components: normalizedComps,
      );
    }
    return msg;
  }

  Map<String, dynamic> _normalizeJson(Map<String, dynamic> json) {
    if (json.containsKey('updateComponents')) {
      final update = json['updateComponents'];
      if (update is Map && update.containsKey('components')) {
        final comps = update['components'];
        if (comps is List) {
          final normalizedComps = comps.map((c) {
            if (c is Map<String, dynamic>) {
              return _normalizeComponentMap(c);
            } else if (c is Map) {
              return _normalizeComponentMap(c.cast<String, dynamic>());
            }
            return c;
          }).toList();
          return {
            ...json,
            'updateComponents': {
              ...update,
              'components': normalizedComps,
            },
          };
        }
      }
    }
    return json;
  }

  Map<String, dynamic> _normalizeComponentMap(Map<String, dynamic> comp) {
    var result = comp;
    if (comp.containsKey('properties') && comp['properties'] is Map) {
      final props = (comp['properties'] as Map).cast<String, dynamic>();
      final copy = Map<String, dynamic>.from(comp)..remove('properties');
      result = {...copy, ...props};
    }
    if (result.containsKey('child')) {
      final child = result['child'];
      if (child is Map &&
          child.containsKey('id') &&
          !child.containsKey('path')) {
        result = {
          ...result,
          'child': child['id'],
        };
      }
    }
    if (result.containsKey('children')) {
      final children = result['children'];
      if (children is List) {
        final normalizedChildren = children.map((c) {
          if (c is Map && c.containsKey('id')) {
            return c['id'];
          }
          return c;
        }).toList();
        result = {
          ...result,
          'children': normalizedChildren,
        };
      }
    }
    if (result.containsKey('action')) {
      final action = result['action'];
      if (action is Map) {
        if (!action.containsKey('event') &&
            !action.containsKey('functionCall')) {
          result = {
            ...result,
            'action': {
              'event': action,
            },
          };
        }
      } else if (action is String) {
        result = {
          ...result,
          'action': {
            'event': {'name': action},
          },
        };
      }
    }
    return result;
  }

  /// Emits the appropriate surface state snapshot based on active surface and
  /// component readiness.
  ///
  /// Surfaces with populated components emit [SurfaceReady]. Surfaces that are
  /// created but have not yet received components remain in [SurfaceStreaming]
  /// to eliminate skeleton-vs-blank UI mismatches between streaming and message
  /// ingestion paths (F19). If no surfaces exist and an active stream is
  /// pending, emits [SurfaceStreaming]; otherwise emits [SurfaceInitial].
  void _emitSurfaceSnapshot(
    void Function(A2uiSurfaceState) emit, {
    int? messageCount,
  }) {
    final count = messageCount ?? _messageCount;
    var targetSurfaceId = _activeSurfaceId;
    SurfaceModel<ComponentApi>? surface;

    if (targetSurfaceId != null) {
      surface = _processor.groupModel.getSurface(targetSurfaceId);
    }

    if (surface == null) {
      final fallbackId = _selectSurvivingSurfaceId();
      if (fallbackId != null) {
        surface = _processor.groupModel.getSurface(fallbackId);
        targetSurfaceId = fallbackId;
        _activeSurfaceId = targetSurfaceId;
      } else {
        targetSurfaceId = null;
        _activeSurfaceId = null;
      }
    }

    if (surface != null && surface.componentsModel.all.isNotEmpty) {
      final formValues = _extractFormData(surface);
      final validationErrors = _validateForm(surface, formValues);
      emit(
        SurfaceReady(
          surfaceId: targetSurfaceId!,
          surface: surface,
          availableSurfaceIds: availableSurfaceIds,
          formValues: formValues,
          isValid: validationErrors.isEmpty,
          validationErrors: validationErrors,
          version: _surfaceVersions[targetSurfaceId] ?? 0,
        ),
      );
      return;
    }

    if (surface != null) {
      emit(
        SurfaceStreaming(
          surfaceId: targetSurfaceId,
          messageCount: count,
        ),
      );
      return;
    }

    if (_activeStreamSubscription != null) {
      emit(
        SurfaceStreaming(
          messageCount: count,
        ),
      );
      return;
    }

    emit(const SurfaceInitial());
  }

  static const int _maxRegexCacheSize = 100;
  static final Map<String, RegExp?> _regexCache = <String, RegExp?>{};

  /// Returns the current number of entries in the validation regular expression
  /// cache.
  @visibleForTesting
  static int get debugRegexCacheSize => _regexCache.length;

  /// Clears all cached validation regular expressions.
  @visibleForTesting
  static void clearRegexCache() {
    _regexCache.clear();
  }

  static RegExp? _resolveValidationRegExp(String pattern) {
    if (_regexCache.containsKey(pattern)) {
      final cached = _regexCache.remove(pattern);
      _regexCache[pattern] = cached;
      return cached;
    }
    RegExp? compiled;
    try {
      compiled = RegExp(pattern);
    } on FormatException {
      compiled = null;
    }
    if (_regexCache.length >= _maxRegexCacheSize) {
      _regexCache.remove(_regexCache.keys.first);
    }
    _regexCache[pattern] = compiled;
    return compiled;
  }

  List<String> _validateForm(
    SurfaceModel<ComponentApi> surface,
    Map<String, dynamic> formValues,
  ) {
    final errors = <String>[];
    for (final component in surface.componentsModel.all) {
      final props = component.properties;
      final isRequired =
          props['required'] == true || props['isRequired'] == true;
      final label = props['label']?.toString() ?? component.id;

      String? fieldPath;
      final valueProp = props['value'];
      if (valueProp is Map && valueProp.containsKey('path')) {
        fieldPath = valueProp['path']?.toString();
      } else if (props.containsKey('name')) {
        fieldPath = props['name']?.toString();
      } else {
        fieldPath = '/${component.id}';
      }

      dynamic fieldValue;
      if (fieldPath != null) {
        final normalized =
            fieldPath.startsWith('/') ? fieldPath.substring(1) : fieldPath;
        if (formValues.containsKey(fieldPath)) {
          fieldValue = formValues[fieldPath];
        } else if (formValues.containsKey(normalized)) {
          fieldValue = formValues[normalized];
        } else {
          dynamic current = formValues;
          final segments = normalized.split('/').where((s) => s.isNotEmpty);
          for (final seg in segments) {
            if (current is Map && current.containsKey(seg)) {
              current = current[seg];
            } else {
              current = null;
              break;
            }
          }
          fieldValue = current;
        }
      }

      if (isRequired) {
        if (fieldValue == null ||
            (fieldValue is String && fieldValue.trim().isEmpty) ||
            (fieldValue is Iterable && fieldValue.isEmpty) ||
            (fieldValue is Map && fieldValue.isEmpty)) {
          errors.add('Field "$label" is required.');
        }
      }

      if (fieldValue is String && fieldValue.isNotEmpty) {
        final pattern = props['pattern']?.toString() ??
            props['validationRegexp']?.toString();
        if (pattern != null) {
          final regExp = _resolveValidationRegExp(pattern);
          if (regExp != null && !regExp.hasMatch(fieldValue)) {
            errors.add('Field "$label" does not match the required pattern.');
          }
        }
        final minLength = (props['minLength'] as num?)?.toInt();
        if (minLength != null && fieldValue.length < minLength) {
          errors.add('Field "$label" must be at least $minLength characters.');
        }
        final maxLength = (props['maxLength'] as num?)?.toInt();
        if (maxLength != null && fieldValue.length > maxLength) {
          errors.add('Field "$label" must be at most $maxLength characters.');
        }
      }
    }
    return errors;
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
    _isClosing = true;
    _responseHistory.clear();
    final oldCompleter = _activeStreamCompleter;
    _activeStreamCompleter = null;
    if (oldCompleter != null && !oldCompleter.isCompleted) {
      oldCompleter.complete();
    }
    final oldSub = _activeStreamSubscription;
    _activeStreamSubscription = null;
    await _safeCancel(oldSub);
    await _actionResponsesController.close();
    await super.close();
  }

  Future<void> _safeCancel(StreamSubscription<dynamic>? sub) async {
    if (sub == null) return;
    try {
      await sub.cancel();
    } catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }
}
