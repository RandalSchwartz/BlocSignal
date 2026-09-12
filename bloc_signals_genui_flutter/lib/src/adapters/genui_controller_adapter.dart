import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';

/// An adapter bridge that connects [A2uiSurfaceBloc] to codebases or
/// architectures designed around external Generative UI controllers.
///
/// Dispatches outgoing tool call results and incoming messages through a clean,
/// stream-based interface.
class GenUiControllerAdapter {
  /// Creates a [GenUiControllerAdapter] wrapping [surfaceBloc].
  GenUiControllerAdapter(this.surfaceBloc);

  /// The underlying [A2uiSurfaceBloc] orchestrating generative state.
  final A2uiSurfaceBloc surfaceBloc;

  /// Stream of user interaction submissions packaged as [A2uiActionResponse]s.
  Stream<A2uiActionResponse> get actionResponses => surfaceBloc.actionResponses;

  /// Current surface state value.
  A2uiSurfaceState get state => surfaceBloc.value;

  /// Ingests an incoming message stream.
  void ingestStream(Stream<dynamic> stream) {
    surfaceBloc.add(IngestStream(stream));
  }

  /// Ingests a raw JSON envelope.
  void processJson(Map<String, dynamic> json) {
    surfaceBloc.add(ProcessJsonMessage(json));
  }

  /// Submits an action manually.
  void submitAction(
    String actionName, {
    required String sourceComponentId,
    String? surfaceId,
    Map<String, dynamic> context = const {},
  }) {
    surfaceBloc.add(
      SubmitAction(
        actionName: actionName,
        sourceComponentId: sourceComponentId,
        surfaceId: surfaceId,
        context: context,
      ),
    );
  }

  /// Resets the surface.
  void reset([String? surfaceId]) {
    surfaceBloc.add(ResetSurface(surfaceId: surfaceId));
  }
}

/// Extension on [A2uiSurfaceBloc] providing convenient access to
/// [GenUiControllerAdapter].
extension GenUiControllerAdapterX on A2uiSurfaceBloc {
  /// Wraps this bloc with a [GenUiControllerAdapter].
  GenUiControllerAdapter toGenUiController() => GenUiControllerAdapter(this);
}
