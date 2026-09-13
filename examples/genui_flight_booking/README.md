# `genui_flight_booking` (Phase 3 Reference Application)

An interactive, multi-turn Flutter reference application demonstrating **Generative UI** driven by Google's **A2UI Declarative Protocol**, [`bloc_signals_genui`](../../bloc_signals_genui), and [`bloc_signals_genui_flutter`](../../bloc_signals_genui_flutter).

Part of the **Generative UI Epic (#206)** and **Phase 3 (#258)**.

---

## 🎯 Architectural Highlights

- **Dual Execution Modes**:
  - **Offline Mock Simulation Mode**: Deterministic zero-key offline streamer (`FlightMockStreamer`) for rapid local development, automated widget testing, and CI smoke verification.
  - **Live Gemini Stream Mode**: Connects directly to Google Gemini via API key (`--dart-define=GEMINI_API_KEY=...`) streaming declarative A2UI JSON over Server-Sent Events (SSE).
- **Mixed Surface & Chat Experience**:
  - Conversational chat stream on top maintaining user/assistant message turns.
  - Dynamic interactive Generative UI surface (`A2uiSurfaceView`) embedded below, reacting synchronously to user form inputs.
- **Granular Form Reactivity & Real-time Calculations**:
  - Live reactive pricing calculations driven by BlocSignal signal graph reactions as passengers toggle seat tiers (`Economy: $420`, `Premium: $650`, `Business: $1,250`) and add-on amenities (luggage, priority boarding) without frame drops or entire-screen re-renders.
- **Action Submission Loop**:
  - Submits flight booking actions (`selectFlight`, `proceedBooking`, `restartSearch`) back to the agent tool pipeline, initiating the next turn.

---

## 🚀 Running the Reference Application

### 1. Offline Mock Simulation (Zero-Key Local Development)

Run the application with offline simulation:

```bash
cd examples/genui_flight_booking
flutter run
```

### 2. Live Gemini Execution (with API Key)

Run the application connected to Gemini 1.5 Flash:

```bash
cd examples/genui_flight_booking
flutter run --dart-define=GEMINI_API_KEY="YOUR_GEMINI_API_KEY"
```

---

## 🧪 Automated Testing

Run the automated widget and cubit test suite:

```bash
flutter test
```

---

## 🏗️ Production Architecture Considerations ("In Real Production, X Would Be Y")

To keep this reference application lightweight, deterministic, and runnable without mandatory cloud infrastructure or API keys, several real-world production layers are simulated locally in the client. When building an enterprise application based on this pattern, consider the following architectural differences:

| Domain | Reference Example (Local Simulation) | Production Architecture ("In Real Production...") |
| :--- | :--- | :--- |
| **Agent / LLM Gateway** | Client connects directly to Gemini via `--dart-define=GEMINI_API_KEY` or uses local mock streams. | **Backend-for-Frontend (BFF) Gateway**: Clients connect to an authenticated backend proxy (via WebSockets or SSE at `/api/chat/stream`). The backend securely holds model API keys, applies rate limiting, enforces enterprise guardrails, and manages agent orchestrators (for example LangGraph, Cloud Run). |
| **Tool Execution & Action Loop** | `FlightAssistantCubit` listens to `surfaceBloc.actionResponses` and directly swaps local mock streams. | **Server-Side Agent Tool Pipeline**: Action submissions (`selectFlight`, `proceedBooking`) are posted as agent tool call responses to the remote orchestrator. The agent executes real backend services (for example Amadeus, Sabre, Stripe payments) before generating the next A2UI surface stream. |
| **Pricing & Business Rules** | `calculatedTotal` is dynamically computed on the client via reactive BlocSignal derived state for immediate UI feedback. | **Authoritative Server Pricing & Inventory Locks**: Client-side reactive pricing provides instant UX previews, but final ticketing fares, taxes, currency conversions, and seat inventory locks must be authoritatively computed and cryptographically validated on the server at checkout. |
| **Session Persistence & Recovery** | Chat history and active surface state live ephemerally in client memory (`FlightAssistantState`). | **Hydrated State & Multi-Device Sync**: Use `HydratedCubitSignal` (from `bloc_signals_hydrate`) or local encrypted storage (SQLite / Hive) to persist conversation state, active surface tokens, and draft form inputs across app restarts and network interruptions. |
| **Surface History in Chat** | Single active surface container replaces the previous surface as the conversation progresses. | **Multi-Surface Timeline Stacking**: Chat histories preserve prior surfaces in disabled, read-only snapshot mode (for example, keeping the chosen flight summary visible higher in the chat scrollback while the new passenger form is active below). |
| **Form Validation & Schemas** | Loose JSON string paths (for example `/passenger/name`) with fallback heuristic mapping in the cubit. | **Typed Schema Contracts**: Surface layouts and form inputs conform to strict JSON Schema or Protobuf contracts with client-side field validation (regex, passport rules, phone masking) before enabling action dispatchers. |

