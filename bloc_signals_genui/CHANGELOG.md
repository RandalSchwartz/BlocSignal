# Changelog

All notable changes to `bloc_signals_genui` will be documented in this file.

## 0.1.0

- Initial release of `bloc_signals_genui`.
- Pure-Dart `A2uiSurfaceBloc` state container bridging Google's A2UI protocol with `BlocSignal`.
- Sealed presentation state machine: `SurfaceInitial`, `SurfaceStreaming`, `SurfaceReady`, `SurfaceSubmitting`, `SurfaceError`.
- Polymorphic event envelopes: `IngestStream`, `ProcessMessage`, `ProcessJsonMessage`, `ProcessMessages`, `UpdateFormField`, `SubmitAction`, `ResetSurface`.
- Built-in `restartable()` concurrency protection for streaming chunk ingestion.
- Zero-latency synchronous form mutations on `DataModel`.
- Formatted `A2uiActionResponse` agent tool calling callbacks.
