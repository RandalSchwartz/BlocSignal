# bloc_signals_genui

[![pub points](https://img.shields.io/pub/points/bloc_signals_genui?color=2E8B57&label=pub%20points)](https://pub.dev/packages/bloc_signals_genui/score)
[![pub package](https://img.shields.io/pub/v/bloc_signals_genui.svg)](https://pub.dev/packages/bloc_signals_genui)
[![license](https://img.shields.io/github/license/RandalSchwartz/BlocSignal.svg)](https://github.com/RandalSchwartz/BlocSignal/blob/main/LICENSE)

Pure-Dart A2UI state machine and Generative UI runtime adapter for the **BlocSignal** ecosystem.

Bridges Google's **A2UI** (Agent-to-User Interface) declarative protocol specification with `BlocSignal` reactive architecture, providing streaming token ingestion, 0ms synchronous form updates, and structured agent callback integration.

---

## 🌐 Ecosystem Packages

The `BlocSignal` monorepo consists of 13 modular packages:

| Package | Version | Description |
| :--- | :--- | :--- |
| **`bloc_signals`** | [![pub](https://img.shields.io/pub/v/bloc_signals.svg)](https://pub.dev/packages/bloc_signals) | Core pure Dart reactive state primitives bridging BLoC & Signals |
| **`bloc_signals_flutter`** | [![pub](https://img.shields.io/pub/v/bloc_signals_flutter.svg)](https://pub.dev/packages/bloc_signals_flutter) | Flutter UI bindings, providers, builders, listeners & selectors |
| **`bloc_signals_bloc`** | [![pub](https://img.shields.io/pub/v/bloc_signals_bloc.svg)](https://pub.dev/packages/bloc_signals_bloc) | Classic BLoC 8/9 interop adapters & bidirectional event bridges |
| **`bloc_signals_riverpod`** | [![pub](https://img.shields.io/pub/v/bloc_signals_riverpod.svg)](https://pub.dev/packages/bloc_signals_riverpod) | Bidirectional Riverpod 2/3 interop adapters & provider extensions |
| **`bloc_signals_jaspr`** | [![pub](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr) | Jaspr web component integration and state binding for BlocSignal |
| **`bloc_signals_hydrate`** | [![pub](https://img.shields.io/pub/v/bloc_signals_hydrate.svg)](https://pub.dev/packages/bloc_signals_hydrate) | Automated synchronous local state persistence & hydration |
| **`bloc_signals_replay`** | [![pub](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay) | Undo & redo state history tracking for CubitSignal and BlocSignal |
| **`bloc_signals_otel`** | [![pub](https://img.shields.io/pub/v/bloc_signals_otel.svg)](https://pub.dev/packages/bloc_signals_otel) | OpenTelemetry tracing and span generation for state transitions |
| **`bloc_signals_devtools`** | [![pub](https://img.shields.io/pub/v/bloc_signals_devtools.svg)](https://pub.dev/packages/bloc_signals_devtools) | Universal DevTools telemetry observer using `dart:developer` |
| **`bloc_signals_test`** | [![pub](https://img.shields.io/pub/v/bloc_signals_test.svg)](https://pub.dev/packages/bloc_signals_test) | Declarative unit testing utilities (`blocSignalTest`) |
| **`bloc_signals_lint`** | [![pub](https://img.shields.io/pub/v/bloc_signals_lint.svg)](https://pub.dev/packages/bloc_signals_lint) | Custom analyzer lint rules & automated IDE quick-fixes |
| **`bloc_signals_genui`** | [![pub](https://img.shields.io/pub/v/bloc_signals_genui.svg)](https://pub.dev/packages/bloc_signals_genui) | Pure-Dart A2UI streaming state machine & Generative UI runtime adapter |
| **`bloc_signals_genui_flutter`** | [![pub](https://img.shields.io/pub/v/bloc_signals_genui_flutter.svg)](https://pub.dev/packages/bloc_signals_genui_flutter) | Declarative Flutter surface containers & A2UI catalog widget adapters |

---

## ⚡ Features

- **Decoupled Wire Protocol**: Ingests streaming A2UI chunk envelopes (`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`) via polymorphic message boundaries without hardcoding schema internals.
- **Race-Condition Shielding**: Protects in-flight token streams using `restartable()` concurrency transformers — any user re-prompt or interruption aborts obsolete streams immediately.
- **Sealed State Hierarchy**: Emits strictly typed presentation states (`SurfaceInitial`, `SurfaceStreaming`, `SurfaceReady`, `SurfaceSubmitting`, `SurfaceError`) for glitch-free UI rendering.
- **0ms Synchronous Form State**: Mutates underlying `DataModel` values synchronously within the current frame using batch updates.
- **Agent Tool Calling**: Captures user submissions into structured `A2uiActionResponse` payloads ready for upstream LLM conversation contexts.
- **Pure Dart & Zero Flutter Dependency**: Runs cleanly on backend servers, CLI tools, web workers, and mobile/desktop clients.

---

## 🚀 Getting Started

Add `bloc_signals_genui` to your `pubspec.yaml`:

```yaml
dependencies:
  bloc_signals: ^1.7.0
  bloc_signals_genui: ^1.0.0
  a2ui_core: ^0.3.0
```


### Basic Usage

```dart
import 'dart:async';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';

void main() async {
  // 1. Instantiate the surface bloc (defaults to MinimalCatalog)
  final bloc = A2uiSurfaceBloc();

  // 2. Reactively observe state transitions
  bloc.state.subscribe((state) {
    switch (state) {
      case SurfaceInitial():
        print('Awaiting A2UI payload...');
      case SurfaceStreaming(:final messageCount):
        print('Receiving chunks... ($messageCount messages)');
      case SurfaceReady(:final surfaceId, :final formValues):
        print('Surface $surfaceId ready for interaction!');
      case SurfaceSubmitting(:final actionName):
        print('Submitting action: $actionName');
      case SurfaceError(:final error):
        print('Error: $error');
    }
  });

  // 3. Listen for agent tool callbacks
  bloc.actionResponses.listen((response) {
    print('Action dispatched to agent: ${response.toToolResult()}');
  });

  // 4. Ingest an incoming stream from your LLM agent
  final stream = Stream<Map<String, dynamic>>.fromIterable([
    {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': 'user_profile',
        'catalogId': 'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json',
      },
    },
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': 'user_profile',
        'components': [
          {'id': 'txt_title', 'component': 'Text', 'text': 'User Settings'},
        ],
      },
    },
  ]);

  bloc.add(IngestStream(stream));
}
```

### Multi-Surface Navigation & Bounded LRU Eviction

`A2uiSurfaceBloc` decouples active navigation coordinates from per-surface content revisions:

- **Reactive Active Surface Signal**: Observe `bloc.activeSurfaceId` (`ReadonlySignal<String?>`) or read `bloc.activeSurfaceIdValue` (`String?`) synchronously in 0ms.
- **Zero-Rebuild Tab Switching**: Dispatch `SelectSurface(surfaceId: '...')` to switch the primary active surface without artificially incrementing any surface's `version` counter.
- **Explicit Surface Closure**: Dispatch `CloseSurface(surfaceId: '...')` (or ingest wire-level `DeleteSurfaceMessage`) to evict a surface, prune its action history and revision metadata, and automatically promote the most-recently-accessed surviving surface.
- **Bounded LRU Retention**: Configure `A2uiSurfaceBloc(maxSurfaces: 10)` to automatically evict the least-recently-used non-active surface when the active session exceeds the configured cap.

---

## 💡 Production Architecture: Safe Stream Wiring & Zero-Chunk Rollback

In LLM-driven generative UI architectures (for example Google Gemini or Firebase Genkit/AI), conversation turns strictly alternate between `user` and `model`. When an application optimistically adds a user message to chat history before initiating a stream, a failure *before any chunks arrive* (zero chunks) leaves a dangling user message. On retry, appending another user message creates two consecutive user turns, causing backend APIs to reject the request with `INVALID_ARGUMENT: Consecutive user turns are not allowed`.

To prevent this tripwire, monitor chunk arrivals and transactionally prune the optimistic user turn if the stream aborts with zero chunks:

```dart
Future<void> sendTurn({
  required String query,
  required A2uiSurfaceBloc surfaceBloc,
  required Stream<Map<String, dynamic>> Function() streamFactory,
}) async {
  final userTurn = ChatMessage.user(query);
  messages.add(userTurn);

  var chunkCount = 0;
  final monitoredStream = streamFactory().transform(
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
  final disposeSub = surfaceBloc.state.subscribe((state) {
    if ((state is SurfaceReady || state is SurfaceError) &&
        !doneCompleter.isCompleted) {
      doneCompleter.complete(state);
    }
  });

  surfaceBloc.add(IngestStream(monitoredStream));

  try {
    final finalState = await doneCompleter.future;
    if (finalState is SurfaceError && chunkCount == 0) {
      // Transactionally rollback optimistic user turn on zero-chunk stream failure
      messages.remove(userTurn);
    }
  } catch (_) {
    if (chunkCount == 0) {
      messages.remove(userTurn);
    }
  } finally {
    disposeSub();
  }
}
```

---

## 💻 CLI Showcase (`agy-cli` Style)

Explore the interactive terminal client in [`examples/genui_tui_agent`](https://github.com/RandalSchwartz/BlocSignal/tree/main/examples/genui_tui_agent):

```bash
# Run with zero-key offline mock simulation:
dart run examples/genui_tui_agent/bin/main.dart --mock

# Run with your Gemini API key:
GEMINI_API_KEY=your_key dart run examples/genui_tui_agent/bin/main.dart
```

---

## 🛡️ License

MIT License. See [LICENSE](https://github.com/RandalSchwartz/BlocSignal/blob/main/LICENSE) for details.
