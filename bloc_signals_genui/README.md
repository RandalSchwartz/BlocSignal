# bloc_signals_genui

[![pub points](https://img.shields.io/pub/points/bloc_signals_genui?color=2E8B57&label=pub%20points)](https://pub.dev/packages/bloc_signals_genui/score)
[![pub package](https://img.shields.io/pub/v/bloc_signals_genui.svg)](https://pub.dev/packages/bloc_signals_genui)
[![license](https://img.shields.io/github/license/RandalSchwartz/BlocSignal.svg)](https://github.com/RandalSchwartz/BlocSignal/blob/main/LICENSE)

Pure-Dart A2UI state machine and Generative UI runtime adapter for the **BlocSignal** ecosystem.

Bridges Google's **A2UI** (Agent-to-User Interface) declarative protocol specification with `BlocSignal` reactive architecture, providing streaming token ingestion, 0ms synchronous form updates, and structured agent callback integration.

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
  bloc_signals: ^1.4.0
  bloc_signals_genui: ^0.1.0
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
