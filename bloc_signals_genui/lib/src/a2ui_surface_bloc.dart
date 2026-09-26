import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/src/a2ui_action_response.dart';
import 'package:bloc_signals_genui/src/a2ui_surface_event.dart';
import 'package:bloc_signals_genui/src/a2ui_surface_state.dart';
import 'package:bloc_signals_genui/src/standard_catalog.dart';

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
  A2uiSurfaceBloc({
    List<Catalog<ComponentApi, FunctionImplementation>>? catalogs,
  })  : catalogs = catalogs ??
            [
              StandardCatalog(),
              StandardCatalog(
                id: 'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json',
              ),
            ],
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
    on<CancelSubmission>(_onCancelSubmission);
    on<CompleteAction>(_onCompleteAction);
    on<ResetSurface>(_onResetSurface);
  }

  /// The active component catalogs registered with this surface bloc.
  final List<Catalog<ComponentApi, FunctionImplementation>> catalogs;

  late final MessageProcessor<ComponentApi> _processor;

  /// The primary active surface ID being tracked by this bloc.
  String? _activeSurfaceId;

  /// Returns the current active surface ID, derived from state or tracked session.
  String? get activeSurfaceId => stateValue.surfaceId ?? _activeSurfaceId;

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
        final liveQueue = <A2uiActionResponse>[];
        var replaying = true;

        sub = _actionResponsesController.stream.listen(
          (event) {
            if (replaying) {
              liveQueue.add(event);
            } else {
              controller.add(event);
            }
          },
          onError: controller.addError,
          onDone: controller.close,
        );

        _responseHistory.forEach(controller.add);
        replaying = false;

        liveQueue.forEach(controller.add);
        liveQueue.clear();
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

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
          onError(error, stackTrace);
          if (error is Error) rethrow;
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
        onError(error, stackTrace);
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
        if (error is Error) throw error;
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
      final message = _normalizeMessage(event.message);
      if (message is CreateSurfaceMessage) {
        _activeSurfaceId = message.surfaceId;
      }
      _processor.processMessages([message]);
      _surfaceVersion++;
      _emitFinalReadyOrInitial(emit);
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
      if (message is CreateSurfaceMessage) {
        _activeSurfaceId = message.surfaceId;
      }
      _processor.processMessages([message]);
      _surfaceVersion++;
      _emitFinalReadyOrInitial(emit);
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
      for (final msg in normalizedMessages) {
        if (msg is CreateSurfaceMessage) {
          _activeSurfaceId = msg.surfaceId;
        }
      }
      _processor.processMessages(normalizedMessages);
      _surfaceVersion++;
      _emitFinalReadyOrInitial(emit);
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

    // Capture form values and enforce validation contract
    final formValues = _extractFormData(surface);
    final validationErrors = _validateForm(surface, formValues);
    if (validationErrors.isNotEmpty) {
      _surfaceVersion++;
      emit(
        SurfaceReady(
          surfaceId: surfaceId,
          surface: surface,
          formValues: formValues,
          isValid: false,
          validationErrors: validationErrors,
          version: _surfaceVersion,
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
    final targetSurfaceId = surfaceId ?? activeSurfaceId;
    if (targetSurfaceId == null) return;

    final surface = _processor.groupModel.getSurface(targetSurfaceId);
    if (surface == null) return;

    final formValues = _extractFormData(surface);
    final formErrors = _validateForm(surface, formValues);
    final validationErrors = List<String>.from(formErrors);
    if (error != null && error.trim().isNotEmpty) {
      final trimmed = error.trim();
      if (!validationErrors.contains(trimmed)) {
        validationErrors.add(trimmed);
      }
    }

    _surfaceVersion++;
    emit(
      SurfaceReady(
        surfaceId: targetSurfaceId,
        surface: surface,
        formValues: formValues,
        isValid: validationErrors.isEmpty,
        validationErrors: validationErrors,
        version: _surfaceVersion,
      ),
    );
  }

  void _onResetSurface(
    ResetSurface event,
    void Function(A2uiSurfaceState) emit,
  ) {
    _responseHistory.clear();
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

  void _emitSurfaceSnapshot(
    void Function(A2uiSurfaceState) emit, {
    required int messageCount,
  }) {
    if (_activeSurfaceId != null) {
      final surface = _processor.groupModel.getSurface(_activeSurfaceId!);
      if (surface != null && surface.componentsModel.all.isNotEmpty) {
        final formValues = _extractFormData(surface);
        final validationErrors = _validateForm(surface, formValues);
        emit(
          SurfaceReady(
            surfaceId: _activeSurfaceId!,
            surface: surface,
            formValues: formValues,
            isValid: validationErrors.isEmpty,
            validationErrors: validationErrors,
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
        final validationErrors = _validateForm(surface, formValues);
        emit(
          SurfaceReady(
            surfaceId: _activeSurfaceId!,
            surface: surface,
            formValues: formValues,
            isValid: validationErrors.isEmpty,
            validationErrors: validationErrors,
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
      final validationErrors = _validateForm(first, formValues);
      emit(
        SurfaceReady(
          surfaceId: first.id,
          surface: first,
          formValues: formValues,
          isValid: validationErrors.isEmpty,
          validationErrors: validationErrors,
          version: _surfaceVersion,
        ),
      );
      return;
    }

    emit(const SurfaceInitial());
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
          try {
            if (!RegExp(pattern).hasMatch(fieldValue)) {
              errors.add('Field "$label" does not match the required pattern.');
            }
          } catch (_) {}
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
    _responseHistory.clear();
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
