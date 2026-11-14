import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    as otel;

/// Wraps an [EventTransformer] in a [BlocEventTransformer] that records
/// an OpenTelemetry trace span for each event processed by the transformer.
///
/// The span is tagged with the host bloc's type (`bloc.type`) and the event's
/// type (`event.type`). Any unhandled exceptions that escape the transformer or
/// its handler are recorded on the span before being rethrown.
///
/// If [tracer] is omitted, [otel.OTelAPI.tracerProvider] is used to resolve
/// the `'bloc_signals_otel'` tracer.
///
/// An optional [spanName] can be specified to override the default span name
/// (`'${bloc.runtimeType}.${event.runtimeType}'`).
///
/// An optional [errorRedactor] callback can be provided to format or redact
/// error descriptions before recording them on span status descriptions and
/// `exception.message` attributes. Returning `null` omits the span status
/// description and records `'[REDACTED]'` for `exception.message`.
///
/// An optional [maxAttributeLength] caps the character length of recorded
/// error messages when greater than zero.
///
/// ### Example
/// ```dart
/// class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
///   SearchBloc() : super(initialState: SearchInitial()) {
///     on<SearchQueryChanged>(
///       _onSearchQueryChanged,
///       blocTransformer: traced(restartable()),
///     );
///   }
/// }
/// ```
BlocEventTransformer<E, StateType> traced<E, StateType>(
  EventTransformer<E, StateType> transformer, {
  otel.APITracer? tracer,
  String? spanName,
  String? Function(BlocSignalBase<dynamic> bloc, Object error)? errorRedactor,
  int? maxAttributeLength,
}) {
  assert(
    maxAttributeLength == null || maxAttributeLength > 0,
    'maxAttributeLength must be greater than zero.',
  );
  return tracedBloc(
    transformer.toBlocTransformer(),
    tracer: tracer,
    spanName: spanName,
    errorRedactor: errorRedactor,
    maxAttributeLength: maxAttributeLength,
  );
}

/// Wraps a contextual [BlocEventTransformer] with OpenTelemetry tracing.
///
/// The span is tagged with the host bloc's type (`bloc.type`) and the event's
/// type (`event.type`). Any unhandled exceptions that escape the transformer or
/// its handler are recorded on the span before being rethrown.
///
/// If [tracer] is omitted, [otel.OTelAPI.tracerProvider] is used to resolve
/// the `'bloc_signals_otel'` tracer.
///
/// An optional [spanName] can be specified to override the default span name
/// (`'${bloc.runtimeType}.${event.runtimeType}'`).
///
/// An optional [errorRedactor] callback can be provided to format or redact
/// error descriptions before recording them on span status descriptions and
/// `exception.message` attributes. Returning `null` omits the span status
/// description and records `'[REDACTED]'` for `exception.message`.
///
/// An optional [maxAttributeLength] caps the character length of recorded
/// error messages when greater than zero.
///
/// ### Example
/// ```dart
/// on<SearchQueryChanged>(
///   _onSearchQueryChanged,
///   blocTransformer: tracedBloc(
///     myCustomBlocTransformer,
///   ),
/// );
/// ```
BlocEventTransformer<E, StateType> tracedBloc<E, StateType>(
  BlocEventTransformer<E, StateType> transformer, {
  otel.APITracer? tracer,
  String? spanName,
  String? Function(BlocSignalBase<dynamic> bloc, Object error)? errorRedactor,
  int? maxAttributeLength,
}) {
  assert(
    maxAttributeLength == null || maxAttributeLength > 0,
    'maxAttributeLength must be greater than zero.',
  );
  return (bloc, event, handler, emit) {
    final effectiveTracer =
        tracer ?? otel.OTelAPI.tracerProvider().getTracer('bloc_signals_otel');
    final name = spanName ?? '${bloc.runtimeType}.${event.runtimeType}';
    final span = effectiveTracer.startSpan(
      name,
      attributes: otel.OTelAPI.attributesFromMap({
        'bloc.type': bloc.runtimeType.toString(),
        'event.type': event.runtimeType.toString(),
      }),
    );

    var exceptionRecorded = false;
    var spanEnded = false;

    void recordError(Object error, StackTrace stackTrace) {
      if (!exceptionRecorded) {
        exceptionRecorded = true;
        var errorMessage = errorRedactor != null
            ? errorRedactor(bloc, error)
            : error.toString();
        if (errorMessage != null &&
            maxAttributeLength != null &&
            errorMessage.length > maxAttributeLength) {
          errorMessage = errorMessage.substring(0, maxAttributeLength);
        }
        span
          ..recordException(
            error,
            stackTrace: stackTrace,
            attributes: otel.OTelAPI.attributesFromMap({
              'exception.message': errorMessage ?? '[REDACTED]',
            }),
          )
          ..setStatus(otel.SpanStatusCode.Error, errorMessage);
      }
    }

    void endSpanOk() {
      if (!spanEnded && !exceptionRecorded) {
        spanEnded = true;
        span
          ..setStatus(otel.SpanStatusCode.Ok)
          ..end();
      }
    }

    void endSpanError(Object error, StackTrace stackTrace) {
      recordError(error, stackTrace);
      if (!spanEnded) {
        spanEnded = true;
        span.end();
      }
    }

    try {
      final result = transformer(
        bloc,
        event,
        (e, em) {
          try {
            final res = handler(e, em);
            if (res is Future) {
              return res.then<void>((_) {
                endSpanOk();
              }).catchError((Object error, StackTrace stackTrace) {
                endSpanError(error, stackTrace);
                Error.throwWithStackTrace(error, stackTrace);
              });
            } else {
              endSpanOk();
            }
            // Intentional `on Object catch` (SCAR-OTEL-02 / SCAR-ERR-02):
            // record span error status and close the OpenTelemetry span on any
            // synchronous `Exception` or `Error` before rethrowing.
          } on Object catch (error, stackTrace) {
            endSpanError(error, stackTrace);
            rethrow;
          }
        },
        emit,
      );

      if (result is Future) {
        return result.then((_) {
          endSpanOk();
        }).catchError((Object error, StackTrace stackTrace) {
          endSpanError(error, stackTrace);
          Error.throwWithStackTrace(error, stackTrace);
        });
      }

      endSpanOk();
      // Intentional `on Object catch` (SCAR-OTEL-02 / SCAR-ERR-02): ensure
      // outer transformer span is closed with error status before rethrowing.
    } on Object catch (error, stackTrace) {
      endSpanError(error, stackTrace);
      rethrow;
    }
  };
}
