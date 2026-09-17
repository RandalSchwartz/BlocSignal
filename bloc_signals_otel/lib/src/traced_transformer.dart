import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:opentelemetry/api.dart' as otel;

/// Wraps an [EventTransformer] in a [BlocEventTransformer] that records
/// an OpenTelemetry trace span for each event processed by the transformer.
///
/// The span is tagged with the host bloc's type (`bloc.type`) and the event's
/// type (`event.type`). Any unhandled exceptions that escape the transformer or
/// its handler are recorded on the span before being rethrown.
///
/// If [tracer] is omitted, [otel.globalTracerProvider] is used to resolve
/// the `'bloc_signals_otel'` tracer.
///
/// An optional [spanName] can be specified to override the default span name
/// (`'${bloc.runtimeType}.${event.runtimeType}'`).
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
  otel.Tracer? tracer,
  String? spanName,
}) {
  return tracedBloc(
    transformer.toBlocTransformer(),
    tracer: tracer,
    spanName: spanName,
  );
}

/// Wraps a contextual [BlocEventTransformer] with OpenTelemetry tracing.
///
/// The span is tagged with the host bloc's type (`bloc.type`) and the event's
/// type (`event.type`). Any unhandled exceptions that escape the transformer or
/// its handler are recorded on the span before being rethrown.
///
/// If [tracer] is omitted, [otel.globalTracerProvider] is used to resolve
/// the `'bloc_signals_otel'` tracer.
///
/// An optional [spanName] can be specified to override the default span name
/// (`'${bloc.runtimeType}.${event.runtimeType}'`).
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
  otel.Tracer? tracer,
  String? spanName,
}) {
  return (bloc, event, handler, emit) {
    final effectiveTracer =
        tracer ?? otel.globalTracerProvider.getTracer('bloc_signals_otel');
    final name = spanName ?? '${bloc.runtimeType}.${event.runtimeType}';
    final span = effectiveTracer.startSpan(
      name,
      attributes: [
        otel.Attribute.fromString('bloc.type', bloc.runtimeType.toString()),
        otel.Attribute.fromString('event.type', event.runtimeType.toString()),
      ],
    );

    var exceptionRecorded = false;
    var spanEnded = false;
    var handlerInvoked = false;

    void recordError(Object error, StackTrace stackTrace) {
      if (!exceptionRecorded) {
        exceptionRecorded = true;
        span
          ..recordException(error, stackTrace: stackTrace)
          ..setStatus(otel.StatusCode.error, error.toString());
      }
    }

    void endSpanOk() {
      if (!spanEnded && !exceptionRecorded) {
        spanEnded = true;
        span
          ..setStatus(otel.StatusCode.ok)
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
          handlerInvoked = true;
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
          } catch (error, stackTrace) {
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

      if (handlerInvoked) {
        endSpanOk();
      }
    } catch (error, stackTrace) {
      endSpanError(error, stackTrace);
      rethrow;
    }
  };
}
