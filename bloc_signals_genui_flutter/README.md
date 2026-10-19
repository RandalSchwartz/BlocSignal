<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_genui_flutter" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_genui_flutter</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        Declarative Flutter surface views, Material 3 catalog widgets, and 0ms reactive two-way data bindings
        for <a href="https://pub.dev/packages/bloc_signals_genui">bloc_signals_genui</a> and Google's
        <strong>A2UI (Agent-to-User Interface)</strong> protocol.
      </p>
    </td>
  </tr>
</table>

<p align="center">
  <a href="https://pub.dev/packages/bloc_signals_genui_flutter/score"><img src="https://img.shields.io/pub/points/bloc_signals_genui_flutter?color=2E8B57&label=pub%20points" alt="pub points" /></a>
  <a href="https://pub.dev/packages/bloc_signals_genui_flutter"><img src="https://img.shields.io/pub/v/bloc_signals_genui_flutter.svg" alt="pub package" /></a>
  <a href="https://github.com/RandalSchwartz/BlocSignal/blob/main/LICENSE"><img src="https://img.shields.io/github/license/RandalSchwartz/BlocSignal.svg" alt="license" /></a>
</p>

`bloc_signals_genui_flutter` connects the pure-Dart `A2uiSurfaceBloc` state machine to Flutter's widget hierarchy via `A2uiSurfaceView`, `A2uiFlutterCatalog`, `A2uiComponentContext`, and `GenUiControllerAdapter`.

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

## ⚡ Key Features

- 🎨 **`A2uiSurfaceView`**: Declarative Flutter widget handling the complete `A2uiSurfaceState` lifecycle (`SurfaceInitial`, `SurfaceStreaming`, `SurfaceReady`, `SurfaceSubmitting`, and `SurfaceError`) with customizable builders and per-component error boundaries.
- 🧱 **`A2uiFlutterCatalog`**: Extensible component registry pre-populated with Material 3 widgets (`A2uiText`, `A2uiRow`, `A2uiColumn`, `A2uiButton`, `A2uiTextField`, `A2uiCard`, `A2uiDivider`) and immutable composition helpers (`copyWith`, `copyWithout`, `registerAll`).
- ⚡ **Granular Signal Bindings**: Each rendered component subscribes to its own `GenericBinder.resolvedProps` signal, updating leaf widgets in 0ms on `DataModel` or `@path` mutations without rebuilding parent containers.
- 🧭 **Multi-Surface & Split-Pane Support**: Pin `A2uiSurfaceView(bloc: bloc, surfaceId: '...')` to a specific surface or omit `surfaceId` to follow `bloc.activeSurfaceId` reactively across tabs and split views.
- 🛡️ **Defensive LLM Property Coercion**: Built-in `safe_prop_parser.dart` utilities (`unwrapBinding`, `asString`, `asInt`, `asDouble`, `extractChildId`, `extractChildIds`) protect the widget tree from malformed or stringified LLM JSON properties.

---

## 📦 Installation

Add `bloc_signals_genui_flutter` to your Flutter project:

```bash
flutter pub add bloc_signals_genui_flutter
```

Or declare it in your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  bloc_signals: ^1.7.0
  bloc_signals_flutter: ^1.3.4
  bloc_signals_genui: ^0.1.2
  bloc_signals_genui_flutter: ^0.1.1
  a2ui_core: ^0.3.0
```

---

## 🚀 Quick Start

### Rendering an Interactive A2UI Surface

```dart
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';

// Dart 3.5+ (Standard)
class AgentSurfaceScreen extends StatelessWidget {
  const AgentSurfaceScreen({
    required this.surfaceBloc,
    super.key,
  });

  final A2uiSurfaceBloc surfaceBloc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generative UI Surface')),
      body: A2uiSurfaceView(
        bloc: surfaceBloc,
        catalog: A2uiFlutterCatalog.standard(),
      ),
    );
  }
}

// Dart 3.13+ (Modern Primary Constructor)
class ModernAgentSurfaceScreen({
  required this.surfaceBloc,
  super.key,
}) extends StatelessWidget {
  final A2uiSurfaceBloc surfaceBloc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generative UI Surface')),
      body: A2uiSurfaceView(
        bloc: surfaceBloc,
        catalog: A2uiFlutterCatalog.standard(),
      ),
    );
  }
}
```

### Registering Custom Catalog Widgets

Extend `A2uiFlutterCatalog.standard()` using `copyWith` (or `register`) to bind domain-specific A2UI components to custom Flutter widgets while reading and mutating form signals through `A2uiComponentContext`:

```dart
final customCatalog = A2uiFlutterCatalog.standard().copyWith({
  'RatingSlider': (context, A2uiComponentContext componentContext) {
    final path = componentContext.props['path'] as String? ?? '/rating';
    final label = componentContext.props['label'] as String? ?? 'Rating';
    final current =
        (componentContext.props['value'] as num?)?.toDouble() ?? 3.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${current.toStringAsFixed(1)}'),
        Slider(
          min: 1,
          max: 5,
          divisions: 4,
          value: current,
          onChanged: (next) => componentContext.updateFormField(path, next),
        ),
      ],
    );
  },
});
```

---

## 🛡️ License

MIT License. See [LICENSE](https://github.com/RandalSchwartz/BlocSignal/blob/main/LICENSE) for details.
