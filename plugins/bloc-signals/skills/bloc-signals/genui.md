# Generative UI & A2UI Protocol Integration (`bloc_signals_genui` & `bloc_signals_genui_flutter`)

[![pub package](https://img.shields.io/pub/v/bloc_signals_genui.svg)](https://pub.dev/packages/bloc_signals_genui)
[![pub points](https://img.shields.io/pub/points/bloc_signals_genui?color=2E8B57&label=pub%20points)](https://pub.dev/packages/bloc_signals_genui/score)
[![pub package](https://img.shields.io/pub/v/bloc_signals_genui_flutter.svg)](https://pub.dev/packages/bloc_signals_genui_flutter)
[![pub points](https://img.shields.io/pub/points/bloc_signals_genui_flutter?color=2E8B57&label=pub%20points)](https://pub.dev/packages/bloc_signals_genui_flutter/score)

This document defines the architectural patterns, streaming state machine lifecycles, Flutter surface rendering, and production integration guidelines for integrating `BlocSignal` with Google's **A2UI (Agent-to-User Interface)** protocol.

---

## 📦 Installation

For pure-Dart, CLI, server, or web applications:

```bash
dart pub add bloc_signals_genui bloc_signals
```

For Flutter applications:

```bash
flutter pub add bloc_signals_genui_flutter bloc_signals_genui bloc_signals_flutter
```

---

## 🌐 Protocol & Catalog Support (`a2ui_core: ^0.3.0`)

`bloc_signals_genui` and `bloc_signals_genui_flutter` target the published `a2ui_core: ^0.3.0` package on pub.dev and support both **A2UI v0.9** and **A2UI v1.0** wire protocols out of the box:
- **Default Catalogs**: `A2uiSurfaceBloc` registers `[StandardCatalog(), BasicCatalog.v0_9(), BasicCatalog.v1_0()]` by default, enabling seamless ingestion of legacy `minimal_catalog.json` surfaces, `v0.9` basic catalog surfaces, and `v1.0` basic catalog surfaces (including inline `components` and `dataModel` in `CreateSurfaceMessage` and `@path` data bindings).
- **Processor & Surface Model**: `A2uiSurfaceBloc.processor.model` exposes the `SurfaceGroupModel<ComponentApi>`, and `A2uiSurfaceBloc.close()` calls `processor.dispose()` to tear down the `RpcHandler` and all registered surfaces.
- **Bidirectional RPC (`RpcHandler`)**: `A2uiSurfaceBloc` wires `MessageProcessor.rpc` so agents can invoke client catalog functions via `CallRendererFunctionMessage` (emitting `RendererFunctionResponseMessage` over `outboundMessages` and `outboundListener`), and client code can call agent-side functions via `bloc.callAgentFunction(surfaceId, call, options: ...)` (awaiting `AgentFunctionResponseMessage` with timeout, error, and lifecycle cancellation safety).
- **Reactive `NodeResolver` Tree & Template `ChildList` Expansion**: `A2uiSurfaceView` mounts a `NodeResolver<ComponentApi>` over `surfaceReady.surface` when the surface's root component (`surface.rootId`, defaulting to `'root'`) is present. This expands data-driven template `ChildList` definitions (`{"componentId": "...", "path": "/items"}`) into distinct `ComponentNode` subtrees keyed by `node.instanceId` with per-item `DataContext` scoping (`node` and `dataPath` on `A2uiComponentContext`), handles `NodeState.pending`, `NodeState.cyclic`, and `NodeState.unknownType`, and falls back to heuristic root scanning for legacy unrooted surfaces.
- **`ResolvedBinding` & `WritableBinding` Unwrapping**: In `a2ui_core 0.3.0`, `GenericBinder.resolvedProps` wraps dynamic properties in `ResolvedBinding<Object?>` (or `WritableBinding<Object?>` for bound paths). `A2uiSurfaceView` and `safe_prop_parser.dart` (`unwrapBinding`, `asDouble`, `asInt`, `asString`, `asBool`, `extractChildId`, `extractChildIds`) unwrap these bindings automatically before passing property values to catalog widget builders, and `surface.resolveCatalog(component.catalog)` + `catalog.resolvedComponentSchema(component.type)` resolve component schemas per surface.
- **16 Standard `BasicCatalog` Widgets & `CheckRule` Validation UI**: `A2uiFlutterCatalog.standard()` (`registerStandardComponents`) registers 16 Material 3 builders covering `BasicCatalog` v0.9 and v1.0:
  - *Layout & Containers*: `Row` (`justify`/`mainAxisAlignment`, `align`/`crossAxisAlignment`), `Column` (`justify`/`mainAxisAlignment`, `align`/`crossAxisAlignment`), `List` (`direction`/`axis`, `align`, `children`), `Tabs` (`tabs: [{title, child}]`), `Modal` (`trigger`/`entryPointChild`, `content`/`contentChild`), `Card` (`child`, `children`, `elevation`), and `Divider` (`axis`: `horizontal` or `vertical`).
  - *Display*: `Text` (`variant`: `h1`..`h5`, `title`, `caption`, `body`, plus `style` fallback), `Icon` (maps standard A2UI icon names to `Icons.*` with `Icons.help_outline` fallback), and `Image` (`url`, `description`, `fit`, `variant` sizing, and offline `errorBuilder` fallback).
  - *Interactive Inputs & Validation*: `Button` (disabled when `componentContext.isValid == false` or `enabled == false`), `TextField` (`variant`: `shortText`, `longText`, `number`, `obscured`, plus `CheckRule` `errorText`), `CheckBox` (two-way boolean binding + `CheckRule` error subtitle), `ChoicePicker` (`mutuallyExclusive` and `multipleSelection` variants, `checkbox` and `chips` styles, two-way binding + `CheckRule` error text), `Slider` (clamped `[min, max]` range, two-way binding + `CheckRule` error text), and `DateTimeInput` (ISO 8601 `enableDate` / `enableTime` pickers, two-way binding + `CheckRule` error text).
  - *Two-Way Binding Helpers*: `A2uiComponentContext` exposes `isValid`, `validationErrors`, `validationResults`, `resolveBoundPath(propKey)`, and `updateBoundValue(propKey, newValue)` so interactive widgets synchronize `v0.9` `path` and `v1.0` `@path` bindings with `A2uiSurfaceBloc` in 0ms.

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
│  - Bounded FIFO history: maxResponseHistory  │
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
    maxResponseHistory: 100,
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
Never rebuild the entire surface when a user types into a form input or when a single bound path in `DataModel` updates. `A2uiSurfaceView` wraps each component in a reactive `_BoundComponentWidget` subscribed to its `GenericBinder.resolvedProps` signal, updating only the affected leaf widget in 0ms while preserving ancestor-path circular reference protection.

---

## 🛡️ Defensive Invariants & Verification

1. **Uncaught Stream Errors**: Never allow stream parse exceptions to crash the UI isolate. Route them through `onError()` on `BlocSignalObserver` and transition the surface to `SurfaceError`.
2. **Defensive Property Parsing**: Component properties received from LLMs can be malformed (for example strings where integers are expected). Use defensive type coercers (`SafePropParser`) with fallback defaults.
3. **Unknown Component Graceful Fallback**: When an agent streams an unrecognized component type, render an inline fallback container rather than throwing an exception.
4. **Bounded Action Response Replay (`maxResponseHistory`)**: Buffer submitted `A2uiActionResponse` items so late-mounted listeners on `actionResponses` do not drop responses. Capacity defaults to `maxResponseHistory: 100` with FIFO eviction of the oldest entry when full (or set `maxResponseHistory: 0` to disable replay buffering while preserving live broadcast delivery).
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

    final doneCompleter = Completer<A2uiSurfaceState>();
    final disposeSub = surfaceBloc.state.subscribe((s) {
      if ((s is SurfaceReady || s is SurfaceError) &&
          !doneCompleter.isCompleted) {
        doneCompleter.complete(s);
      }
    });

    try {
      surfaceBloc.add(IngestStream(monitoredStream));
      final finalState = await doneCompleter.future;

      // 3. Rollback guard on zero-chunk stream abort
      if (finalState is SurfaceError && chunkCount == 0) {
        emit(state.copyWith(
          messages: List<ChatMessage>.from(state.messages)..remove(userMsg),
          isStreaming: false,
          error: 'Streaming failed before response started. Please retry.',
        ));
        return;
      }

      emit(state.copyWith(isStreaming: false));
    } finally {
      disposeSub();
    }
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
