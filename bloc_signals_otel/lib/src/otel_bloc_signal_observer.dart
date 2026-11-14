import 'package:bloc_signals/bloc_signals.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    as otel;

/// A [BlocSignalObserver] that instruments `BlocSignal` lifecycles
/// with OpenTelemetry spans.
class OtelBlocSignalObserver extends BlocSignalObserver {
  /// Creates an observer that routes BlocSignal lifecycle steps to the
  /// provided [tracer].
  ///
  /// If [tracer] is omitted, [otel.OTelAPI.tracerProvider] is used to resolve
  /// the `'bloc_signals_otel'` tracer.
  ///
  /// The [maxActiveSpans] parameter caps the active span cache size
  /// (default 100) to prevent transient memory growth under high-frequency
  /// event streams via FIFO (oldest-span) eviction.
  ///
  /// An optional [stateRedactor] callback can be provided to format or redact
  /// state values before recording them under the `state.value` span attribute.
  /// If [stateRedactor] returns `null`, the `state.value` attribute is omitted.
  ///
  /// An optional [eventRedactor] callback can be provided to format or redact
  /// event values before recording them under the `event.value` transition
  /// event attribute. If [eventRedactor] returns `null`, `event.value` is
  /// omitted.
  ///
  /// An optional [errorRedactor] callback can be provided to format or redact
  /// error messages before recording them on span status descriptions and
  /// `exception.message` attributes. If [errorRedactor] returns `null`, the
  /// span status description is omitted and `exception.message` is recorded as
  /// `'[REDACTED]'`.
  ///
  /// An optional [maxAttributeLength] caps the character length of recorded
  /// string attributes (`state.value`, `event.value`, error messages, and
  /// stringified metadata values). When provided, it must be greater than zero.
  OtelBlocSignalObserver({
    otel.APITracer? tracer,
    this.maxActiveSpans = 100,
    this.stateRedactor,
    this.eventRedactor,
    this.errorRedactor,
    this.maxAttributeLength,
  })  : assert(maxActiveSpans > 0, 'maxActiveSpans must be greater than zero.'),
        assert(
          maxAttributeLength == null || maxAttributeLength > 0,
          'maxAttributeLength must be greater than zero.',
        ),
        _tracer = tracer ??
            otel.OTelAPI.tracerProvider().getTracer('bloc_signals_otel');

  final otel.APITracer _tracer;

  /// The maximum number of active unclosed spans retained before FIFO eviction.
  final int maxActiveSpans;

  /// Optional callback to redact or format state values before recording them
  /// on OpenTelemetry spans.
  ///
  /// ```dart
  /// final observer = OtelBlocSignalObserver(
  ///   stateRedactor: (bloc, state) {
  ///     if (state is UserProfileState) {
  ///       return 'UserProfile(id: ${state.id}, email: [REDACTED])';
  ///     }
  ///     return state?.toString();
  ///   },
  /// );
  /// ```
  final String? Function(BlocSignalBase<dynamic> bloc, Object? state)?
      stateRedactor;

  /// Optional callback to redact or format event values before recording them
  /// under the `event.value` attribute on transition span events.
  ///
  /// Returning `null` omits `event.value` from the transition event.
  final String? Function(BlocSignalBase<dynamic> bloc, Object? event)?
      eventRedactor;

  /// Optional callback to redact or format error descriptions before recording
  /// them on span status descriptions and `exception.message` attributes.
  ///
  /// Returning `null` omits the span status description and records
  /// `'[REDACTED]'` for `exception.message`.
  final String? Function(BlocSignalBase<dynamic> bloc, Object error)?
      errorRedactor;

  /// Optional maximum character length applied to string span and event
  /// attributes (`state.value`, `event.value`, error messages, and string
  /// metadata).
  final int? maxAttributeLength;

  // Track active spans for events mapped by a unique key per bloc/event.
  // Uses a FIFO list to prevent collisions when repeated identical or const
  // events are dispatched before prior spans close.
  final Map<String, List<otel.APISpan>> _activeSpans = {};

  int get _totalActiveSpans =>
      _activeSpans.values.fold(0, (sum, list) => sum + list.length);

  String _spanKey(BlocSignalBase<dynamic> bloc, Object? event) {
    return '${identityHashCode(bloc)}_${identityHashCode(event)}';
  }

  String _cap(String value) {
    final max = maxAttributeLength;
    if (max != null && value.length > max) {
      return value.substring(0, max);
    }
    return value;
  }

  String? _formatState(BlocSignalBase<dynamic> bloc, Object? state) {
    final raw =
        stateRedactor != null ? stateRedactor!(bloc, state) : state?.toString();
    return raw != null ? _cap(raw) : null;
  }

