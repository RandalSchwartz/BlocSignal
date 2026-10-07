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
│  - Reactive activeSurfaceId ReadonlySignal   │
│  - Per-surface _surfaceVersions counters     │
│  - Bounded LRU eviction via maxSurfaces      │
└──────────────────────┬───────────────────────┘
                       │ 2. Synchronous Signals
                       ▼
┌──────────────────────────────────────────────┐
│       A2uiSurfaceView (Flutter Tree)         │
│  - Maps catalog components to widgets        │
│  - Subscribes to activeSurfaceId when null   │
│  - Error boundaries wrap unknown components  │
└──────────────────────────────────────────────┘
```

---

## 📦 Core State Machine: `A2uiSurfaceBloc`

### Surface State Lifecycle

The surface state hierarchy is modeled as a sealed class `A2uiSurfaceState`:
- **`SurfaceInitial`**: Initial blank state before any stream connection or after all surfaces are closed/reset.
- **`SurfaceStreaming`**: Chunks are actively arriving over SSE, or a surface has been created but has not yet received components.
- **`SurfaceReady`**: Surface has populated components and is interactive. Carries a per-surface monotonic `version` counter.
- **`SurfaceSubmitting`**: User triggered a form or action button. Contains the action payload and loading feedback.
- **`SurfaceError`**: Stream parsing error, missing surface target, or network failure, routed through `onError()`.

### Per-Surface Content Revisions & Reactive Navigation Coordinates
Because state updates propagate synchronously in `BlocSignal` and transitions are de-duplicated by default, `A2uiSurfaceBloc` separates **navigation coordinates** from **per-surface content revisions** (`SCAR-GENUI-7`):
- **Navigation Coordinates (`activeSurfaceId`)**: `A2uiSurfaceBloc.activeSurfaceId` exposes a `ReadonlySignal<String?>` (with `activeSurfaceIdValue` for raw `String?` access) that updates synchronously in 0ms whenever a surface is created, selected via `SelectSurface`, closed via `CloseSurface`, deleted via `DeleteSurfaceMessage`, or reset via `ResetSurface`.
- **Per-Surface Content Revisions (`_surfaceVersions`)**: Each surface tracks its own monotonic version counter in `_surfaceVersions[surfaceId]`. Content mutations (`CreateSurfaceMessage`, `UpdateComponentsMessage`, `UpdateDataModelMessage`, `UpdateFormField`, `StreamCompleted`, `CancelSubmission`, `CompleteAction`, or validation failures) increment only the targeted surface's version. Switching active surfaces via `SelectSurface` never increments any surface's version, preventing redundant `_SurfaceTreeRenderer` binder reconciliation in split-pane or tabbed views.

```dart
// SurfaceReady carries the per-surface content version
final ready = surfaceBloc.getSurfaceReady('surf_main');
final activeId = surfaceBloc.activeSurfaceId.value;
```

---

## 🎨 Flutter Rendering with `A2uiSurfaceView`

### Surface View Setup
Inject the `A2uiSurfaceBloc` via `BlocSignalProvider` and display `A2uiSurfaceView`:

```dart
BlocSignalProvider<A2uiSurfaceBloc>(
  create: (context) => A2uiSurfaceBloc(
    maxSurfaces: 10,
  )..add(IngestStream(stream)),
  child: Scaffold(
    body: A2uiSurfaceView(
      bloc: surfaceBloc,
      catalog: A2uiFlutterCatalog.standard(),
    ),
  ),
);
```

### Granular Form Field Reactivity
Never rebuild the entire surface when a user types into a form input. `A2uiSurfaceView` binds each component to `a2ui_core`'s reactive `DataModel` via per-component `_ComponentReactiveBinder` instances, updating only the affected leaf widget in 0ms.

---

## 🛡️ Defensive Invariants & Verification

1. **Uncaught Stream Errors**: Never allow stream parse exceptions to crash the UI isolate. Route them through `onError()` on `BlocSignalObserver` and transition the surface to `SurfaceError`.
2. **Defensive Property Parsing**: Component properties received from LLMs can be malformed (for example strings where integers are expected). Use defensive type coercers (`SafePropParser`) with fallback defaults.
3. **Unknown Component Graceful Fallback**: When an agent streams an unrecognized component type, render an inline fallback container rather than throwing an exception.
4. **Action Response Replay**: Buffer action responses so late-mounted listeners do not drop responses.
5. **Submission Recovery & Lifecycle Completion**: Action submissions (`SubmitAction`) transition the state to `SurfaceSubmitting`. If an agent action fails, encounters a network timeout, or completes without streaming a new UI tree, the surface must transition back to `SurfaceReady` via `CancelSubmission({String? error, String? surfaceId})` or `CompleteAction({String? error, String? surfaceId})`. This dismisses the `ModalBarrier` overlay, preserves all active form inputs and component models, sets `isValid: false`, and renders error notifications via `validationErrorsBuilder`.
6. **Multi-Surface Navigation, Split-Pane Isolation & Bounded LRU Eviction (`SCAR-GENUI-7`)**: An agent may stream multiple distinct surfaces (for example conversational sidebars, main content panes, or modal sheets) over the same connection. Surfaces register dynamically in `availableSurfaceIds`.
   - Dispatch `SelectSurface({required String surfaceId})` (or call `componentContext.selectSurface(id)` / `adapter.selectSurface(id)`) to switch `bloc.activeSurfaceId` synchronously without incrementing surface content versions.
   - Pass `surfaceId:` to `A2uiSurfaceView(bloc: bloc, surfaceId: '...')` to pin a viewport to a specific surface in split panes or tabs; when `surfaceId` is `null`, `A2uiSurfaceView` automatically subscribes to `bloc.activeSurfaceId`.
   - Dispatch `CloseSurface({required String surfaceId})` (or call `componentContext.closeSurface([id])` / `adapter.closeSurface(id)`) or ingest wire-level `DeleteSurfaceMessage` to evict a surface, prune its `_responseHistory`, `_surfaceVersions`, and LRU entries, and automatically promote the most-recently-accessed surviving surface.
   - Pass `maxSurfaces:` to `A2uiSurfaceBloc(maxSurfaces: k)` to bound memory growth in long-running sessions by automatically evicting the least-recently-used non-active surface.
7. **Zero-Chunk Stream Aborts & Dangling Turn Prevention (`SCAR-GENUI-3`)**: In conversational LLM architectures, an optimistic user turn is added to chat history before initiating the streaming request. If the stream fails or disconnects before any chunks arrive (`chunkCount == 0`), the client must transactionally roll back / prune the optimistic user message from chat history. Failing to prune leaves two consecutive user turns in history on retry, which strictly violates the turn-alternation schemas of Google Generative AI and Firebase AI/Genkit, throwing `INVALID_ARGUMENT: Consecutive user turns are not allowed`.

---

## 🔄 Zero-Chunk LLM Stream Error Handling & History Rollback

### The Dangling User Turn Tripwire

In modern conversational generative UI applications (for example using Google Gemini via `google_generative_ai`, Firebase AI / Genkit, or Anthropic Claude), dialog turns strictly alternate between `user` and `model`/`assistant`. 

To provide instantaneous visual feedback, applications optimistically append the user message to their local chat history state before awaiting the streaming LLM response:

```dart
// 1. Optimistic append
final userMessage = ChatMessage.user(prompt);
emit(state.copyWith(messages: [...state.messages, userMessage]));

