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
  /// underlying [MessageProcessor] and defaults to [ValidationConfig.relaxed].
  /// Pass `validationConfig: null` to disable graph-level validation.
  /// When [reportErrorsOnly] is `true`, [MessageProcessor.processMessages] emits
  /// mapped [ErrorMessage]s instead of throwing [A2uiError]s.
  /// When [unifiedOutbound] is `true`, outbound actions are also forwarded to
  /// [outboundMessages] as [ActionMessage] envelopes.
  /// [maxAgentCallCacheEntries] (defaults to `256`) bounds settled agent
  /// function call responses retained per surface.
  /// [maxChunkLength] (defaults to `1048576` characters, must be greater than
  /// `0`) bounds the maximum character length of a single incoming stream chunk.
  /// [maxMessagesPerBatch] (defaults to `256`, must be greater than `0`) bounds
  /// the maximum number of messages processed in a single batch or JSON array
  /// chunk.
  /// [maxComponentsPerSurface] (defaults to `2000`, must be greater than `0`)
  /// bounds the maximum number of components retained on a single surface.
  /// [patternValidator] optionally overrides the built-in ReDoS safety check
  /// for component validation `pattern` and `validationRegexp` strings.
  ///
  /// When [SubmitAction] or a `NodeAction`-bound UI button (bridged via
  /// [recordFunctionCallTelemetry]) targets a local `functionCall`, `call`, or
  /// `@call` action, this bloc emits an operational telemetry event named
  /// `'function_call_evaluated'` via [emitTelemetry] with `event` set to the
  /// [SubmitAction] (or `null` for `NodeAction` bridges) and `metadata`
  /// containing `surface_id`, `source_component_id`, optional `call` (from
  /// `call` or `@call`), `latency_ms`, `status` (`'ok'` or `'error'`), and
  /// `error_type` (on failure). Sensitive `args` payloads and raw error messages
  /// are omitted.
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
    this.validationConfig = ValidationConfig.relaxed,
    this.reportErrorsOnly = false,
    this.unifiedOutbound = false,
    this.maxAgentCallCacheEntries = 256,
    this.maxChunkLength = 1048576,
    this.maxMessagesPerBatch = 256,
    this.maxComponentsPerSurface = 2000,
    this.patternValidator,
  })  : assert(
          maxSurfaces == null || maxSurfaces > 0,
          'maxSurfaces must be null or greater than 0.',
        ),
        assert(
          maxResponseHistory >= 0,
          'maxResponseHistory must be greater than or equal to 0.',
        ),
        assert(
          maxChunkLength > 0,
          'maxChunkLength must be greater than 0.',
        ),
        assert(
          maxMessagesPerBatch > 0,
          'maxMessagesPerBatch must be greater than 0.',
        ),
        assert(
          maxComponentsPerSurface > 0,
          'maxComponentsPerSurface must be greater than 0.',
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
  ///
  /// Defaults to [ValidationConfig.relaxed]. Pass `null` to opt out.
  final ValidationConfig? validationConfig;

  /// Whether [MessageProcessor.processMessages] emits mapped [ErrorMessage]s
  /// instead of rethrowing [A2uiError]s.
  final bool reportErrorsOnly;

  /// Whether surface actions are also forwarded to [outboundMessages] as
  /// [ActionMessage] envelopes.
  final bool unifiedOutbound;

  /// Maximum number of settled agent function call responses cached per surface.
  final int maxAgentCallCacheEntries;

  /// Maximum character length permitted for a single raw string chunk in
  /// [IngestStream].
  ///
  /// Defaults to `1048576` (1 MiB of UTF-16 code units).
  final int maxChunkLength;

  /// Maximum number of messages permitted in a single [ProcessMessages] batch
  /// or decoded JSON array chunk.
  ///
  /// Defaults to `256`.
  final int maxMessagesPerBatch;

  /// Maximum number of components permitted on a single surface.
  ///
  /// Defaults to `2000`.
  final int maxComponentsPerSurface;

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

      _processor.rpc.cancelSurfaceCalls(victimId);
      _processor.model.deleteSurface(victimId);
      _pruneSurfaceMetadata(victimId);
    }
  }

  void _preProcessMessages(List<A2uiMessage> messages) {
    for (final msg in messages) {
      if (msg is CreateSurfaceMessage) {
        if (_processor.model.getSurface(msg.surfaceId) != null) {
          _processor.rpc.cancelSurfaceCalls(msg.surfaceId);
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
              _enforceIngestionBudgets(messages);
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
      _enforceIngestionBudgets([message]);
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
      _enforceIngestionBudgets([message]);
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
      if (event.messages.length > maxMessagesPerBatch) {
        throw FormatException(
          'Message batch length ${event.messages.length} exceeds '
          'maxMessagesPerBatch ($maxMessagesPerBatch).',
        );
      }
      final normalizedMessages = event.messages.map(_normalizeMessage).toList();
      _enforceIngestionBudgets(normalizedMessages);
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
          return _evaluateFunctionCall(dataContext, fc, event, surfaceId);
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
        if (!identical(_processor.model.getSurface(surfaceId), surface)) {
          return;
        }
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

  /// Records operational telemetry (`'function_call_evaluated'`) for a local
  /// `functionCall` action evaluated outside [SubmitAction] (for example,
  /// via a [NodeAction] closure in Flutter or Jaspr).
  ///
  /// Drops the telemetry event silently when this bloc is closing or closed.
  ///
  /// ```dart
  /// bloc.recordFunctionCallTelemetry(
  ///   surfaceId: 'surface_1',
  ///   sourceComponentId: 'btn_1',
  ///   callName: 'openUrl',
  ///   latencyMs: 4,
  ///   status: 'ok',
  /// );
  /// ```
  void recordFunctionCallTelemetry({
    required String surfaceId,
    required String sourceComponentId,
    required int latencyMs,
    required String status,
    String? callName,
    String? errorType,
  }) {
    _emitFunctionCallTelemetry(
      surfaceId: surfaceId,
      sourceComponentId: sourceComponentId,
      callName: callName,
      latencyMs: latencyMs,
      status: status,
      errorType: errorType,
    );
  }

  void _emitFunctionCallTelemetry({
    required String surfaceId,
    required String sourceComponentId,
    required int latencyMs,
    required String status,
    Object? callName,
    Object? event,
    String? errorType,
  }) {
    if (isClosed || _isClosing) return;
    emitTelemetry(
      'function_call_evaluated',
      event: event,
      metadata: <String, dynamic>{
        'surface_id': surfaceId,
        'source_component_id': sourceComponentId,
        if (callName is String && callName.isNotEmpty) 'call': callName,
        'latency_ms': latencyMs,
        'status': status,
        if (errorType != null && errorType.isNotEmpty) 'error_type': errorType,
      },
    );
  }

  Future<void> _evaluateFunctionCall(
    DataContext dataContext,
    Map<dynamic, dynamic> fc,
    SubmitAction event,
    String surfaceId,
  ) async {
    final stopwatch = Stopwatch()..start();
    final Object? callName = fc['call'] ?? fc['@call'];

    void emitOutcome({required String status, String? errorType}) {
      stopwatch.stop();
      _emitFunctionCallTelemetry(
        surfaceId: surfaceId,
        sourceComponentId: event.sourceComponentId,
        callName: callName,
        latencyMs: stopwatch.elapsedMilliseconds,
        status: status,
        event: event,
        errorType: errorType,
      );
    }

    try {
      await dataContext
          .withUserActivation()
          .evaluateFunctionCall(Map<String, dynamic>.from(fc));
    } on Object catch (error) {
      // SCAR-ERR-02: Justified exception: record failure telemetry before rethrowing.
      emitOutcome(
        status: 'error',
        errorType: error.runtimeType.toString(),
      );
      rethrow;
    }

    emitOutcome(status: 'ok');
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
        _processor.rpc.cancelSurfaceCalls(surface.id);
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

    _processor.rpc.cancelSurfaceCalls(targetId);
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

  void _enforceIngestionBudgets(List<A2uiMessage> messages) {
    final pendingComponentIds = <String, Set<String>>{};
    for (final msg in messages) {
      if (msg is CreateSurfaceMessage) {
        final comps = msg.components;
        if (comps == null) {
          pendingComponentIds[msg.surfaceId] = <String>{};
          continue;
        }
        final ids = <String>{};
        for (final comp in comps) {
          final id = comp['id']?.toString();
          if (id != null && id.isNotEmpty) {
            ids.add(id);
          }
        }
        pendingComponentIds[msg.surfaceId] = ids;
      } else if (msg is UpdateComponentsMessage) {
        final ids = pendingComponentIds.putIfAbsent(msg.surfaceId, () {
          final existingSurface = _processor.model.getSurface(msg.surfaceId);
          return existingSurface?.componentsModel.all
                  .map((c) => c.id)
                  .toSet() ??
              <String>{};
        });
        for (final comp in msg.components) {
          final id = comp['id']?.toString();
          if (id != null && id.isNotEmpty) {
            ids.add(id);
          }
        }
        if (ids.length > maxComponentsPerSurface) {
          throw FormatException(
            'Total component count ${ids.length} for surface '
            '"${msg.surfaceId}" exceeds maxComponentsPerSurface '
            '($maxComponentsPerSurface).',
          );
        }
      } else if (msg is DeleteSurfaceMessage) {
        pendingComponentIds[msg.surfaceId] = <String>{};
      }
    }
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
      if (chunk.length > maxChunkLength) {
        throw FormatException(
          'Chunk length ${chunk.length} exceeds maxChunkLength '
          '($maxChunkLength).',
        );
      }
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) return const [];
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        if (decoded.length > maxMessagesPerBatch) {
          throw FormatException(
            'Message batch length ${decoded.length} exceeds '
            'maxMessagesPerBatch ($maxMessagesPerBatch).',
          );
        }
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
      if (msg.components.length > maxComponentsPerSurface) {
        throw FormatException(
          'Component count ${msg.components.length} for surface '
          '"${msg.surfaceId}" exceeds maxComponentsPerSurface '
          '($maxComponentsPerSurface).',
        );
      }
      final normalizedComps =
          msg.components.map(_normalizeComponentMap).toList();
      return UpdateComponentsMessage(
        version: version,
        surfaceId: msg.surfaceId,
        components: normalizedComps,
      );
    }
    if (msg is CreateSurfaceMessage) {
      final comps = msg.components;
      if (comps != null && comps.length > maxComponentsPerSurface) {
        throw FormatException(
          'Component count ${comps.length} for surface '
          '"${msg.surfaceId}" exceeds maxComponentsPerSurface '
          '($maxComponentsPerSurface).',
        );
      }
      if (comps != null || version != msg.version) {
        final normalizedComps = comps?.map(_normalizeComponentMap).toList();
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
    if (comps.length > maxComponentsPerSurface) {
      throw FormatException(
        'Component count ${comps.length} exceeds maxComponentsPerSurface '
        '($maxComponentsPerSurface).',
      );
    }
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
        result = {...props, ...copy};
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

  static const int _ccDigit = 1 << 0;
  static const int _ccUpper = 1 << 1;
  static const int _ccLower = 1 << 2;
  static const int _ccUnderscore = 1 << 3;
  static const int _ccSpace = 1 << 4;
  static const int _ccPunct = 1 << 5;
  static const int _ccWord = _ccDigit | _ccUpper | _ccLower | _ccUnderscore;
  static const int _ccAll = _ccWord | _ccSpace | _ccPunct;

  static int _maskForCodeUnit(int code) {
    if (code >= 48 && code <= 57) return _ccDigit;
    if (code >= 65 && code <= 90) return _ccUpper;
    if (code >= 97 && code <= 122) return _ccLower;
    if (code == 95) return _ccUnderscore;
    if (code == 32 ||
        (code >= 9 && code <= 13) ||
        code == 0x00A0 ||
        code == 0x1680 ||
        (code >= 0x2000 && code <= 0x200A) ||
        code == 0x2028 ||
        code == 0x2029 ||
        code == 0x202F ||
        code == 0x205F ||
        code == 0x3000 ||
        code == 0xFEFF) {
      return _ccSpace;
    }
    return _ccPunct;
  }

  static int _maskForRange(int start, int end) {
    if (start > end) return _ccAll;
    var mask = 0;
    if (start <= 57 && end >= 48) mask |= _ccDigit;
    if (start <= 90 && end >= 65) mask |= _ccUpper;
    if (start <= 122 && end >= 97) mask |= _ccLower;
    if (start <= 95 && end >= 95) mask |= _ccUnderscore;
    if ((start <= 13 && end >= 9) ||
        (start <= 32 && end >= 32) ||
        (start <= 0x00A0 && end >= 0x00A0) ||
        (start <= 0x1680 && end >= 0x1680) ||
        (start <= 0x200A && end >= 0x2000) ||
        (start <= 0x2029 && end >= 0x2028) ||
        (start <= 0x202F && end >= 0x202F) ||
        (start <= 0x205F && end >= 0x205F) ||
        (start <= 0x3000 && end >= 0x3000) ||
        (start <= 0xFEFF && end >= 0xFEFF)) {
      mask |= _ccSpace;
    }
    if (start < 9 ||
        (start <= 31 && end >= 14) ||
        (start <= 47 && end >= 33) ||
        (start <= 64 && end >= 58) ||
        (start <= 94 && end >= 91) ||
        (start <= 96 && end >= 96) ||
        (start <= 126 && end >= 123) ||
        end > 126) {
      mask |= _ccPunct;
    }
    return mask;
  }

  static ({int end, bool isUnbounded, bool isNullable, int maxVal})?
      _quantifierInfo(
    String pattern,
    int index,
  ) {
    if (index >= pattern.length) return null;
    final code = pattern.codeUnitAt(index);
    // '*' (42), '+' (43), '?' (63)
    if (code == 42 || code == 43 || code == 63) {
      var end = index + 1;
      if (end < pattern.length && pattern.codeUnitAt(end) == 63) {
        end++;
      }
      return (
        end: end,
        isUnbounded: code == 42 || code == 43,
        isNullable: code == 42 || code == 63,
        maxVal: code == 63 ? 1 : 2,
      );
    }
    // '{n}', '{n,}', '{n,m}'
    if (code == 123) {
      var cursor = index + 1;
      final minStart = cursor;
      while (cursor < pattern.length &&
          pattern.codeUnitAt(cursor) >= 48 &&
          pattern.codeUnitAt(cursor) <= 57) {
        cursor++;
      }
      if (cursor == minStart) return null;
      const maxQuantifierSentinel = 1 << 30;
      final parsedMin = int.tryParse(pattern.substring(minStart, cursor));
      final minOverflow = parsedMin == null;
      final minVal = parsedMin ?? maxQuantifierSentinel;
      var hasComma = false;
      var hasMax = false;
      var maxOverflow = false;
      var maxVal = minVal;
      if (cursor < pattern.length && pattern.codeUnitAt(cursor) == 44) {
        hasComma = true;
        cursor++;
        final maxStart = cursor;
        while (cursor < pattern.length &&
            pattern.codeUnitAt(cursor) >= 48 &&
            pattern.codeUnitAt(cursor) <= 57) {
          cursor++;
        }
        if (cursor > maxStart) {
          hasMax = true;
          final parsedMax = int.tryParse(pattern.substring(maxStart, cursor));
          maxOverflow = parsedMax == null;
          maxVal = parsedMax ?? maxQuantifierSentinel;
        }
      }
      if (cursor < pattern.length && pattern.codeUnitAt(cursor) == 125) {
        var end = cursor + 1;
        if (end < pattern.length && pattern.codeUnitAt(end) == 63) {
          end++;
        }
        return (
          end: end,
          isUnbounded: minOverflow ||
              maxOverflow ||
              (hasComma && (!hasMax || maxVal > minVal)),
          isNullable: minVal == 0,
          maxVal: hasComma && !hasMax
              ? (minVal >= maxQuantifierSentinel - 2
                  ? maxQuantifierSentinel
                  : minVal + 2)
              : maxVal,
        );
      }
    }
    return null;
  }

  static ({int bodyStart, bool isLookaround}) _parseGroupHeader(
    String pattern,
    int openParenIndex,
  ) {
    if (openParenIndex + 1 >= pattern.length ||
        pattern.codeUnitAt(openParenIndex + 1) != 63) {
      return (bodyStart: openParenIndex + 1, isLookaround: false);
    }
    if (openParenIndex + 2 >= pattern.length) {
      return (bodyStart: openParenIndex + 1, isLookaround: false);
    }
    final next = pattern.codeUnitAt(openParenIndex + 2);
    // '(?:'
    if (next == 58) {
      return (bodyStart: openParenIndex + 3, isLookaround: false);
    }
    // '(?=' or '(?!'
    if (next == 61 || next == 33) {
      return (bodyStart: openParenIndex + 3, isLookaround: true);
    }
    if (next == 60 && openParenIndex + 3 < pattern.length) {
      final after = pattern.codeUnitAt(openParenIndex + 3);
      // '(?<=' or '(?<!'
      if (after == 61 || after == 33) {
        return (bodyStart: openParenIndex + 4, isLookaround: true);
      }
      // Named group '(?<name>'
      final gtIndex = pattern.indexOf('>', openParenIndex + 3);
      if (gtIndex != -1) {
        return (bodyStart: gtIndex + 1, isLookaround: false);
      }
    }
    return (bodyStart: openParenIndex + 1, isLookaround: false);
  }

  static ({int end, int mask, bool isZeroWidth, int? codeUnit})?
      _parseEscapeAtom(
    String pattern,
    int backslashIndex, {
    bool inCharClass = false,
  }) {
    if (backslashIndex + 1 >= pattern.length) return null;
    final next = pattern.codeUnitAt(backslashIndex + 1);
    // Reject numeric backreferences \1-\9 and named backreferences \k<...>
    if (next >= 49 && next <= 57) return null;
    if (next == 107 &&
        backslashIndex + 2 < pattern.length &&
        pattern.codeUnitAt(backslashIndex + 2) == 60) {
      return null;
    }
    // '\b', '\B'
    if (next == 98 || next == 66) {
      if (inCharClass) {
        return next == 98
            ? (
                end: backslashIndex + 2,
                mask: _ccPunct,
                isZeroWidth: false,
                codeUnit: 8,
              )
            : (
                end: backslashIndex + 2,
                mask: _ccUpper,
                isZeroWidth: false,
                codeUnit: 66,
              );
      }
      return (
        end: backslashIndex + 2,
        mask: 0,
        isZeroWidth: true,
        codeUnit: null,
      );
    }
    // Whitespace escapes \t (116->9), \n (110->10), \v (118->11),
    // \f (102->12), \r (114->13)
    if (next == 116) {
      return (
        end: backslashIndex + 2,
        mask: _ccSpace,
        isZeroWidth: false,
        codeUnit: 9,
      );
    }
    if (next == 110) {
      return (
        end: backslashIndex + 2,
        mask: _ccSpace,
        isZeroWidth: false,
        codeUnit: 10,
      );
    }
    if (next == 118) {
      return (
        end: backslashIndex + 2,
        mask: _ccSpace,
        isZeroWidth: false,
        codeUnit: 11,
      );
    }
    if (next == 102) {
      return (
        end: backslashIndex + 2,
        mask: _ccSpace,
        isZeroWidth: false,
        codeUnit: 12,
      );
    }
    if (next == 114) {
      return (
        end: backslashIndex + 2,
        mask: _ccSpace,
        isZeroWidth: false,
        codeUnit: 13,
      );
    }
    // Null byte / legacy octal escape \0 or \0[0-7]{1,2}
    if (next == 48) {
      var cursor = backslashIndex + 2;
      var octalVal = 0;
      var digits = 0;
      while (cursor < pattern.length && digits < 2) {
        final d = pattern.codeUnitAt(cursor);
        if (d < 48 || d > 55) break;
        octalVal = (octalVal << 3) | (d - 48);
        cursor++;
        digits++;
      }
      return (
        end: cursor,
        mask: _maskForCodeUnit(octalVal),
        isZeroWidth: false,
        codeUnit: octalVal,
      );
    }
    // Control escape \c[A-Za-z] (and Annex B \c[0-9_] inside char classes)
    if (next == 99) {
      if (backslashIndex + 2 < pattern.length) {
        final ctrl = pattern.codeUnitAt(backslashIndex + 2);
        if ((ctrl >= 65 && ctrl <= 90) ||
            (ctrl >= 97 && ctrl <= 122) ||
            (inCharClass && ((ctrl >= 48 && ctrl <= 57) || ctrl == 95))) {
          final codeUnit = ctrl & 0x1F;
          return (
            end: backslashIndex + 3,
            mask: _maskForCodeUnit(codeUnit),
            isZeroWidth: false,
            codeUnit: codeUnit,
          );
        }
      }
      return (
        end: backslashIndex + 1,
        mask: _ccPunct,
        isZeroWidth: false,
        codeUnit: 92,
      );
    }
    // \d, \D, \w, \W, \s, \S
    if (next == 100) {
      return (
        end: backslashIndex + 2,
        mask: _ccDigit,
        isZeroWidth: false,
        codeUnit: null,
      );
    }
    if (next == 68) {
      return (
        end: backslashIndex + 2,
        mask: _ccAll & ~_ccDigit,
        isZeroWidth: false,
        codeUnit: null,
      );
    }
    if (next == 119) {
      return (
        end: backslashIndex + 2,
        mask: _ccWord,
        isZeroWidth: false,
        codeUnit: null,
      );
    }
    if (next == 87) {
      return (
        end: backslashIndex + 2,
        mask: _ccAll & ~_ccWord,
        isZeroWidth: false,
        codeUnit: null,
      );
    }
    if (next == 115) {
      return (
        end: backslashIndex + 2,
        mask: _ccSpace,
        isZeroWidth: false,
        codeUnit: null,
      );
    }
    if (next == 83) {
      return (
        end: backslashIndex + 2,
        mask: _ccAll & ~_ccSpace,
        isZeroWidth: false,
        codeUnit: null,
      );
    }
    // \xHH
    if (next == 120) {
      final hex = _parseExactHex(pattern, backslashIndex + 2, 2);
      if (hex != null) {
        return (
          end: backslashIndex + 4,
          mask: _maskForCodeUnit(hex),
          isZeroWidth: false,
          codeUnit: hex,
        );
      }
    }
    // \uHHHH (4-digit Unicode escape; in non-unicode RegExp, \u{...}, \p{...},
    // and \P{...} are IdentityEscapes for 'u', 'p', 'P' followed by '{...}').
    if (next == 117) {
      final hex = _parseExactHex(pattern, backslashIndex + 2, 4);
      if (hex != null) {
        return (
          end: backslashIndex + 6,
          mask: _maskForCodeUnit(hex),
          isZeroWidth: false,
          codeUnit: hex,
        );
      }
    }
    return (
      end: backslashIndex + 2,
      mask: _maskForCodeUnit(next),
      isZeroWidth: false,
      codeUnit: next,
    );
  }

  static int? _parseExactHex(String pattern, int start, int length) {
    if (start + length > pattern.length) return null;
    var value = 0;
    for (var i = 0; i < length; i++) {
      final c = pattern.codeUnitAt(start + i);
      int digit;
      if (c >= 48 && c <= 57) {
        digit = c - 48;
      } else if (c >= 65 && c <= 70) {
        digit = c - 55;
      } else if (c >= 97 && c <= 102) {
        digit = c - 87;
      } else {
        return null;
      }
      value = (value << 4) | digit;
    }
    return value;
  }

  static ({int end, int mask, Set<int>? punctChars}) _parseCharClass(
    String pattern,
    int openIndex,
  ) {
    var cursor = openIndex + 1;
    var negated = false;
    if (cursor < pattern.length && pattern.codeUnitAt(cursor) == 94) {
      negated = true;
      cursor++;
    }
    var mask = 0;
    Set<int>? punctChars = <int>{};
    var prevCode = -1;
    while (cursor < pattern.length) {
      final c = pattern.codeUnitAt(cursor);
      if (c == 93) {
        cursor++;
        break;
      }
      if (c == 92) {
        final esc = _parseEscapeAtom(pattern, cursor, inCharClass: true);
        if (esc != null) {
          mask |= esc.mask;
          if ((esc.mask & _ccPunct) != 0) {
            if (esc.codeUnit != null) {
              punctChars?.add(esc.codeUnit!);
            } else {
              punctChars = null;
            }
          }
          cursor = esc.end;
          prevCode = esc.codeUnit ?? -1;
          continue;
        }
        mask |= _ccAll;
        punctChars = null;
        cursor++;
        prevCode = -1;
        continue;
      }
      if (c == 45 &&
          prevCode != -1 &&
          cursor + 1 < pattern.length &&
          pattern.codeUnitAt(cursor + 1) != 93) {
        final nextChar = pattern.codeUnitAt(cursor + 1);
        if (nextChar == 92) {
          final esc = _parseEscapeAtom(pattern, cursor + 1, inCharClass: true);
          if (esc != null) {
            if (esc.codeUnit != null) {
              final rangeMask = _maskForRange(prevCode, esc.codeUnit!);
              mask |= rangeMask;
              if ((rangeMask & _ccPunct) != 0) punctChars = null;
            } else {
              mask |= _ccPunct | esc.mask;
              if ((esc.mask & _ccPunct) != 0) {
                punctChars = null;
              } else {
                punctChars?.add(45);
              }
            }
            cursor = esc.end;
          } else {
            mask |= _ccAll;
            punctChars = null;
            cursor += 2;
          }
        } else {
          final rangeMask = _maskForRange(prevCode, nextChar);
          mask |= rangeMask;
          if ((rangeMask & _ccPunct) != 0) punctChars = null;
          cursor += 2;
        }
        prevCode = -1;
        continue;
      }
      final charMask = _maskForCodeUnit(c);
      mask |= charMask;
      if ((charMask & _ccPunct) != 0) {
        punctChars?.add(c);
      }
      prevCode = c;
      cursor++;
    }
    return (
      end: cursor,
      mask: negated || mask == 0 ? _ccAll : mask,
      punctChars: negated || mask == 0 ? null : punctChars,
    );
  }

  static bool _hasOverlappingBranches(List<_BranchFirstMatch> branches) {
    if (branches.length < 2) return false;
    for (var i = 0; i < branches.length; i++) {
      final a = branches[i];
      if (a.mask == 0) return true;
      for (var j = i + 1; j < branches.length; j++) {
        final b = branches[j];
        if (b.mask == 0) return true;
        if (!a.hasNonLiteral && !b.hasNonLiteral) {
          if (a.exactCodeUnits.any(b.exactCodeUnits.contains)) {
            return true;
          }
        } else if (_masksOverlap(a.mask, a.punctChars, b.mask, b.punctChars)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _masksOverlap(
    int maskA,
    Set<int>? punctA,
    int maskB,
    Set<int>? punctB,
  ) {
    final common = maskA & maskB;
    if (common == 0) return false;
    if (common != _ccPunct) return true;
    if (punctA == null || punctB == null) return true;
    return punctA.any(punctB.contains);
  }

  static Set<int>? _unionPunctChars(
    int maskA,
    Set<int>? punctA,
    int maskB,
    Set<int>? punctB,
  ) {
    if ((maskA & _ccPunct) == 0) return punctB;
    if ((maskB & _ccPunct) == 0) return punctA;
    if (punctA == null || punctB == null) return null;
    return <int>{...punctA, ...punctB};
  }

  /// Performs a linear-time $O(M)$ static check rejecting nested quantifiers,
  /// overlapping quantified alternations, backreferences, quantifiers inside
  /// or on lookarounds, and overlapping adjacent unbounded quantifiers (even
  /// across unquantified/nullable groups, overlapping separators, `?`-chains,
  /// or zero-width assertions).
  static bool _isSafeValidationPattern(String pattern) {
    final stack = <_RegexGroupFrame>[_RegexGroupFrame()];
    var lookaroundDepth = 0;
    var i = 0;

    bool applyQuantifierOrAtom({
      required int atomMask,
      required Set<int>? atomPunctChars,
      required int leadingMask,
      required Set<int>? leadingPunctChars,
      required int trailingMask,
      required Set<int>? trailingPunctChars,
      required bool atomCanBeEmpty,
      required bool isZeroWidth,
      required ({
        int end,
        bool isUnbounded,
        bool isNullable,
        int maxVal
      })? quant,
      required int nextIndex,
      int groupTrailingNullableMask = 0,
      Set<int>? groupTrailingNullablePunctChars,
      int groupTrailingNullableChain = 0,
    }) {
      final scope = stack.last;
      if (quant != null) {
        if (lookaroundDepth > 0) return false;
        if (stack.length > 1) {
          scope.hasQuantifier = true;
        }
        final effectiveLeading = leadingMask | atomMask;
        final effectiveLeadingPunct = _unionPunctChars(
          leadingMask,
          leadingPunctChars,
          atomMask,
          atomPunctChars,
        );
        final effectiveTrailing = trailingMask | atomMask;
        final effectiveTrailingPunct = _unionPunctChars(
          trailingMask,
          trailingPunctChars,
          atomMask,
          atomPunctChars,
        );

        if (quant.isUnbounded) {
          if (_masksOverlap(
            scope.trailingUnboundedMask,
            scope.trailingUnboundedPunctChars,
            effectiveLeading,
            effectiveLeadingPunct,
          )) {
            if (scope.trailingUnboundedAbsorbed == 0) {
              return false;
            }
            scope.trailingUnboundedOverlapChain++;
            if (scope.trailingUnboundedOverlapChain >= 2) {
              return false;
            }
          }
          scope.trailingUnboundedAbsorbed = 0;
          if (scope.branchCanBeEmpty) {
            scope.leadingUnboundedPunctChars = _unionPunctChars(
              scope.leadingUnboundedMask,
              scope.leadingUnboundedPunctChars,
              effectiveLeading,
              effectiveLeadingPunct,
            );
            scope.leadingUnboundedMask |= effectiveLeading;
          }
          if (scope.trailingNullableChain >= 1 &&
              _masksOverlap(
                scope.trailingNullableMask,
                scope.trailingNullablePunctChars,
                effectiveLeading,
                effectiveLeadingPunct,
              )) {
            scope.nullableAmbiguityCount++;
            if (scope.nullableAmbiguityCount >= 3) {
              return false;
            }
          }
          if (quant.isNullable || atomCanBeEmpty) {
            scope.trailingUnboundedPunctChars = _unionPunctChars(
              scope.trailingUnboundedMask,
              scope.trailingUnboundedPunctChars,
              effectiveTrailing,
              effectiveTrailingPunct,
            );
            scope.trailingUnboundedMask |= effectiveTrailing;
          } else {
            scope.trailingUnboundedMask = effectiveTrailing;
            scope.trailingUnboundedPunctChars = effectiveTrailingPunct;
            scope.branchCanBeEmpty = false;
            scope.trailingNullableChain = 0;
            scope.trailingNullableMask = 0;
            scope.trailingNullablePunctChars = <int>{};
          }
        } else if (quant.isNullable || atomCanBeEmpty) {
          final stepCount = quant.maxVal > 1 ? quant.maxVal : 1;
          if (_masksOverlap(
            scope.trailingNullableMask,
            scope.trailingNullablePunctChars,
            effectiveLeading,
            effectiveLeadingPunct,
          )) {
            scope.trailingNullableChain += stepCount;
            if (scope.trailingNullableChain >= 2) {
              scope.nullableAmbiguityCount++;
              if (scope.nullableAmbiguityCount >= 3) {
                return false;
              }
            }
          } else if (scope.trailingNullableChain == 0) {
            scope.trailingNullableChain = stepCount;
          }
          if (groupTrailingNullableChain > scope.trailingNullableChain) {
            scope.trailingNullableChain = groupTrailingNullableChain;
          }
          if (scope.trailingNullableChain >= 3) {
            return false;
          }
          final nullableBaseMask = effectiveLeading | effectiveTrailing;
          final nullableBasePunct = _unionPunctChars(
            effectiveLeading,
            effectiveLeadingPunct,
            effectiveTrailing,
            effectiveTrailingPunct,
          );
          final nullableUnionMask =
              nullableBaseMask | groupTrailingNullableMask;
          final nullableUnionPunct = _unionPunctChars(
            nullableBaseMask,
            nullableBasePunct,
            groupTrailingNullableMask,
            groupTrailingNullablePunctChars,
          );
          scope.trailingNullablePunctChars = _unionPunctChars(
            scope.trailingNullableMask,
            scope.trailingNullablePunctChars,
            nullableUnionMask,
            nullableUnionPunct,
          );
          scope.trailingNullableMask |= nullableUnionMask;

          if (_masksOverlap(
            scope.trailingUnboundedMask,
            scope.trailingUnboundedPunctChars,
            effectiveLeading,
            effectiveLeadingPunct,
          )) {
            scope.nullableAmbiguityCount++;
            if (scope.nullableAmbiguityCount >= 3) {
              return false;
            }
            if (trailingMask != 0) {
              if (leadingMask != 0 || scope.trailingUnboundedAbsorbed == 0) {
                return false;
              }
              scope.trailingUnboundedOverlapChain++;
              if (scope.trailingUnboundedOverlapChain >= 2) {
                return false;
              }
              scope.trailingUnboundedAbsorbed = 0;
            }
            scope.trailingUnboundedPunctChars = _unionPunctChars(
              scope.trailingUnboundedMask,
              scope.trailingUnboundedPunctChars,
              effectiveTrailing,
              effectiveTrailingPunct,
            );
            scope.trailingUnboundedMask |= effectiveTrailing;
            if (scope.trailingNullableChain >= 2) {
              return false;
            }
          } else if (trailingMask != 0) {
            scope.trailingUnboundedPunctChars = _unionPunctChars(
              scope.trailingUnboundedMask,
              scope.trailingUnboundedPunctChars,
              trailingMask,
              trailingPunctChars,
            );
            scope.trailingUnboundedMask |= trailingMask;
            scope.trailingUnboundedAbsorbed = 0;
          }
          if (scope.branchCanBeEmpty && leadingMask != 0) {
            scope.leadingUnboundedPunctChars = _unionPunctChars(
              scope.leadingUnboundedMask,
              scope.leadingUnboundedPunctChars,
              leadingMask,
              leadingPunctChars,
            );
            scope.leadingUnboundedMask |= leadingMask;
          }
        } else {
          if (leadingMask != 0 &&
              _masksOverlap(
                scope.trailingUnboundedMask,
                scope.trailingUnboundedPunctChars,
                leadingMask,
                leadingPunctChars,
              )) {
            return false;
          }
          if (scope.branchCanBeEmpty && leadingMask != 0) {
            scope.leadingUnboundedPunctChars = _unionPunctChars(
              scope.leadingUnboundedMask,
              scope.leadingUnboundedPunctChars,
              leadingMask,
              leadingPunctChars,
            );
            scope.leadingUnboundedMask |= leadingMask;
          }
          if (scope.trailingNullableChain >= 1 &&
              _masksOverlap(
                scope.trailingNullableMask,
                scope.trailingNullablePunctChars,
                effectiveLeading,
                effectiveLeadingPunct,
              )) {
            scope.nullableAmbiguityCount++;
            if (scope.nullableAmbiguityCount >= 3) {
              return false;
            }
          }
          if (groupTrailingNullableChain > 0) {
            scope.trailingNullableChain = groupTrailingNullableChain;
            scope.trailingNullableMask = groupTrailingNullableMask;
            scope.trailingNullablePunctChars =
                groupTrailingNullablePunctChars ?? <int>{};
          } else {
            scope.trailingNullableChain = 0;
            scope.trailingNullableMask = 0;
            scope.trailingNullablePunctChars = <int>{};
          }
          if (_masksOverlap(
            scope.trailingUnboundedMask,
            scope.trailingUnboundedPunctChars,
            effectiveLeading,
            effectiveLeadingPunct,
          )) {
            scope.nullableAmbiguityCount++;
            if (scope.nullableAmbiguityCount >= 3) {
              return false;
            }
            if (trailingMask != 0) {
              if (scope.trailingUnboundedAbsorbed == 0) {
                return false;
              }
              scope.trailingUnboundedOverlapChain++;
              if (scope.trailingUnboundedOverlapChain >= 2) {
                return false;
              }
              scope.trailingUnboundedAbsorbed = 0;
              scope.trailingUnboundedPunctChars = _unionPunctChars(
                scope.trailingUnboundedMask,
                scope.trailingUnboundedPunctChars,
                trailingMask,
                trailingPunctChars,
              );
              scope.trailingUnboundedMask |= trailingMask;
            } else {
              scope.trailingUnboundedAbsorbed++;
            }
          } else {
            scope.trailingUnboundedMask = trailingMask;
            scope.trailingUnboundedPunctChars = trailingPunctChars;
            scope.trailingUnboundedAbsorbed = 0;
          }
          scope.branchCanBeEmpty = false;
        }
        i = quant.end;
        return true;
      }

      if (isZeroWidth) {
        i = nextIndex;
        return true;
      }

      // Unquantified atom/group
      final effLeading = leadingMask | atomMask;
      final effLeadingPunct = _unionPunctChars(
        leadingMask,
        leadingPunctChars,
        atomMask,
        atomPunctChars,
      );
      final effTrailing = trailingMask | atomMask;
      final effTrailingPunct = _unionPunctChars(
        trailingMask,
        trailingPunctChars,
        atomMask,
        atomPunctChars,
      );
      if (atomCanBeEmpty) {
        if (_masksOverlap(
          scope.trailingNullableMask,
          scope.trailingNullablePunctChars,
          effLeading,
          effLeadingPunct,
        )) {
          scope.trailingNullableChain++;
          if (scope.trailingNullableChain >= 2) {
            scope.nullableAmbiguityCount++;
            if (scope.nullableAmbiguityCount >= 3) {
              return false;
            }
          }
        } else if (scope.trailingNullableChain == 0) {
          scope.trailingNullableChain = 1;
        }
        if (groupTrailingNullableChain > scope.trailingNullableChain) {
          scope.trailingNullableChain = groupTrailingNullableChain;
        }
        if (scope.trailingNullableChain >= 3) {
          return false;
        }
        final nullableBaseMask = effLeading | effTrailing;
        final nullableBasePunct = _unionPunctChars(
          effLeading,
          effLeadingPunct,
          effTrailing,
          effTrailingPunct,
        );
        final nullableUnionMask = nullableBaseMask | groupTrailingNullableMask;
        final nullableUnionPunct = _unionPunctChars(
          nullableBaseMask,
          nullableBasePunct,
          groupTrailingNullableMask,
          groupTrailingNullablePunctChars,
        );
        scope.trailingNullablePunctChars = _unionPunctChars(
          scope.trailingNullableMask,
          scope.trailingNullablePunctChars,
          nullableUnionMask,
          nullableUnionPunct,
        );
        scope.trailingNullableMask |= nullableUnionMask;
        if (_masksOverlap(
          scope.trailingUnboundedMask,
          scope.trailingUnboundedPunctChars,
          effLeading,
          effLeadingPunct,
        )) {
          scope.nullableAmbiguityCount++;
          if (scope.nullableAmbiguityCount >= 3) {
            return false;
          }
          if (leadingMask != 0 || scope.trailingNullableChain >= 2) {
            return false;
          }
        }
        scope.trailingUnboundedPunctChars = _unionPunctChars(
          scope.trailingUnboundedMask,
          scope.trailingUnboundedPunctChars,
          trailingMask,
          trailingPunctChars,
        );
        scope.trailingUnboundedMask |= trailingMask;
        if (scope.branchCanBeEmpty && leadingMask != 0) {
          scope.leadingUnboundedPunctChars = _unionPunctChars(
            scope.leadingUnboundedMask,
            scope.leadingUnboundedPunctChars,
            leadingMask,
            leadingPunctChars,
          );
          scope.leadingUnboundedMask |= leadingMask;
        }
      } else {
        if (leadingMask != 0 &&
            _masksOverlap(
              scope.trailingUnboundedMask,
              scope.trailingUnboundedPunctChars,
              leadingMask,
              leadingPunctChars,
            )) {
          return false;
        }
        if (scope.branchCanBeEmpty && leadingMask != 0) {
          scope.leadingUnboundedPunctChars = _unionPunctChars(
            scope.leadingUnboundedMask,
            scope.leadingUnboundedPunctChars,
            leadingMask,
            leadingPunctChars,
          );
          scope.leadingUnboundedMask |= leadingMask;
        }
        if (scope.trailingNullableChain >= 1 &&
            _masksOverlap(
              scope.trailingNullableMask,
              scope.trailingNullablePunctChars,
              effLeading,
              effLeadingPunct,
            )) {
          scope.nullableAmbiguityCount++;
          if (scope.nullableAmbiguityCount >= 3) {
            return false;
          }
        }
        if (groupTrailingNullableChain > 0) {
          scope.trailingNullableChain = groupTrailingNullableChain;
          scope.trailingNullableMask = groupTrailingNullableMask;
          scope.trailingNullablePunctChars =
              groupTrailingNullablePunctChars ?? <int>{};
        } else {
          scope.trailingNullableChain = 0;
          scope.trailingNullableMask = 0;
          scope.trailingNullablePunctChars = <int>{};
        }
        if (_masksOverlap(
          scope.trailingUnboundedMask,
          scope.trailingUnboundedPunctChars,
          effLeading,
          effLeadingPunct,
        )) {
          if (trailingMask != 0) return false;
          scope.trailingUnboundedAbsorbed++;
        } else {
          scope.trailingUnboundedMask = trailingMask;
          scope.trailingUnboundedPunctChars = trailingPunctChars;
          scope.trailingUnboundedAbsorbed = 0;
        }
        scope.branchCanBeEmpty = false;
      }
      i = nextIndex;
      return true;
    }

    while (i < pattern.length) {
      final code = pattern.codeUnitAt(i);
      if (code == 92) {
        // '\' escape, backreference, or zero-width assertion
        final esc = _parseEscapeAtom(pattern, i);
        if (esc == null) return false;
        final escPunct = !esc.isZeroWidth && (esc.mask & _ccPunct) != 0
            ? (esc.codeUnit != null ? <int>{esc.codeUnit!} : null)
            : <int>{};
        final wasBranchEmpty = stack.length > 1 && stack.last.branchCanBeEmpty;
        final quant = _quantifierInfo(pattern, esc.end);
        if (!applyQuantifierOrAtom(
          atomMask: esc.mask,
          atomPunctChars: escPunct,
          leadingMask: 0,
          leadingPunctChars: <int>{},
          trailingMask: 0,
          trailingPunctChars: <int>{},
          atomCanBeEmpty: esc.isZeroWidth,
          isZeroWidth: esc.isZeroWidth,
          quant: quant,
          nextIndex: esc.end,
        )) {
          return false;
        }
        if (!esc.isZeroWidth && stack.length > 1) {
          stack.last.recordAtom(
            esc.mask,
            escPunct,
            wasBranchEmpty: wasBranchEmpty,
            codeUnit: esc.codeUnit,
          );
        }
        continue;
      }
      if (code == 91) {
        // '[' character class
        final cc = _parseCharClass(pattern, i);
        final wasBranchEmpty = stack.length > 1 && stack.last.branchCanBeEmpty;
        final quant = _quantifierInfo(pattern, cc.end);
        if (!applyQuantifierOrAtom(
          atomMask: cc.mask,
          atomPunctChars: cc.punctChars,
          leadingMask: 0,
          leadingPunctChars: <int>{},
          trailingMask: 0,
          trailingPunctChars: <int>{},
          atomCanBeEmpty: false,
          isZeroWidth: false,
          quant: quant,
          nextIndex: cc.end,
        )) {
          return false;
        }
        if (stack.length > 1) {
          stack.last.recordAtom(
            cc.mask,
            cc.punctChars,
            wasBranchEmpty: wasBranchEmpty,
          );
        }
        continue;
      }
      if (code == 40) {
        // '(' group open
        final header = _parseGroupHeader(pattern, i);
        if (header.isLookaround) lookaroundDepth++;
        stack.add(_RegexGroupFrame(isLookaround: header.isLookaround));
        i = header.bodyStart;
        continue;
      }
      if (code == 41) {
        // ')' group close
        if (stack.length <= 1) {
          i++;
          continue;
        }
        final frame = stack.removeLast();
        frame.finishBranch();
        var groupAmbCount = frame.groupMaxAmbiguousAlternationCount;
        if (frame.branches.length > 1 &&
            _hasOverlappingBranches(frame.branches)) {
          frame.hasAmbiguousAlternation = true;
          groupAmbCount++;
        }
        stack.last.ambiguousAlternationCount += groupAmbCount;
        if (stack.last.ambiguousAlternationCount >= 3) {
          return false;
        }
        stack.last.nullableAmbiguityCount +=
            frame.groupMaxNullableAmbiguityCount;
        if (stack.last.nullableAmbiguityCount >= 3) {
          return false;
        }
        stack.last.trailingUnboundedOverlapChain +=
            frame.groupMaxUnboundedOverlapChain;
        if (stack.last.trailingUnboundedOverlapChain >= 2) {
          return false;
        }
        if (frame.isLookaround) lookaroundDepth--;
        final wasBranchEmpty = stack.length > 1 && stack.last.branchCanBeEmpty;
        final quant = _quantifierInfo(pattern, i + 1);
        if (quant != null) {
          if (lookaroundDepth > 0 || frame.isLookaround) return false;
          if ((quant.isUnbounded || quant.maxVal > 1) &&
              (frame.hasQuantifier || frame.hasAmbiguousAlternation)) {
            return false;
          }
          if (!applyQuantifierOrAtom(
            atomMask: quant.isUnbounded
                ? frame.allCharsMask
                : frame.groupFirstAtomMask,
            atomPunctChars: quant.isUnbounded
                ? frame.allCharsPunctChars
                : frame.groupFirstAtomPunctChars,
            leadingMask: frame.groupLeadingUnboundedMask,
            leadingPunctChars: frame.groupLeadingUnboundedPunctChars,
            trailingMask: frame.groupTrailingUnboundedMask,
            trailingPunctChars: frame.groupTrailingUnboundedPunctChars,
            atomCanBeEmpty: frame.groupCanBeEmpty || quant.isNullable,
            isZeroWidth: false,
            quant: quant,
            nextIndex: i + 1,
            groupTrailingNullableMask: frame.groupTrailingNullableMask,
            groupTrailingNullablePunctChars:
                frame.groupTrailingNullablePunctChars,
            groupTrailingNullableChain: frame.groupMaxTrailingNullableChain,
          )) {
            return false;
          }
          if (stack.length > 1) {
            stack.last.recordAtom(
              frame.allCharsMask,
              frame.allCharsPunctChars,
              wasBranchEmpty: wasBranchEmpty,
            );
          }
          continue;
        }
        if (stack.length > 1) {
          if (frame.hasQuantifier) {
            stack.last.hasQuantifier = true;
          }
          if (frame.hasAmbiguousAlternation) {
            stack.last.hasAmbiguousAlternation = true;
          }
        }
        if (!applyQuantifierOrAtom(
          atomMask: frame.groupFirstAtomMask,
          atomPunctChars: frame.groupFirstAtomPunctChars,
          leadingMask: frame.groupLeadingUnboundedMask,
          leadingPunctChars: frame.groupLeadingUnboundedPunctChars,
          trailingMask: frame.groupTrailingUnboundedMask,
          trailingPunctChars: frame.groupTrailingUnboundedPunctChars,
          atomCanBeEmpty: frame.groupCanBeEmpty,
          isZeroWidth: frame.isLookaround,
          quant: null,
          nextIndex: i + 1,
          groupTrailingNullableMask: frame.groupTrailingNullableMask,
          groupTrailingNullablePunctChars:
              frame.groupTrailingNullablePunctChars,
          groupTrailingNullableChain: frame.groupMaxTrailingNullableChain,
        )) {
          return false;
        }
        if (!frame.isLookaround && stack.length > 1) {
          stack.last.recordAtom(
            frame.allCharsMask,
            frame.allCharsPunctChars,
            wasBranchEmpty: wasBranchEmpty,
          );
        }
        continue;
      }
      if (code == 124) {
        // '|' alternation
        stack.last.startNewBranch();
        i++;
        continue;
      }

      // Stray quantifier at start of group/pattern
      final strayQuant = _quantifierInfo(pattern, i);
      if (strayQuant != null) {
        if (lookaroundDepth > 0) return false;
        if (stack.length > 1) {
          stack.last.hasQuantifier = true;
        }
        i = strayQuant.end;
        continue;
      }

      final isAnchor = code == 94 || code == 36; // '^' or '$'
      final atomMask =
          isAnchor ? 0 : (code == 46 ? _ccAll : _maskForCodeUnit(code));
      final atomPunct = !isAnchor && (atomMask & _ccPunct) != 0
          ? (code == 46 ? null : <int>{code})
          : <int>{};
      final wasBranchEmpty = stack.length > 1 && stack.last.branchCanBeEmpty;
      final quant = _quantifierInfo(pattern, i + 1);
      if (!applyQuantifierOrAtom(
        atomMask: atomMask,
        atomPunctChars: atomPunct,
        leadingMask: 0,
        leadingPunctChars: <int>{},
        trailingMask: 0,
        trailingPunctChars: <int>{},
        atomCanBeEmpty: isAnchor,
        isZeroWidth: isAnchor,
        quant: quant,
        nextIndex: i + 1,
      )) {
        return false;
      }
      if (!isAnchor && stack.length > 1) {
        stack.last.recordAtom(
          atomMask,
          atomPunct,
          wasBranchEmpty: wasBranchEmpty,
          codeUnit: code == 46 ? null : code,
        );
      }
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
    if (value is num) return value.isFinite ? value.toInt() : null;
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
  _RegexGroupFrame({this.isLookaround = false});

  final bool isLookaround;
  bool hasQuantifier = false;
  bool hasAmbiguousAlternation = false;
  int ambiguousAlternationCount = 0;
  int groupMaxAmbiguousAlternationCount = 0;
  int nullableAmbiguityCount = 0;
  int groupMaxNullableAmbiguityCount = 0;
  int groupMaxUnboundedOverlapChain = 0;
  int leadingUnboundedMask = 0;
  Set<int>? leadingUnboundedPunctChars = <int>{};
  int trailingUnboundedMask = 0;
  Set<int>? trailingUnboundedPunctChars = <int>{};
  int trailingUnboundedAbsorbed = 0;
  int trailingUnboundedOverlapChain = 0;
  int trailingNullableMask = 0;
  Set<int>? trailingNullablePunctChars = <int>{};
  int trailingNullableChain = 0;
  bool branchCanBeEmpty = true;
  int firstAtomMask = 0;
  Set<int>? firstAtomPunctChars = <int>{};
  int allCharsMask = 0;
  Set<int>? allCharsPunctChars = <int>{};

  int groupLeadingUnboundedMask = 0;
  Set<int>? groupLeadingUnboundedPunctChars = <int>{};
  int groupTrailingUnboundedMask = 0;
  Set<int>? groupTrailingUnboundedPunctChars = <int>{};
  int groupTrailingNullableMask = 0;
  Set<int>? groupTrailingNullablePunctChars = <int>{};
  int groupMaxTrailingNullableChain = 0;
  int groupFirstAtomMask = 0;
  Set<int>? groupFirstAtomPunctChars = <int>{};
  bool groupCanBeEmpty = false;

  final List<_BranchFirstMatch> branches = <_BranchFirstMatch>[
    _BranchFirstMatch(),
  ];

  void finishBranch() {
    groupLeadingUnboundedPunctChars = A2uiSurfaceBloc._unionPunctChars(
      groupLeadingUnboundedMask,
      groupLeadingUnboundedPunctChars,
      leadingUnboundedMask,
      leadingUnboundedPunctChars,
    );
    groupLeadingUnboundedMask |= leadingUnboundedMask;

    groupTrailingUnboundedPunctChars = A2uiSurfaceBloc._unionPunctChars(
      groupTrailingUnboundedMask,
      groupTrailingUnboundedPunctChars,
      trailingUnboundedMask,
      trailingUnboundedPunctChars,
    );
    groupTrailingUnboundedMask |= trailingUnboundedMask;

    groupFirstAtomPunctChars = A2uiSurfaceBloc._unionPunctChars(
      groupFirstAtomMask,
      groupFirstAtomPunctChars,
      firstAtomMask,
      firstAtomPunctChars,
    );
    groupFirstAtomMask |= firstAtomMask;
    groupCanBeEmpty = groupCanBeEmpty || branchCanBeEmpty;
    if (ambiguousAlternationCount > groupMaxAmbiguousAlternationCount) {
      groupMaxAmbiguousAlternationCount = ambiguousAlternationCount;
    }
    if (nullableAmbiguityCount > groupMaxNullableAmbiguityCount) {
      groupMaxNullableAmbiguityCount = nullableAmbiguityCount;
    }
    if (trailingUnboundedOverlapChain > groupMaxUnboundedOverlapChain) {
      groupMaxUnboundedOverlapChain = trailingUnboundedOverlapChain;
    }
    groupTrailingNullablePunctChars = A2uiSurfaceBloc._unionPunctChars(
      groupTrailingNullableMask,
      groupTrailingNullablePunctChars,
      trailingNullableMask,
      trailingNullablePunctChars,
    );
    groupTrailingNullableMask |= trailingNullableMask;
    if (trailingNullableChain > groupMaxTrailingNullableChain) {
      groupMaxTrailingNullableChain = trailingNullableChain;
    }
  }

  void recordAtom(
    int mask,
    Set<int>? punctChars, {
    required bool wasBranchEmpty,
    int? codeUnit,
  }) {
    if (wasBranchEmpty) {
      branches.last.record(mask, punctChars, codeUnit: codeUnit);
    }
    if (wasBranchEmpty || firstAtomMask == 0) {
      firstAtomPunctChars = A2uiSurfaceBloc._unionPunctChars(
        firstAtomMask,
        firstAtomPunctChars,
        mask,
        punctChars,
      );
      firstAtomMask |= mask;
    }
    allCharsPunctChars = A2uiSurfaceBloc._unionPunctChars(
      allCharsMask,
      allCharsPunctChars,
      mask,
      punctChars,
    );
    allCharsMask |= mask;
  }

  void startNewBranch() {
    finishBranch();
    branches.add(_BranchFirstMatch());
    leadingUnboundedMask = 0;
    leadingUnboundedPunctChars = <int>{};
    trailingUnboundedMask = 0;
    trailingUnboundedPunctChars = <int>{};
    trailingUnboundedAbsorbed = 0;
    trailingUnboundedOverlapChain = 0;
    trailingNullableMask = 0;
    trailingNullablePunctChars = <int>{};
    trailingNullableChain = 0;
    ambiguousAlternationCount = 0;
    nullableAmbiguityCount = 0;
    firstAtomMask = 0;
    firstAtomPunctChars = <int>{};
    branchCanBeEmpty = true;
  }
}

class _BranchFirstMatch {
  int mask = 0;
  Set<int>? punctChars = <int>{};
  final Set<int> exactCodeUnits = <int>{};
  bool hasNonLiteral = false;

  void record(int atomMask, Set<int>? atomPunctChars, {int? codeUnit}) {
    punctChars = A2uiSurfaceBloc._unionPunctChars(
      mask,
      punctChars,
      atomMask,
      atomPunctChars,
    );
    mask |= atomMask;
    if (codeUnit != null) {
      exactCodeUnits.add(codeUnit);
    } else {
      hasNonLiteral = true;
    }
  }
}
