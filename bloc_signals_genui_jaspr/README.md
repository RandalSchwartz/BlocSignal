<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_genui_jaspr" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_genui_jaspr</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        Jaspr web component bindings, HTML DOM catalog adapters, and 0ms reactive two-way data bindings
        for <a href="https://pub.dev/packages/bloc_signals_genui">bloc_signals_genui</a> and Google's
        <strong>A2UI (Agent-to-User Interface)</strong> protocol.
      </p>
    </td>
  </tr>
</table>

<p align="center">
  <a href="https://pub.dev/packages/bloc_signals_genui_jaspr/score"><img src="https://img.shields.io/pub/points/bloc_signals_genui_jaspr?color=2E8B57&label=pub%20points" alt="pub points" /></a>
  <a href="https://pub.dev/packages/bloc_signals_genui_jaspr"><img src="https://img.shields.io/pub/v/bloc_signals_genui_jaspr.svg" alt="pub package" /></a>
  <a href="https://github.com/RandalSchwartz/BlocSignal/blob/main/LICENSE"><img src="https://img.shields.io/github/license/RandalSchwartz/BlocSignal.svg" alt="license" /></a>
</p>

`bloc_signals_genui_jaspr` connects the pure-Dart `A2uiSurfaceBloc` state machine to Jaspr's web component hierarchy via `A2uiSurfaceView`, `A2uiJasprCatalog`, `A2uiComponentContext`, and standard DOM catalog components.

---

## ⚡ Key Features

- 🎨 **`A2uiSurfaceView`**: Reactive Jaspr web component handling the complete `A2uiSurfaceState` lifecycle (`SurfaceInitial`, `SurfaceStreaming`, `SurfaceReady`, `SurfaceSubmitting`, and `SurfaceError`) with customizable builders and per-component error boundaries.
- 🧱 **`A2uiJasprCatalog`**: Extensible component registry pre-populated with standard DOM components covering core A2UI primitives (`Text`, `Row`, `Column`, `Card`, `Divider`, `Button`, and `TextField`) alongside immutable composition helpers (`copyWith`, `copyWithout`, `registerAll`).
- ✅ **Reactive `CheckRule` Validation UI**: Automatically surfaces `GenericBinder` validation state (`isValid`, `validationErrors`, `validationResults`) across form inputs and disables button submissions when validation rules fail.
- ⚡ **Granular Signal Bindings & Two-Way Sync**: Each rendered component subscribes to its own resolved properties and writes two-way input mutations via `A2uiComponentContext.updateBoundValue`, updating leaf DOM elements and `A2uiSurfaceBloc` form data in 0ms on data changes without tearing down parent containers.
- 🧭 **Multi-Surface & Split-Pane Support**: Pin `A2uiSurfaceView(bloc: bloc, surfaceId: '...')` to a specific surface or omit `surfaceId` to follow `bloc.activeSurfaceId` reactively across tabs and split views.
- 🛡️ **Defensive LLM Property Coercion**: Built-in `safe_prop_parser.dart` utilities (`unwrapBinding`, `asString`, `asInt`, `asDouble`, `asBool`, `extractChildId`, `extractChildIds`) protect the DOM tree from malformed or stringified LLM JSON properties.
