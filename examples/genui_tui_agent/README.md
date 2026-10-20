# `genui_tui_agent`

Interactive ANSI terminal client showcasing [`bloc_signals_genui`](../../bloc_signals_genui) with Google's **A2UI v0.9/v1.0 Declarative Protocol**, inspired by the `agy-cli` terminal UX.

---

## ⚡ Features

- **Full 16-Component `BasicCatalog` v0.9/v1.0 ANSI Rendering**:
  - Visual terminal rendering for all 16 `BasicCatalog` components plus layout containers:
    - **Content & Media**: `Text`, `Icon`, `Image`, `Video`, `AudioPlayer`, `Divider`
    - **Interactive Controls**: `Button`, `TextField`, `CheckBox` (`[x]` / `[ ]`), `ChoicePicker` (`(o)` / `( )`), `Slider` (`[====----]`), `DateTimeInput`
    - **Containers & Navigation**: `Card`, `List` (with `ChildList` template path summary), `Tabs`, `Modal`, `Column`, `Row`
- **Declarative `CheckRule` Status Annotations**:
  - Evaluates component `checks` (`CheckRule`) against the live `SurfaceContext` and renders inline validation warnings (`! <message>`) on `TextField` inputs and `[DISABLED: <message>]` indicators on `Button` controls when validation rules fail.
- **Dynamic `NodeResolver` List Template Expansion**:
  - Recursively renders `NodeResolver` trees, including dynamic `ChildList` templates (`children: {'componentId': '...', 'path': '/items'}`) expanded across `DataModel` list entries.
- **Reactive State Log**:
  - Synchronous live terminal updates matching `BlocSignal` emissions (`SurfaceStreaming`, `SurfaceReady`, `SurfaceSubmitting`, `SurfaceError`).
- **3-Tier Auth Resolution**:
  - **Tier 1**: Google Cloud ADC / OAuth (`gcloud auth application-default print-access-token`).
  - **Tier 2**: `GEMINI_API_KEY` from environment.
  - **Tier 3**: Zero-key offline simulation via `--mock`.

---

## 🚀 Running the Showcase

```bash
# Offline simulation mode (zero credentials required):
dart run bin/main.dart --mock

# With Gemini API key:
GEMINI_API_KEY=your_key dart run bin/main.dart
```

---

## 🧪 Automated Testing

```bash
dart test
```

---

## 🏗️ Production Architecture & Security Considerations ("In Real Production, X Would Be Y")

To keep this CLI showcase self-contained and runnable offline with `--mock`, several production infrastructure concerns are simplified locally:

| Domain | Reference Example (Local CLI Showcase) | Production Architecture ("In Real Production...") |
| :--- | :--- | :--- |
| **Credential Storage & Auth** | Reads `GEMINI_API_KEY` from environment variables or invokes `gcloud auth application-default print-access-token` locally. | **Short-Lived OAuth Tokens & Secret Managers**: Production CLI tools authenticate via OAuth 2.0 device/PKCE flows, store refresh tokens in the OS keychain (macOS Keychain, Linux Secret Service, or Windows Credential Manager), and route requests through an authenticated gateway. |
| **Interactive Terminal Input** | Simulates form mutations and action submissions deterministically in `--mock` mode or via single-line prompt input. | **Full Raw-Mode TUI Event Loop**: Production terminal clients use raw-mode keystroke handling (arrow keys, Tab focus traversal, Spacebar toggle for `CheckBox` and `ChoicePicker`, and Escape for `Modal` dismissal) bound directly to `UpdateFormField` and `SubmitAction`. |
| **Action & RPC Transport** | Prints `A2uiActionResponse` payloads to stdout and completes actions locally via `CompleteAction`. | **Bidirectional Agent Tool & RPC Pipeline**: Action payloads (`actionResponses`) and `outboundMessages` (`callFunction`) are transmitted over persistent SSE or WebSocket streams to the remote agent orchestrator to trigger real tool executions. |
