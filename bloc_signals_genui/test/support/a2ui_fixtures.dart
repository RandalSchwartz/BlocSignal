// The A2UI envelope fixtures shared by this package's tests.

import 'dart:async';
import 'dart:convert';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';

/// The catalog identifier the standard catalog registers under.
const catalogId =
    'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

/// A well-formed `createSurface` envelope for [surfaceId].
Map<String, dynamic> createSurface(
  String surfaceId, {
  String catalog = catalogId,
}) =>
    {
      'version': 'v0.9',
      'createSurface': {'surfaceId': surfaceId, 'catalogId': catalog},
    };

/// An `updateComponents` envelope adding one `Text` component to [surfaceId].
Map<String, dynamic> textComponent(
  String surfaceId, [
  String componentId = 'c1',
  String text = 'hello',
]) =>
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {'id': componentId, 'component': 'Text', 'text': text},
        ],
      },
    };

/// An `updateComponents` envelope adding one `TextField` bound to [path].
Map<String, dynamic> textField(
  String surfaceId, {
  String componentId = 'email',
  String label = 'Email',
  String path = '/email',
  Map<String, dynamic> properties = const {},
}) =>
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': surfaceId,
        'components': [
          {
            'id': componentId,
            'component': 'TextField',
            'label': label,
            'value': {'path': path},
            ...properties,
          },
        ],
      },
    };

/// The JSON-string form of [envelope], which is what a chunk off the wire is.
String asChunk(Map<String, dynamic> envelope) => jsonEncode(envelope);

/// Completes [finished] when the framework reports an ingest event done, and
/// records every error the framework reports along the way.
class StreamFinishedObserver extends BlocSignalObserver {
  /// Creates an observer that completes [finished] when an ingest finishes.
  StreamFinishedObserver(this.finished);

  /// Completed once an `IngestStream` event's handler has resolved.
  final Completer<void> finished;

  /// Every error the framework reported while this observer was installed.
  final List<Object> errors = <Object>[];

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
  }

  @override
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) {
    if (event is IngestStream && !finished.isCompleted) finished.complete();
  }
}
