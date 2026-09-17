import 'package:bloc_signals/bloc_signals.dart';
import 'package:opentelemetry/api.dart' as otel;

/// A [BlocSignalObserver] that instruments `BlocSignal` lifecycles
/// with OpenTelemetry spans.
class OtelBlocSignalObserver extends BlocSignalObserver {
  /// Creates an observer that routes BlocSignal lifecycle steps to the
  /// provided [tracer].
  ///
  /// The [maxActiveSpans] parameter caps the active span cache size
  /// (default 100) to prevent transient memory growth under high-frequency
  /// event streams.
  ///
  /// An optional [stateRedactor] callback can be provided to format or redact
  /// state values before recording them under the `state.value` span attribute.
  /// If [stateRedactor] returns `null`, the `state.value` attribute is omitted.
  OtelBlocSignalObserver({
    otel.Tracer? tracer,
    this.maxActiveSpans = 100,
    this.stateRedactor,
  })  : assert(maxActiveSpans > 0, 'maxActiveSpans must be greater than zero.'),
        _tracer =
            tracer ?? otel.globalTracerProvider.getTracer('bloc_signals_otel');

  final otel.Tracer _tracer;

  /// The maximum number of active unclosed spans retained before LRU eviction.
  final int maxActiveSpans;

  /// Optional callback to redact or format state values before recording them
  /// on OpenTelemetry spans.
  final String? Function(BlocSignalBase<dynamic> bloc, Object? state)?
      stateRedactor;

  // Track active spans for events mapped by a unique key per bloc/event.
  // Uses a FIFO list to prevent collisions when repeated identical or const
  // events are dispatched before prior spans close.
  final Map<String, List<otel.Span>> _activeSpans = {};

  int get _totalActiveSpans =>
      _activeSpans.values.fold(0, (sum, list) => sum + list.length);

  String _spanKey(BlocSignalBase<dynamic> bloc, Object? event) {
    return '${identityHashCode(bloc)}_${identityHashCode(event)}';
  }

  void _applyStateAttribute(
    otel.Span span,
    BlocSignalBase<dynamic> bloc,
    Object? state,
  ) {
    final stateStr =
        stateRedactor != null ? stateRedactor!(bloc, state) : state?.toString();
    if (stateStr != null) {
      span.setAttribute(otel.Attribute.fromString('state.value', stateStr));
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
      attributes: [
        otel.Attribute.fromString('bloc.type', bloc.runtimeType.toString()),
        otel.Attribute.fromString('event.type', event.runtimeType.toString()),
      ],
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
      final stateStr = stateRedactor != null
          ? stateRedactor!(bloc, state)
          : state?.toString();
      span.addEvent(
        'transition',
        attributes: [
          if (stateStr != null)
            otel.Attribute.fromString('state.value', stateStr),
          if (event != null)
            otel.Attribute.fromString('event.value', event.toString()),
        ],
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
        ..setStatus(otel.StatusCode.ok)
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

    final blocId = identityHashCode(bloc).toString();
    final keysToRemove =
        _activeSpans.keys.where((key) => key.startsWith('${blocId}_')).toList();

    if (keysToRemove.isNotEmpty) {
      for (final key in keysToRemove) {
        final spans = _activeSpans.remove(key);
        if (spans != null) {
          for (final span in spans) {
            span
              ..recordException(error, stackTrace: stackTrace)
              ..setStatus(otel.StatusCode.error, error.toString())
              ..end();
          }
        }
      }
    } else {
      _tracer.startSpan(
        '${bloc.runtimeType}.error',
        attributes: [
          otel.Attribute.fromString('bloc.type', bloc.runtimeType.toString()),
        ],
      )
        ..recordException(error, stackTrace: stackTrace)
        ..setStatus(otel.StatusCode.error, error.toString())
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

    final attrs = <otel.Attribute>[
      if (metadata != null)
        for (final entry in metadata.entries)
          _attributeFromValue(entry.key, entry.value),
    ];

    if (activeSpan != null) {
      activeSpan.addEvent(name, attributes: attrs);
      if (name == BlocTelemetryKeys.eventDropped ||
          name == BlocTelemetryKeys.taskPreempted) {
        activeSpan
          ..setAttribute(
            otel.Attribute.fromBoolean('bloc.contention', true),
          )
          ..setStatus(otel.StatusCode.ok)
          ..end();
        spans!.removeAt(0);
        if (spans.isEmpty) _activeSpans.remove(key);
      }
    } else {
      _tracer.startSpan(
        '${bloc.runtimeType}.telemetry.$name',
        attributes: [
          otel.Attribute.fromString(
            'bloc.type',
            bloc.runtimeType.toString(),
          ),
          ...attrs,
        ],
      ).end();
    }
  }

  otel.Attribute _attributeFromValue(String key, dynamic value) {
    if (value is bool) {
      return otel.Attribute.fromBoolean(key, value);
    }
    if (value is int) {
      return otel.Attribute.fromInt(key, value);
    }
    if (value is double) {
      return otel.Attribute.fromDouble(key, value);
    }
    if (value is List<String>) {
      return otel.Attribute.fromStringList(key, value);
    }
    if (value is List<int>) {
      return otel.Attribute.fromIntList(key, value);
    }
    if (value is List<double>) {
      return otel.Attribute.fromDoubleList(key, value);
    }
    if (value is List<bool>) {
      return otel.Attribute.fromBooleanList(key, value);
    }
    return otel.Attribute.fromString(key, value.toString());
  }
}
