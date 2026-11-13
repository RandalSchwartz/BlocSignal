import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart' show A2uiMessage;
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
  /// If [catalogs] is omitted, defaults to registering [StandardCatalog],
  /// [BasicCatalog.v0_9], and [BasicCatalog.v1_0].
  /// [maxSurfaces] defaults to [defaultMaxSurfaces] (`20`) and enforces bounded
  /// Least-Recently-Used (LRU) eviction of inactive surfaces when the number of
  /// tracked surfaces exceeds [maxSurfaces] (must be greater than `0` when
  /// non-null). Pass `maxSurfaces: null` to explicitly opt out of eviction.
  /// [maxResponseHistory] (defaults to `100`, must be greater than or equal to
  /// `0`) bounds the number of submitted [A2uiActionResponse] items buffered in
  /// memory for replay to late [actionResponses] subscribers.
  ///
  /// If [outboundListener] is provided, it receives every outbound
  /// [RendererToAgentMessage] produced by the RPC layer (such as
  /// [CallAgentFunctionMessage] and [RendererFunctionResponseMessage]) in
  /// addition to broadcasting on [outboundMessages].
  /// [defaultRpcTimeout] (defaults to `const Duration(seconds: 30)`) sets the
  /// default timeout for outbound [callAgentFunction] requests.
  /// [validationConfig] configures optional graph-level checks enforced by the
  /// underlying [MessageProcessor].
  /// When [reportErrorsOnly] is `true`, [MessageProcessor.processMessages] emits
  /// mapped [ErrorMessage]s instead of throwing [A2uiError]s.
  /// When [unifiedOutbound] is `true`, outbound actions are also forwarded to
  /// [outboundMessages] as [ActionMessage] envelopes.
  /// [maxAgentCallCacheEntries] (defaults to `256`) bounds settled agent
  /// function call responses retained per surface.
  /// [patternValidator] optionally overrides the built-in ReDoS safety check
  /// for component validation `pattern` and `validationRegexp` strings.
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc(
  ///   maxSurfaces: 10,
  ///   maxResponseHistory: 50,
  /// );
  /// ```
  A2uiSurfaceBloc({
    List<Catalog<ComponentApi, FunctionImplementation>>? catalogs,
    this.maxSurfaces = defaultMaxSurfaces,
    this.maxResponseHistory = 100,
    OutboundMessageListener? outboundListener,
    this.defaultRpcTimeout = const Duration(seconds: 30),
    this.validationConfig,
    this.reportErrorsOnly = false,
    this.unifiedOutbound = false,
    this.maxAgentCallCacheEntries = 256,
    this.patternValidator,
  })  : assert(
          maxSurfaces == null || maxSurfaces > 0,
          'maxSurfaces must be null or greater than 0.',
        ),
        assert(
          maxResponseHistory >= 0,
          'maxResponseHistory must be greater than or equal to 0.',
        ),
        _userOutboundListener = outboundListener,
        catalogs = catalogs ??
            [
              StandardCatalog(),
              BasicCatalog.v0_9(),
              BasicCatalog.v1_0(),
            ],
        super(initialState: const SurfaceInitial()) {
    _processor = MessageProcessor<ComponentApi>(
      catalogs: this.catalogs,
      outboundListener: _handleOutboundRpcMessage,
      defaultTimeout: defaultRpcTimeout,
      validationConfig: validationConfig,
      reportErrorsOnly: reportErrorsOnly,
      unifiedOutbound: unifiedOutbound,
      maxAgentCallCacheEntries: maxAgentCallCacheEntries,
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

  /// Default maximum number of surfaces retained in memory before evicting the
  /// least-recently-used inactive surface.
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc();
  /// assert(bloc.maxSurfaces == A2uiSurfaceBloc.defaultMaxSurfaces);
  /// ```
  static const int defaultMaxSurfaces = 20;

  /// The active component catalogs registered with this surface bloc.
  final List<Catalog<ComponentApi, FunctionImplementation>> catalogs;

  /// Optional maximum number of surfaces to retain in memory before evicting
  /// the least-recently-used inactive surface.
  ///
  /// Defaults to [defaultMaxSurfaces] (`20`). When explicitly set to `null`,
  /// surface count is unbounded.
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

  /// Default timeout for outbound [callAgentFunction] requests when
  /// [CallOptions.timeout] is omitted.
  ///
  /// Defaults to `const Duration(seconds: 30)`.
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc(
  ///   defaultRpcTimeout: const Duration(seconds: 15),
  /// );
  /// print(bloc.defaultRpcTimeout.inSeconds); // 15
  /// ```
  final Duration defaultRpcTimeout;

  /// Optional graph-level validation rules applied by the underlying
  /// [MessageProcessor].
  final ValidationConfig? validationConfig;

  /// Whether [MessageProcessor.processMessages] emits mapped [ErrorMessage]s
  /// instead of rethrowing [A2uiError]s.
  final bool reportErrorsOnly;

  /// Whether surface actions are also forwarded to [outboundMessages] as
  /// [ActionMessage] envelopes.
  final bool unifiedOutbound;

  /// Maximum number of settled agent function call responses cached per surface.
  final int maxAgentCallCacheEntries;

  /// Optional callback that overrides the built-in ReDoS safety heuristic for
  /// form validation `pattern` and `validationRegexp` strings.
  ///
  /// When provided, patterns exceeding [maxValidationPatternLength] are still
  /// rejected before invoking this callback, and compiled patterns bypass the
  /// shared static cache so custom policies do not affect other instances.
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc(
  ///   patternValidator: (pattern) => !pattern.contains('forbidden'),
  /// );
  /// ```
  final bool Function(String pattern)? patternValidator;

  final OutboundMessageListener? _userOutboundListener;

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
      if (_processor.model.getSurface(candidate) != null) {
        return candidate;
      }
    }
    final allSurfaces = _processor.model.allSurfaces;
    if (allSurfaces.isNotEmpty) {
      return allSurfaces.first.id;
    }
    return null;
  }

  void _enforceMaxSurfacesBound() {
    final limit = maxSurfaces;
    if (limit == null) return;

    while (_processor.model.allSurfaces.length > limit) {
      String? victimId;
      for (final id in _surfaceAccessOrder) {
        if (id != _activeSurfaceId && _processor.model.getSurface(id) != null) {
          victimId = id;
          break;
        }
      }
      victimId ??= _processor.model.allSurfaces
          .map((s) => s.id)
          .firstWhere((id) => id != _activeSurfaceId);

      _processor.model.deleteSurface(victimId);
      _pruneSurfaceMetadata(victimId);
    }
  }

  void _preProcessMessages(List<A2uiMessage> messages) {
    for (final msg in messages) {
      if (msg is CreateSurfaceMessage) {
        if (_processor.model.getSurface(msg.surfaceId) != null) {
          _processor.model.deleteSurface(msg.surfaceId);
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
        _processor.model.allSurfaces.map((s) => s.id),
      );

  /// Returns a [SurfaceReady] snapshot for [surfaceId] if it exists in the
  /// message processor, or `null` if the surface has not been created.
  SurfaceReady? getSurfaceReady(String surfaceId) {
    final surface = _processor.model.getSurface(surfaceId);
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

  /// The bidirectional [RpcHandler] coordinating function calls between the
  /// renderer and the agent.
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc();
  /// print(bloc.rpc.pendingCallCount); // 0
  /// ```
  RpcHandler get rpc => _processor.rpc;

  final List<RendererToAgentMessage> _outboundMessageHistory = [];

  final StreamController<RendererToAgentMessage> _outboundMessagesController =
      StreamController<RendererToAgentMessage>.broadcast();

  FutureOr<void> _handleOutboundRpcMessage(RendererToAgentMessage message) {
    _outboundMessageHistory.add(message);
    if (_outboundMessageHistory.length > maxResponseHistory) {
      _outboundMessageHistory.removeRange(
        0,
        _outboundMessageHistory.length - maxResponseHistory,
      );
    }
    if (!_outboundMessagesController.isClosed) {
      _outboundMessagesController.add(message);
    }
    return _userOutboundListener?.call(message);
  }

  /// Unmodifiable snapshot of buffered outbound [RendererToAgentMessage] items
  /// (bounded by [maxResponseHistory]).
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc();
  /// print(bloc.outboundMessageHistory.isEmpty); // true
  /// ```
  List<RendererToAgentMessage> get outboundMessageHistory =>
      List<RendererToAgentMessage>.unmodifiable(_outboundMessageHistory);

  /// Stream of outbound [RendererToAgentMessage] envelopes (such as
  /// [CallAgentFunctionMessage] and [RendererFunctionResponseMessage]) emitted
  /// by the RPC layer.
  ///
  /// Replays buffered [outboundMessageHistory] to new subscribers before
  /// forwarding live broadcast messages so synchronous RPC replies are never
  /// missed.
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc();
  /// final sub = bloc.outboundMessages.listen((msg) {
  ///   print(msg.toJson());
  /// });
  /// await sub.cancel();
  /// ```
  Stream<RendererToAgentMessage> get outboundMessages {
    late final StreamController<RendererToAgentMessage> controller;
    StreamSubscription<RendererToAgentMessage>? sub;
    controller = StreamController<RendererToAgentMessage>(
      onListen: () {
        sub = _outboundMessagesController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );

        List<RendererToAgentMessage>.of(_outboundMessageHistory)
            .forEach(controller.add);
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Sends [call] to the agent on behalf of [surfaceId] and completes when the
  /// matching [AgentFunctionResponseMessage] arrives via [ProcessMessage],
  /// [ProcessJsonMessage], [ProcessMessages], or [IngestStream].
  ///
  /// ```dart
  /// final bloc = A2uiSurfaceBloc();
  /// final future = bloc.callAgentFunction(
  ///   'surf-1',
  ///   FunctionCall(call: 'fetchWeather', args: const {'city': 'Portland'}),
  /// );
  /// ```
  Future<Object?> callAgentFunction(
    String surfaceId,
    FunctionCall call, {
    CallOptions? options,
  }) =>
      _processor.callAgentFunction(surfaceId, call, options: options);

  bool _isClosing = false;
  StreamSubscription<dynamic>? _activeStreamSubscription;
  static bool _isFatalVmError(Object error) =>
      error is OutOfMemoryError ||
      error is StackOverflowError ||
      error is AssertionError;

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
            // Intentional `on Object catch` (SCAR-ERR-02): report stream chunk
            // failures to `onError`, emit `SurfaceError`, clean up active stream
            // completer/pointer, and rethrow only fatal VM errors.
          } on Object catch (error, stackTrace) {
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
            if (_isFatalVmError(error)) rethrow;
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
          if (_isFatalVmError(error) || error is StateError) {
            Error.throwWithStackTrace(error, stackTrace);
          }
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
      // Intentional `on Object catch` (SCAR-ERR-02): complete stream completer
      // and report subscription setup failure to `onError` before rethrowing.
    } on Object catch (e, st) {
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
      // Intentional `on Object catch` (SCAR-ERR-02): report to `onError` and
      // rethrow only fatal VM errors via `_isFatalVmError(error)` before
      // emitting `SurfaceError` for recoverable exceptions and type mismatches.
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
      if (_isFatalVmError(error)) rethrow;
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
      // Intentional `on Object catch` (SCAR-ERR-02): report to `onError` and
      // rethrow only fatal VM errors via `_isFatalVmError(error)` before
      // emitting `SurfaceError` for recoverable exceptions and type mismatches.
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
      if (_isFatalVmError(error)) rethrow;
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
      // Intentional `on Object catch` (SCAR-ERR-02): report to `onError` and
      // rethrow only fatal VM errors via `_isFatalVmError(error)` before
      // emitting `SurfaceError` for recoverable exceptions and type mismatches.
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
      if (_isFatalVmError(error)) rethrow;
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

    final surface = _processor.model.getSurface(surfaceId);
    if (surface == null) return;

    // Synchronous data model mutation with batching
    batch(() {
      surface.dataModel.set(event.path, event.value);
    });
    _touchSurface(surfaceId);
    _bumpSurfaceVersion(surfaceId);

    _emitSurfaceSnapshot(emit);
  }

  FutureOr<void> _onSubmitAction(
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
      return null;
    }

    final surface = _processor.model.getSurface(surfaceId);
    if (surface == null) {
      emit(
        SurfaceError(
          error: StateError(
            'Cannot submit action: surface "$surfaceId" not found.',
          ),
          surfaceId: surfaceId,
        ),
      );
      return null;
    }

    _touchSurface(surfaceId);

    final sourceComponent =
        surface.componentsModel.get(event.sourceComponentId);
    final dataContext = ComponentContext(
      surface,
      sourceComponent ??
          ComponentModel(event.sourceComponentId, 'Button', const {}),
    ).dataContext;

    if (sourceComponent != null) {
      final rawAction = sourceComponent.properties['action'];
      if (rawAction is Map) {
        final Object? fc = rawAction['functionCall'] is Map
            ? rawAction['functionCall']
            : rawAction;
        if (fc is Map && dataContext.isFunctionCall(fc)) {
          return dataContext
              .withUserActivation()
              .evaluateFunctionCall(Map<String, dynamic>.from(fc))
              .then((_) {});
        }
      }
    }

    // Capture form values and enforce validation contract synchronously.
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
      return null;
    }

    void dispatchResolvedContext(Map<String, dynamic> resolvedContext) {
      if (isClosed || _isClosing) return;
      final response = A2uiActionResponse(
        actionName: event.actionName,
        surfaceId: surfaceId,
        sourceComponentId: event.sourceComponentId,
        timestamp: DateTime.now(),
        formData: formValues,
        context: resolvedContext,
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

    if (event.context.isEmpty) {
      dispatchResolvedContext(event.context);
      return null;
    }

    final resolvedOrFuture =
        dataContext.withUserActivation().resolveActionAsync({
      'event': {
        'name': event.actionName,
        'context': event.context,
      },
    });

    if (resolvedOrFuture is Future<Map<String, dynamic>?>) {
      return resolvedOrFuture.then((resolved) {
        final ctx = _extractResolvedEventContext(resolved) ?? event.context;
        dispatchResolvedContext(ctx);
      });
    }

    final ctx = _extractResolvedEventContext(resolvedOrFuture) ?? event.context;
    dispatchResolvedContext(ctx);
    return null;
  }

  Map<String, dynamic>? _extractResolvedEventContext(
    Map<String, dynamic>? resolved,
  ) {
    if (resolved == null) return null;
    final eventMap = resolved['event'];
    if (eventMap is Map) {
      final ctx = eventMap['context'];
      if (ctx is Map) return Map<String, dynamic>.from(ctx);
    }
    return null;
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

    final surface = _processor.model.getSurface(targetSurfaceId);
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
    final surface = _processor.model.getSurface(event.surfaceId);
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
      for (final surface in _processor.model.allSurfaces.toList()) {
        _processor.model.deleteSurface(surface.id);
      }
      _responseHistory.clear();
      _outboundMessageHistory.clear();
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

    final surface = _processor.model.getSurface(targetId);
    if (surface == null) {
      if (_activeSurfaceId == targetId) {
        _activeSurfaceId = null;
        _emitSurfaceSnapshot(emit);
      }
      return;
    }

    _processor.model.deleteSurface(targetId);
    if (_activeSurfaceId == targetId) {
      _activeSurfaceId = null;
    }
    _emitSurfaceSnapshot(emit);
  }

  static Map<String, dynamic> _toStringKeyedMap(
    Map<dynamic, dynamic> map, {
    String context = 'JSON object',
  }) {
    if (map is Map<String, dynamic>) {
      return map;
    }
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException(
          'Expected String keys in $context, got ${key.runtimeType}.',
        );
      }
      result[key] = entry.value;
    }
    return result;
  }

  List<A2uiMessage> _parseChunkToMessages(dynamic chunk) {
    if (chunk is A2uiMessage) {
      return [_normalizeMessage(chunk)];
    }
    if (chunk is Map) {
      return [
        A2uiMessage.fromJson(_normalizeJson(_toStringKeyedMap(chunk))),
      ];
    }
    if (chunk is String) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) return const [];
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        final messages = <A2uiMessage>[];
        for (final item in decoded) {
          if (item is! Map) {
            throw FormatException(
              'Expected JSON object in message list, got ${item.runtimeType}.',
            );
          }
          messages.add(
            A2uiMessage.fromJson(
              _normalizeJson(
                _toStringKeyedMap(item, context: 'message list item'),
              ),
            ),
          );
        }
        return messages;
      } else if (decoded is Map) {
        return [
          A2uiMessage.fromJson(_normalizeJson(_toStringKeyedMap(decoded))),
        ];
      }
    }
    return const [];
  }

  A2uiMessage _normalizeMessage(A2uiMessage msg) {
    final version = msg.version == 'v1.0'
        ? A2uiProtocolVersion.v1_0.jsonValue
        : msg.version;
    if (msg is UpdateComponentsMessage) {
      final normalizedComps =
          msg.components.map(_normalizeComponentMap).toList();
      return UpdateComponentsMessage(
        version: version,
        surfaceId: msg.surfaceId,
        components: normalizedComps,
      );
    }
    if (msg is CreateSurfaceMessage) {
      if (msg.components != null || version != msg.version) {
        final normalizedComps =
            msg.components?.map(_normalizeComponentMap).toList();
        return CreateSurfaceMessage(
          version: version,
          surfaceId: msg.surfaceId,
          catalogId: msg.catalogId,
          theme: msg.theme,
          sendDataModel: msg.sendDataModel,
          components: normalizedComps,
          dataModel: msg.dataModel,
          metadata: msg.metadata,
        );
      }
      return msg;
    }
    if (version != msg.version) {
      if (msg is UpdateDataModelMessage) {
        return UpdateDataModelMessage(
          version: version,
          surfaceId: msg.surfaceId,
          path: msg.path,
          value: msg.value,
          hasValue: msg.hasValue,
        );
      }
      if (msg is DeleteSurfaceMessage) {
        return DeleteSurfaceMessage(
          version: version,
          surfaceId: msg.surfaceId,
        );
      }
      if (msg is CallRendererFunctionMessage) {
        return CallRendererFunctionMessage(
          version: version,
          surfaceId: msg.surfaceId,
          functionCallId: msg.functionCallId,
          callFunction: msg.callFunction,
        );
      }
      if (msg is AgentFunctionResponseMessage) {
        return AgentFunctionResponseMessage(
          version: version,
          response: msg.response,
        );
      }
    }
    return msg;
  }

  List<dynamic> _normalizeComponentList(List<dynamic> comps) {
    return comps.map((c) {
      if (c is! Map) {
        throw FormatException(
          'Expected component JSON object, got ${c.runtimeType}.',
        );
      }
      return _normalizeComponentMap(
        _toStringKeyedMap(c, context: 'component'),
      );
    }).toList();
  }

  Map<String, dynamic> _normalizeJson(Map<String, dynamic> json) {
    var normalized = json;
    if (normalized['version'] == 'v1.0') {
      normalized = {
        ...normalized,
        'version': A2uiProtocolVersion.v1_0.jsonValue,
      };
    }
    if (normalized.containsKey('updateComponents')) {
      final update = normalized['updateComponents'];
      if (update != null && update is! Map) {
        throw FormatException(
          'Expected JSON object for updateComponents, '
          'got ${update.runtimeType}.',
        );
      }
      if (update is Map) {
        final updateMap = _toStringKeyedMap(
          update,
          context: 'updateComponents',
        );
        if (updateMap.containsKey('components')) {
          final comps = updateMap['components'];
          if (comps != null && comps is! List) {
            throw FormatException(
              'Expected components list in updateComponents, '
              'got ${comps.runtimeType}.',
            );
          }
          if (comps is List) {
            return {
              ...normalized,
              'updateComponents': {
                ...updateMap,
                'components': _normalizeComponentList(comps),
              },
            };
          }
        }
      }
    }
    if (normalized.containsKey('createSurface')) {
      final create = normalized['createSurface'];
      if (create != null && create is! Map) {
        throw FormatException(
          'Expected JSON object for createSurface, got ${create.runtimeType}.',
        );
      }
      if (create is Map) {
        final createMap = _toStringKeyedMap(
          create,
          context: 'createSurface',
        );
        if (createMap.containsKey('components')) {
          final comps = createMap['components'];
          if (comps != null && comps is! List) {
            throw FormatException(
              'Expected components list in createSurface, '
              'got ${comps.runtimeType}.',
            );
          }
          if (comps is List) {
            return {
              ...normalized,
              'createSurface': {
                ...createMap,
                'components': _normalizeComponentList(comps),
              },
            };
          }
        }
      }
    }
    return normalized;
  }

  Map<String, dynamic> _normalizeComponentMap(Map<String, dynamic> comp) {
    var result = comp;
    if (comp.containsKey('properties')) {
      final rawProps = comp['properties'];
      if (rawProps != null && rawProps is! Map) {
        throw FormatException(
          'Expected JSON object for component properties, '
          'got ${rawProps.runtimeType}.',
        );
      }
      if (rawProps is Map) {
        final props = _toStringKeyedMap(
          rawProps,
          context: 'component properties',
        );
        final copy = Map<String, dynamic>.from(comp)..remove('properties');
        result = {...copy, ...props};
      }
    }
    if (result.containsKey('child')) {
      final child = result['child'];
      if (child is Map &&
          child.containsKey('id') &&
          !child.containsKey('path') &&
          !child.containsKey('@path')) {
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
      surface = _processor.model.getSurface(targetSurfaceId);
    }

    if (surface == null) {
      final fallbackId = _selectSurvivingSurfaceId();
      if (fallbackId != null) {
        surface = _processor.model.getSurface(fallbackId);
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

  /// Maximum permitted character length for a component `pattern` or
  /// `validationRegexp` string before it is rejected as potentially unsafe.
  ///
  /// ```dart
  /// const limit = A2uiSurfaceBloc.maxValidationPatternLength; // 256
  /// ```
  static const int maxValidationPatternLength = 256;

  /// Maximum permitted character length for a string form field value evaluated
  /// against a regular expression validation pattern.
  ///
  /// ```dart
  /// const limit = A2uiSurfaceBloc.maxValidationInputLength; // 2048
  /// ```
  static const int maxValidationInputLength = 2048;

  static const int _maxRegexCacheSize = 100;
  static const int _maxRegexCacheTotalChars = 16384;
  static final Map<String, RegExp?> _regexCache = <String, RegExp?>{};
  static int _regexCacheTotalChars = 0;

  /// Returns the current number of entries in the validation regular expression
  /// cache.
  @visibleForTesting
  static int get debugRegexCacheSize => _regexCache.length;

  /// Clears all cached validation regular expressions.
  @visibleForTesting
  static void clearRegexCache() {
    _regexCache.clear();
    _regexCacheTotalChars = 0;
  }

  static int? _quantifierEndIndex(String pattern, int index) {
    if (index >= pattern.length) return null;
    final code = pattern.codeUnitAt(index);
    // '*', '+', '?'
    if (code == 42 || code == 43 || code == 63) {
      var end = index + 1;
      if (end < pattern.length && pattern.codeUnitAt(end) == 63) {
        end++;
      }
      return end;
    }
    // '{n}', '{n,}', '{n,m}'
    if (code == 123) {
      var cursor = index + 1;
      final digitsStart = cursor;
      while (cursor < pattern.length &&
          pattern.codeUnitAt(cursor) >= 48 &&
          pattern.codeUnitAt(cursor) <= 57) {
        cursor++;
      }
      if (cursor == digitsStart) return null;
      if (cursor < pattern.length && pattern.codeUnitAt(cursor) == 44) {
        cursor++;
        while (cursor < pattern.length &&
            pattern.codeUnitAt(cursor) >= 48 &&
            pattern.codeUnitAt(cursor) <= 57) {
          cursor++;
        }
      }
      if (cursor < pattern.length && pattern.codeUnitAt(cursor) == 125) {
        var end = cursor + 1;
        if (end < pattern.length && pattern.codeUnitAt(end) == 63) {
          end++;
        }
        return end;
      }
    }
    return null;
  }

  static bool _hasOverlappingBranches(List<String> branches) {
    if (branches.length < 2) return false;
    final seenFirstChars = <int>{};
    for (final branch in branches) {
      if (branch.isEmpty) return true;
      final first = branch.codeUnitAt(0);
      // Wildcards, character classes, nested groups, or escapes can overlap.
      // 46='.', 91='[', 40='(', 92='\'
      if (first == 46 || first == 91 || first == 40 || first == 92) {
        return true;
      }
      if (!seenFirstChars.add(first)) {
        return true;
      }
    }
    return false;
  }

  /// Performs a linear-time $O(M)$ static check rejecting nested quantifiers
  /// and overlapping quantified alternations that can cause catastrophic
  /// backtracking (ReDoS).
  static bool _isSafeValidationPattern(String pattern) {
    final stack = <_RegexGroupFrame>[];
    var inCharClass = false;
    var escaped = false;
    var i = 0;

    while (i < pattern.length) {
      final code = pattern.codeUnitAt(i);
      if (escaped) {
        if (stack.isNotEmpty && !inCharClass) {
          stack.last.appendBranchChar(pattern[i]);
        }
        escaped = false;
        i++;
        continue;
      }
      if (code == 92) {
        // '\'
        if (stack.isNotEmpty && !inCharClass) {
          stack.last.appendBranchChar(r'\');
        }
        escaped = true;
        i++;
        continue;
      }
      if (inCharClass) {
        if (code == 93) {
          // ']'
          inCharClass = false;
        }
        i++;
        continue;
      }
      if (code == 91) {
        // '['
        inCharClass = true;
        if (stack.isNotEmpty) {
          stack.last.appendBranchChar('[');
        }
        i++;
        continue;
      }
      if (code == 40) {
        // '('
        if (stack.isNotEmpty) {
          stack.last.appendBranchChar('(');
        }
        stack.add(_RegexGroupFrame());
        i++;
        continue;
      }
      if (code == 41) {
        // ')'
        if (stack.isEmpty) {
          i++;
          continue;
        }
        final frame = stack.removeLast();
        final quantEnd = _quantifierEndIndex(pattern, i + 1);
        if (quantEnd != null) {
          if (frame.hasQuantifier ||
              (frame.branches.length > 1 &&
                  _hasOverlappingBranches(frame.branches))) {
            return false;
          }
          if (stack.isNotEmpty) {
            stack.last.hasQuantifier = true;
          }
          i = quantEnd;
          continue;
        }
        if (frame.hasQuantifier && stack.isNotEmpty) {
          stack.last.hasQuantifier = true;
        }
        i++;
        continue;
      }
      if (code == 124 && stack.isNotEmpty) {
        // '|'
        stack.last.startNewBranch();
        i++;
        continue;
      }

      final quantEnd = _quantifierEndIndex(pattern, i);
      if (quantEnd != null) {
        if (stack.isNotEmpty) {
          stack.last.hasQuantifier = true;
        }
        i = quantEnd;
        continue;
      }

      if (stack.isNotEmpty) {
        stack.last.appendBranchChar(pattern[i]);
      }
      i++;
    }
    return true;
  }

  static RegExp? _resolveValidationRegExp(
    String pattern, {
    bool Function(String pattern)? patternValidator,
  }) {
    if (pattern.length > maxValidationPatternLength) {
      return null;
    }
    if (patternValidator != null) {
      if (!patternValidator(pattern)) {
        return null;
      }
      try {
        return RegExp(pattern);
      } on FormatException {
        return null;
      }
    }
    if (_regexCache.containsKey(pattern)) {
      final cached = _regexCache.remove(pattern);
      _regexCache[pattern] = cached;
      return cached;
    }
    RegExp? compiled;
    if (_isSafeValidationPattern(pattern)) {
      try {
        compiled = RegExp(pattern);
      } on FormatException {
        compiled = null;
      }
    }
    while (_regexCache.isNotEmpty &&
        (_regexCache.length >= _maxRegexCacheSize ||
            _regexCacheTotalChars + pattern.length >
                _maxRegexCacheTotalChars)) {
      final oldestKey = _regexCache.keys.first;
      _regexCache.remove(oldestKey);
      _regexCacheTotalChars -= oldestKey.length;
    }
    _regexCache[pattern] = compiled;
    _regexCacheTotalChars += pattern.length;
    return compiled;
  }

  static int? _coerceInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
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
      if (valueProp is Map &&
          (valueProp.containsKey('path') || valueProp.containsKey('@path'))) {
        fieldPath = (valueProp['path'] ?? valueProp['@path'])?.toString();
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
        if (fieldValue.length > maxValidationInputLength) {
          errors.add(
            'Field "$label" must be at most '
            '$maxValidationInputLength characters.',
          );
        } else {
          final pattern = props['pattern']?.toString() ??
              props['validationRegexp']?.toString();
          if (pattern != null) {
            final regExp = _resolveValidationRegExp(
              pattern,
              patternValidator: patternValidator,
            );
            if (regExp != null && !regExp.hasMatch(fieldValue)) {
              errors.add('Field "$label" does not match the required pattern.');
            }
          }
        }
        final minLength = _coerceInt(props['minLength']);
        if (minLength != null && fieldValue.length < minLength) {
          errors.add('Field "$label" must be at least $minLength characters.');
        }
        final maxLength = _coerceInt(props['maxLength']);
        if (maxLength != null && fieldValue.length > maxLength) {
          errors.add('Field "$label" must be at most $maxLength characters.');
        }
      }
    }
    return errors;
  }

  Map<String, dynamic> _extractFormData(SurfaceModel<ComponentApi> surface) {
    final raw = surface.dataModel.get('/');
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  @override
  Future<void> close() async {
    _isClosing = true;
    _responseHistory.clear();
    _outboundMessageHistory.clear();
    final oldCompleter = _activeStreamCompleter;
    _activeStreamCompleter = null;
    if (oldCompleter != null && !oldCompleter.isCompleted) {
      oldCompleter.complete();
    }
    final oldSub = _activeStreamSubscription;
    _activeStreamSubscription = null;
    await _safeCancel(oldSub);
    _processor.rpc.dispose();
    await _actionResponsesController.close();
    await _outboundMessagesController.close();
    _processor.dispose();
    await super.close();
  }

  Future<void> _safeCancel(StreamSubscription<dynamic>? sub) async {
    if (sub == null) return;
    try {
      await sub.cancel();
    } on Exception catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }
}

class _RegexGroupFrame {
  bool hasQuantifier = false;
  final List<String> branches = <String>[''];

  void appendBranchChar(String ch) {
    if (branches.last.isEmpty) {
      branches[branches.length - 1] = ch;
    }
  }

  void startNewBranch() {
    branches.add('');
  }
}
