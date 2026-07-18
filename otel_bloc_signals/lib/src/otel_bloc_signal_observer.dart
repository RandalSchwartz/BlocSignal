import 'package:bloc_signals/bloc_signals.dart';
import 'package:opentelemetry/api.dart' as otel;

/// A [BlocSignalObserver] that instruments `BlocSignal` lifecycles
/// with OpenTelemetry spans.
class OtelBlocSignalObserver extends BlocSignalObserver {
  /// Creates an observer that routes BlocSignal lifecycle steps to the
  /// provided [tracer].
  OtelBlocSignalObserver({otel.Tracer? tracer})
    : _tracer =
          tracer ?? otel.globalTracerProvider.getTracer('otel_bloc_signals');

  final otel.Tracer _tracer;

  // Track active spans for events mapped by a unique key per bloc/event.
  final Map<String, otel.Span> _activeSpans = {};

  String _spanKey(BlocSignal<dynamic, dynamic> bloc, Object? event) {
    return '${identityHashCode(bloc)}_${identityHashCode(event)}';
  }

  @override
  void onEvent(BlocSignal<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event == null) return;

    final span = _tracer.startSpan(
      '${bloc.runtimeType}.add(${event.runtimeType})',
      attributes: [
        otel.Attribute.fromString('bloc.type', bloc.runtimeType.toString()),
        otel.Attribute.fromString('event.type', event.runtimeType.toString()),
      ],
    );

    _activeSpans[_spanKey(bloc, event)] = span;
  }

  @override
  void onTransition(
    BlocSignal<dynamic, dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);

    final key = _spanKey(bloc, event);
    final span = _activeSpans[key];

    if (span != null) {
      span
        ..setAttribute(
          otel.Attribute.fromString('state.value', state.toString()),
        )
        ..setStatus(otel.StatusCode.ok)
        ..end();
      _activeSpans.remove(key);
    }
  }

  @override
  void onError(
    BlocSignal<dynamic, dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);

    // Record error against a transient error span
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
