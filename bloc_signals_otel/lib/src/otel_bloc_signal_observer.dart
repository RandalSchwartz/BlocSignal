import 'dart:async';
import 'dart:collection';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart'
    as otel;

class _ActiveSpanEntry {
  _ActiveSpanEntry({
    required this.key,
    required this.blocId,
    required this.span,
    this.dispatchToken,
  });

  final String key;
  final int blocId;
  final otel.APISpan span;
  final Object? dispatchToken;
}

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
  ///
  /// An optional [stackTraceRedactor] callback can be provided to format or
  /// redact stack traces before recording them under `exception.stacktrace`.
  /// Returning an empty string omits `exception.stacktrace`.
  ///
  /// An optional [maxStackTraceLength] caps the character length of recorded
  /// `exception.stacktrace` attributes. When omitted, [maxAttributeLength] is
  /// used if provided. When provided, it must be greater than zero.
  OtelBlocSignalObserver({
    otel.APITracer? tracer,
    this.maxActiveSpans = 100,
    this.stateRedactor,
    this.eventRedactor,
    this.errorRedactor,
    this.maxAttributeLength,
    this.stackTraceRedactor,
    this.maxStackTraceLength,
  })  : assert(maxActiveSpans > 0, 'maxActiveSpans must be greater than zero.'),
        assert(
          maxAttributeLength == null || maxAttributeLength > 0,
          'maxAttributeLength must be greater than zero.',
        ),
        assert(
          maxStackTraceLength == null || maxStackTraceLength > 0,
          'maxStackTraceLength must be greater than zero.',
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

  /// Optional callback to redact or format stack traces before recording them
  /// under the `exception.stacktrace` attribute.
  ///
  /// Returning an empty string omits `exception.stacktrace`.
  final String Function(StackTrace stackTrace)? stackTraceRedactor;

  /// Optional maximum character length applied to recorded
  /// `exception.stacktrace` attributes.
  ///
  /// Falls back to [maxAttributeLength] when `null`.
  final int? maxStackTraceLength;

  final Map<Object, _ActiveSpanEntry> _activeSpansByToken = {};
  final Map<String, Queue<_ActiveSpanEntry>> _activeSpansByKey = {};
  final Queue<_ActiveSpanEntry> _chronologicalSpans = Queue<_ActiveSpanEntry>();

  String _spanKey(BlocSignalBase<dynamic> bloc, Object? event) {
    return '${identityHashCode(bloc)}_${identityHashCode(event)}';
  }

  Object? _currentDispatchToken() =>
      Zone.current[BlocSignalBase.ambientZoneDispatchTokenKey];

  bool _isTokenOwnedByBloc(
    Object? dispatchToken,
    BlocSignalBase<dynamic> bloc,
  ) {
    if (dispatchToken == null) return false;
    final Object? ambientBloc = Zone.current[BlocSignalBase.ambientZoneBlocKey];
    return ambientBloc == null || identical(ambientBloc, bloc);
  }

  _ActiveSpanEntry? _entryForToken(
    Object? dispatchToken,
    BlocSignalBase<dynamic> bloc,
  ) {
    if (dispatchToken == null) return null;
    final entry = _activeSpansByToken[dispatchToken];
    if (entry == null || entry.blocId != identityHashCode(bloc)) {
      return null;
    }
    return entry;
  }

  void _removeEntry(_ActiveSpanEntry entry) {
    final token = entry.dispatchToken;
    if (token != null) {
      _activeSpansByToken.remove(token);
    }
    final queue = _activeSpansByKey[entry.key];
    if (queue != null) {
      queue.remove(entry);
      if (queue.isEmpty) {
        _activeSpansByKey.remove(entry.key);
      }
    }
    _chronologicalSpans.remove(entry);
  }

  String? _formatStackTrace(StackTrace stackTrace) {
    var formatted = stackTraceRedactor != null
        ? stackTraceRedactor!(stackTrace)
        : stackTrace.toString();
    final maxLen = maxStackTraceLength ?? maxAttributeLength;
    if (maxLen != null && formatted.length > maxLen) {
      formatted = formatted.substring(0, maxLen);
    }
    return formatted.isEmpty ? null : formatted;
  }

  void _recordSpanError(
    otel.APISpan span,
    Object error,
    String? errorMessage,
    otel.Attributes exceptionAttributes,
  ) {
    span
      ..recordException(
        error,
        attributes: exceptionAttributes,
      )
      ..setStatus(otel.SpanStatusCode.Error, errorMessage)
      ..end();
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

    if (_chronologicalSpans.length >= maxActiveSpans) {
      final oldest = _chronologicalSpans.first;
      _removeEntry(oldest);
      oldest.span.end();
    }

    final span = _tracer.startSpan(
      '${bloc.runtimeType}.add(${event.runtimeType})',
      attributes: otel.OTelAPI.attributesFromMap({
        'bloc.type': bloc.runtimeType.toString(),
        'event.type': event.runtimeType.toString(),
      }),
    );

    final dispatchToken = _currentDispatchToken();
    final scopedToken = (dispatchToken != null &&
            _isTokenOwnedByBloc(dispatchToken, bloc) &&
            !_activeSpansByToken.containsKey(dispatchToken))
        ? dispatchToken
        : null;
    final key = _spanKey(bloc, event);
    final entry = _ActiveSpanEntry(
      key: key,
      blocId: identityHashCode(bloc),
      span: span,
      dispatchToken: scopedToken,
    );

    _chronologicalSpans.addLast(entry);
    (_activeSpansByKey[key] ??= Queue<_ActiveSpanEntry>()).addLast(entry);
    if (scopedToken != null) {
      _activeSpansByToken[scopedToken] = entry;
    }
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);

    final dispatchToken = _currentDispatchToken();
    final entry = _isTokenOwnedByBloc(dispatchToken, bloc)
        ? _entryForToken(dispatchToken, bloc)
        : _activeSpansByKey[_spanKey(bloc, event)]?.firstOrNull;

    if (entry != null) {
      final span = entry.span;
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

    final dispatchToken = _currentDispatchToken();
    final _ActiveSpanEntry? entry;
    if (_isTokenOwnedByBloc(dispatchToken, bloc)) {
      entry = _entryForToken(dispatchToken, bloc);
    } else {
      final queue = _activeSpansByKey[_spanKey(bloc, event)];
      entry = (queue != null && queue.isNotEmpty) ? queue.first : null;
    }

    if (entry != null) {
      _removeEntry(entry);
      _applyStateAttribute(entry.span, bloc, bloc.stateValue);
      entry.span
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
    final sanitizedStackTrace = _formatStackTrace(stackTrace);
    final exceptionAttributes = otel.OTelAPI.attributesFromMap({
      'exception.message': errorMessage ?? '[REDACTED]',
      if (sanitizedStackTrace != null)
        'exception.stacktrace': sanitizedStackTrace,
    });

    final dispatchToken = _currentDispatchToken();
    if (_isTokenOwnedByBloc(dispatchToken, bloc)) {
      final entry = _entryForToken(dispatchToken, bloc);
      if (entry != null) {
        _removeEntry(entry);
        _recordSpanError(entry.span, error, errorMessage, exceptionAttributes);
        return;
      }
    } else {
      final blocId = identityHashCode(bloc);
      final matching =
          _chronologicalSpans.where((e) => e.blocId == blocId).toList();
      if (matching.isNotEmpty) {
        for (final entry in matching) {
          _removeEntry(entry);
          _recordSpanError(
            entry.span,
            error,
            errorMessage,
            exceptionAttributes,
          );
        }
        return;
      }
    }

    final fallbackSpan = _tracer.startSpan(
      '${bloc.runtimeType}.error',
      attributes: otel.OTelAPI.attributesFromMap({
        'bloc.type': bloc.runtimeType.toString(),
      }),
    );
    _recordSpanError(fallbackSpan, error, errorMessage, exceptionAttributes);
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    super.onClose(bloc);

    final blocId = identityHashCode(bloc);
    final entries =
        _chronologicalSpans.where((e) => e.blocId == blocId).toList();

    for (final entry in entries) {
      _removeEntry(entry);
      entry.span.end();
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

    final dispatchToken = _currentDispatchToken();
    final ownToken =
        _isTokenOwnedByBloc(dispatchToken, bloc) ? dispatchToken : null;
    final key = _spanKey(bloc, event);

    final _ActiveSpanEntry? targetEntry;
    if (name == BlocTelemetryKeys.eventDropped) {
      targetEntry = ownToken != null
          ? _entryForToken(ownToken, bloc)
          : _activeSpansByKey[key]?.lastOrNull;
    } else if (name == BlocTelemetryKeys.taskPreempted) {
      final queue = _activeSpansByKey[key];
      if (queue == null || queue.isEmpty) {
        targetEntry = null;
      } else if (ownToken != null) {
        targetEntry =
            queue.where((e) => e.dispatchToken != ownToken).firstOrNull;
      } else {
        targetEntry = queue.first;
      }
    } else {
      targetEntry = ownToken != null
          ? _entryForToken(ownToken, bloc)
          : _activeSpansByKey[key]?.firstOrNull;
    }

    if (targetEntry != null) {
      targetEntry.span.addEventNow(
        name,
        otel.OTelAPI.attributesFromMap(
          metadata != null ? _normalizeMetadata(metadata) : const {},
        ),
      );
      if (name == BlocTelemetryKeys.eventDropped ||
          name == BlocTelemetryKeys.taskPreempted) {
        _removeEntry(targetEntry);
        targetEntry.span
          ..setBoolAttribute('bloc.contention', true)
          ..setStatus(otel.SpanStatusCode.Ok)
          ..end();
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