  String? _formatEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    if (event == null) return null;
    final raw =
        eventRedactor != null ? eventRedactor!(bloc, event) : event.toString();
    return raw != null ? _cap(raw) : null;
  }

  String? _formatError(BlocSignalBase<dynamic> bloc, Object error) {
    final raw =
        errorRedactor != null ? errorRedactor!(bloc, error) : error.toString();
    return raw != null ? _cap(raw) : null;
  }

  Map<String, Object> _normalizeMetadata(Map<String, dynamic> metadata) {
    return {
      for (final entry in metadata.entries)
        entry.key: _normalizeMetadataValue(entry.value),
    };
  }

  Object _normalizeMetadataValue(Object? value) {
    if (value == null) return 'null';
    if (value is bool || value is int || value is double) return value;
    if (value is String) return _cap(value);
    if (value is List<bool> || value is List<int> || value is List<double>) {
      return value;
    }
    if (value is List<Object?> &&
        value.isNotEmpty &&
        value.every((element) => element is num)) {
      return value.map((element) => (element! as num).toDouble()).toList();
    }
    if (value is Iterable<Object?>) {
      return value.map((element) => _cap(element.toString())).toList();
    }
    return _cap(value.toString());
  }

  void _applyStateAttribute(
    otel.APISpan span,
    BlocSignalBase<dynamic> bloc,
    Object? state,
  ) {
    final stateStr = _formatState(bloc, state);
    if (stateStr != null) {
      span.setStringAttribute<String>('state.value', stateStr);
    }
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event == null) return;

    if (_totalActiveSpans >= maxActiveSpans) {
      final oldestKey = _activeSpans.keys.first;
      final list = _activeSpans[oldestKey]!;
      list.removeAt(0).end();
      if (list.isEmpty) _activeSpans.remove(oldestKey);
    }

    final span = _tracer.startSpan(
      '${bloc.runtimeType}.add(${event.runtimeType})',
      attributes: otel.OTelAPI.attributesFromMap({
        'bloc.type': bloc.runtimeType.toString(),
        'event.type': event.runtimeType.toString(),
      }),
    );

    (_activeSpans[_spanKey(bloc, event)] ??= []).add(span);
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);

    final key = _spanKey(bloc, event);
    final spans = _activeSpans[key];

    if (spans != null && spans.isNotEmpty) {
      final span = spans.first;
      _applyStateAttribute(span, bloc, state);
      final stateStr = _formatState(bloc, state);
      final eventStr = _formatEvent(bloc, event);
      span.addEventNow(
        'transition',
        otel.OTelAPI.attributesFromMap({
          if (stateStr != null) 'state.value': stateStr,
          if (eventStr != null) 'event.value': eventStr,
        }),
      );
    }
  }

  @override
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEventCompleted(bloc, event);

    final key = _spanKey(bloc, event);
    final spans = _activeSpans[key];

    if (spans != null && spans.isNotEmpty) {
      final span = spans.removeAt(0);
      if (spans.isEmpty) _activeSpans.remove(key);

      _applyStateAttribute(span, bloc, bloc.stateValue);
      span
        ..setStatus(otel.SpanStatusCode.Ok)
        ..end();
    }
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);

    final errorMessage = _formatError(bloc, error);
    final exceptionAttributes = otel.OTelAPI.attributesFromMap({
      'exception.message': errorMessage ?? '[REDACTED]',
    });

    final blocId = identityHashCode(bloc).toString();
    final keysToRemove =
        _activeSpans.keys.where((key) => key.startsWith('${blocId}_')).toList();

    if (keysToRemove.isNotEmpty) {
      for (final key in keysToRemove) {
        final spans = _activeSpans.remove(key);
        if (spans != null) {
          for (final span in spans) {
            span
              ..recordException(
                error,
                stackTrace: stackTrace,
                attributes: exceptionAttributes,
              )
              ..setStatus(otel.SpanStatusCode.Error, errorMessage)
              ..end();
          }
        }
      }
    } else {
      _tracer.startSpan(
        '${bloc.runtimeType}.error',
        attributes: otel.OTelAPI.attributesFromMap({
          'bloc.type': bloc.runtimeType.toString(),
        }),
      )
        ..recordException(
          error,
          stackTrace: stackTrace,
          attributes: exceptionAttributes,
        )
        ..setStatus(otel.SpanStatusCode.Error, errorMessage)
        ..end();
    }
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    super.onClose(bloc);

    final blocId = identityHashCode(bloc).toString();
    final keysToRemove =
        _activeSpans.keys.where((key) => key.startsWith('${blocId}_')).toList();

    for (final key in keysToRemove) {
      final spans = _activeSpans.remove(key);
      if (spans != null) {
        for (final span in spans) {
          span.end();
        }
      }
    }
  }

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    super.onTelemetry(bloc, name, event: event, metadata: metadata);

    final key = _spanKey(bloc, event);
    final spans = _activeSpans[key];
    final activeSpan = (spans != null && spans.isNotEmpty) ? spans.first : null;

    if (activeSpan != null) {
      activeSpan.addEventNow(
        name,
        otel.OTelAPI.attributesFromMap(
          metadata != null ? _normalizeMetadata(metadata) : const {},
        ),
      );
      if (name == BlocTelemetryKeys.eventDropped ||
          name == BlocTelemetryKeys.taskPreempted) {
        activeSpan
          ..setBoolAttribute('bloc.contention', true)
          ..setStatus(otel.SpanStatusCode.Ok)
          ..end();
        spans!.removeAt(0);
        if (spans.isEmpty) _activeSpans.remove(key);
      }
    } else {
      _tracer
          .startSpan(
            '${bloc.runtimeType}.telemetry.$name',
            attributes: otel.OTelAPI.attributesFromMap({
              if (metadata != null) ..._normalizeMetadata(metadata),
              'bloc.type': bloc.runtimeType.toString(),
            }),
          )
          .end();
    }
  }
}
