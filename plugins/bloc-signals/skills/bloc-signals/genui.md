# Generative UI & A2UI Protocol Integration (`bloc_signals_genui` & `bloc_signals_genui_flutter`)

This document defines the architectural patterns, streaming state machine lifecycles, Flutter surface rendering, and developer preview guidelines for integrating `BlocSignal` with Google's **A2UI (Agent-to-User Interface)** protocol.

---

## 🚫 Pre-Release & Unpublished Status

> [!IMPORTANT]
> **Git-Only Pre-Release**: `bloc_signals_genui` and `bloc_signals_genui_flutter` currently depend on an unreleased, git-overridden fork of Google's `a2ui_core` package (`https://github.com/RandalSchwartz/a2ui.git` branch `fix/widen-preact-signals-a2ui-core`).
>
> Because pub.dev strictly rejects packages with git dependencies or dependency overrides:
> - Do NOT attempt to publish these packages to pub.dev (`flutter pub publish` is forbidden on them).
> - Do NOT add `pub.dev` badges or links to these packages in public documentation or readmes.
> - Depend on them in client applications via path or git workspace dependencies.

---

## 🧠 Architectural Overview

In Google's **A2UI / GenUI** streaming protocol, AI models (such as Google Gemini) stream declarative JSON component trees (surfaces, layouts, interactive forms, and buttons) via Server-Sent Events (SSE) or WebSockets.

`BlocSignal` provides the architectural spine for this flow:
1. **At the Edge (`bloc_signals_genui`)**: A pure-Dart state container (`A2uiSurfaceBloc`) buffers streaming chunks, runs concurrency transformers (`restartable()`), and maps JSON into strongly-typed component models.
2. **In the Core**: 0ms reactive form signals (`fieldSignals`) track user inputs in real time without causing parent surface re-renders.
3. **In the View (`bloc_signals_genui_flutter`)**: `A2uiSurfaceView` renders the declarative surface with `A2uiFlutterCatalog` component mappings.
4. **Upstream Action Dispatch**: Submitting forms bundles user inputs into an `A2uiActionResponse` returned to the agent tool execution pipeline.

```
┌──────────────────────────────────────────────┐
│            LLM / Streaming Backend           │
│        (SSE or WebSocket A2UI Stream)        │
└──────────────────────┬───────────────────────┘
                       │ 1. Streaming JSON Chunks
                       ▼
┌──────────────────────────────────────────────┐
│              A2uiSurfaceBloc                 │
│  - Concurrency control via restartable()     │
│  - State: SurfaceInitial -> Streaming        │
│           -> SurfaceReady -> Submitting      │
│  - Holds fieldSignals for 0ms form updates   │
│  - Monotonic _surfaceVersion on every chunk  │
└──────────────────────┬───────────────────────┘
                       │ 2. Synchronous Signals
                       ▼
┌──────────────────────────────────────────────┐
│       A2uiSurfaceView (Flutter Tree)         │
│  - Maps catalog components to widgets        │
│  - context.select for surgical field rebuild │
│  - Error boundaries wrap unknown components  │
└──────────────────────────────────────────────┘
```

---

## 📦 Core State Machine: `A2uiSurfaceBloc`

### Surface State Lifecycle

The surface state hierarchy is modeled as a sealed class `A2uiSurfaceState`:
- **`A2uiSurfaceInitial`**: Initial blank state before any stream connection.
- **`A2uiSurfaceStreaming`**: Chunks are actively arriving over SSE. Contains current partial surface AST, streaming text buffer, and a monotonic `version` counter.
- **`A2uiSurfaceReady`**: Stream completed successfully. Surface AST is validated and interactive.
- **`A2uiSurfaceSubmitting`**: User triggered a form or action button. Contains the action payload and loading feedback.
- **`A2uiSurfaceError`**: Stream parsing error or network failure, routed through `onError()`.

### Handling Streaming Chunks with Monotonic Versions
Because state updates propagate synchronously in `BlocSignal` and transitions are de-duplicated by default, streaming partial JSON chunks might appear identical to previous chunks if intermediate keys have not changed.

To ensure the widget tree reliably receives every chunk without deduplication drops:
```dart
// A2uiSurfaceState includes a monotonic surfaceVersion
class A2uiSurfaceStreaming extends A2uiSurfaceState {
  const A2uiSurfaceStreaming({
    required this.surface,
    required this.version,
  });

  final A2uiSurface surface;
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is A2uiSurfaceStreaming &&
          version == other.version &&
          surface == other.surface;

  @override
  int get hashCode => Object.hash(surface, version);
}
```

---

## 🎨 Flutter Rendering with `A2uiSurfaceView`

### Surface View Setup
Inject the `A2uiSurfaceBloc` via `BlocSignalProvider` and display `A2uiSurfaceView`:

```dart
BlocSignalProvider<A2uiSurfaceBloc>(
  create: (context) => A2uiSurfaceBloc(
    catalog: A2uiFlutterCatalog.standard(),
  )..add(const ConnectA2uiStreamEvent(streamUrl: 'https://api.example.com/stream')),
  child: const Scaffold(
    body: A2uiSurfaceView(),
  ),
);
```

### Granular Form Field Reactivity
Never rebuild the entire surface when a user types into a form input. `A2uiSurfaceBloc` maintains isolated `fieldSignals` for each input component:
```dart
// Surgical field update: only the input widget updates
final fieldSignal = surfaceBloc.getFieldSignal('passenger_name');
```

---

## 🛡️ Defensive Invariants & Verification

1. **Uncaught Stream Errors**: Never allow stream parse exceptions to crash the UI isolate. Route them through `onError()` on `BlocSignalObserver` and transition the surface to `A2uiSurfaceError`.
2. **Defensive Property Parsing**: Component properties received from LLMs can be malformed (for example strings where integers are expected). Use defensive type coercers (`SafePropParser`) with fallback defaults.
3. **Unknown Component Graceful Fallback**: When an agent streams an unrecognized component type, render an inline fallback container (for example `A2uiFallbackWidget`) rather than throwing an exception.
4. **Action Response Replay**: Buffer action responses so late-mounted listeners do not drop responses.
5. **Submission Recovery & Lifecycle Completion**: Action submissions (`SubmitAction`) transition the state to `SurfaceSubmitting`. If an agent action fails, encounters a network timeout, or completes without streaming a new UI tree, the surface must transition back to `SurfaceReady` via `CancelSubmission({String? error, String? surfaceId})` or `CompleteAction({String? error, String? surfaceId})`. This dismisses the `ModalBarrier` overlay, preserves all active form inputs and component models, sets `isValid: false`, and renders error notifications via `validationErrorsBuilder`.
