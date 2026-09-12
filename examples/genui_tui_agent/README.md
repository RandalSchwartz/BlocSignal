# genui_tui_agent

Interactive ANSI terminal client showcasing `bloc_signals_genui` with Google's A2UI protocol, inspired by the `agy-cli` terminal UX.

---

## ⚡ Features

- **ANSI Box TUI Rendering**: Visual component rendering for `Text`, `TextField`, `Button`, `Column`, and `Row` using `MinimalCatalog`.
- **Reactive State Log**: Synchronous live terminal updates matching `BlocSignal` emissions.
- **3-Tier Auth Resolution**:
  - **Tier 1**: Google Cloud ADC / OAuth.
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