// 2. Stream generation
final stream = geminiModel.generateContentStream(prompt);
surfaceBloc.add(IngestStream(stream));
```

### The Failure Mode: Consecutive User Turns

If the network connection drops, API credentials fail, or rate limits trigger **before any chunks arrive** (`chunkCount == 0`), no model/assistant response is ever generated.

If the application fails to prune the unfulfilled user message, the local history state retains a trailing user message. When the user taps a "Retry" button or sends another message, a second user message is appended consecutively:

```
Turn 1: user: "Find flights to Tokyo" (failed before any chunks arrived)
Turn 2: user: "Find flights to Tokyo" (retry)
```

Sending this payload to Google Generative AI or Firebase Genkit triggers an immediate fatal argument rejection:

```text
INVALID_ARGUMENT: Consecutive user turns are not allowed
```

### Transactional Rollback Pattern

While `A2uiSurfaceBloc` deliberately remains decoupled from vendor LLM SDKs and chat history persistence (the spine), the edge/repository layer (the periphery) must guard against zero-chunk failures using a transactional rollback pattern:

```dart
Future<void> sendPrompt(String prompt) async {
  final userMsg = ChatMessage.user(prompt);
  
  // 1. Optimistically append user message
  emit(state.copyWith(
    messages: [...state.messages, userMsg],
    isStreaming: true,
  ));

  var chunkCount = 0;
  try {
    final rawStream = llmService.streamA2ui(prompt);
    
    // 2. Monitor chunk arrival count
    final monitoredStream = rawStream.transform(
      StreamTransformer<Map<String, dynamic>,
          Map<String, dynamic>>.fromHandlers(
        handleData: (chunk, sink) {
          chunkCount++;
          sink.add(chunk);
        },
        handleError: (error, stackTrace, sink) {
          sink.addError(error, stackTrace);
        },
      ),
    );

    surfaceBloc.add(IngestStream(monitoredStream));
    await surfaceBloc.stream.firstWhere(
      (s) => s is SurfaceReady || s is SurfaceError,
    );

    // 3. Rollback guard on zero-chunk stream abort
    if (surfaceBloc.stateValue is SurfaceError && chunkCount == 0) {
      emit(state.copyWith(
        messages: List<ChatMessage>.from(state.messages)..remove(userMsg),
        isStreaming: false,
        error: 'Streaming failed before response started. Please retry.',
      ));
      return;
    }

    emit(state.copyWith(isStreaming: false));
  } catch (error) {
    if (chunkCount == 0) {
      // Transactionally prune dangling user turn
      emit(state.copyWith(
        messages: List<ChatMessage>.from(state.messages)..remove(userMsg),
        isStreaming: false,
        error: error.toString(),
      ));
    }
  }
}
```

By ensuring the dangling user turn is pruned if zero chunks were delivered, subsequent retries seamlessly append a single user turn, preserving strict turn alternation.
