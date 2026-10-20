# `genui_flight_booking` (Phase 3 Reference Application)

An interactive, multi-turn Flutter reference application demonstrating **Generative UI** driven by Google's **A2UI v0.9/v1.0 Declarative Protocol**, [`bloc_signals_genui`](../../bloc_signals_genui), and [`bloc_signals_genui_flutter`](../../bloc_signals_genui_flutter).

Part of the **Generative UI Epic (#206)** and **Phase 3 (#258 / #373)**.

---

## 🎯 Architectural Highlights

- **Dual Execution Modes**:
  - **Offline Mock Simulation Mode**: Deterministic zero-key offline streamer (`FlightMockStreamer`) targeting `BasicCatalog.v0_9()` (`https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json`) for rapid local development, automated widget testing, and CI smoke verification.
  - **Live Gemini Stream Mode**: Connects directly to Google Gemini via API key (`--dart-define=GEMINI_API_KEY=...`) streaming declarative A2UI JSON over Server-Sent Events (SSE).
- **Dynamic `NodeResolver` List Templates**:
  - Flight discovery cards are rendered from a single `card_flight` template expanded across `/flights` via `children: {'componentId': 'card_flight', 'path': '/flights'}` with relative data bindings (`airline`, `flightNumber`, `origin`, `duration`, `destination`, `priceDisplay`).
- **Pure-A2UI Customization Form (`BasicCatalog` v0.9/v1.0 Widgets)**:
  - Streams declarative `TextField` (`/passenger/name`), `DateTimeInput` (`/booking/departureDate`), `ChoicePicker` (`/booking/tier` with `chips` variant), and `CheckBox` (`/addons/checkedLuggage`, `/addons/priorityBoarding`) directly inside the A2UI surface without any duplicate native widget chrome.
- **Declarative `CheckRule` Validation (`checks`)**:
  - Enforces non-empty passenger name validation via `checks: [{'call': 'required', 'args': {'value': {'path': '/passenger/name'}}, 'message': 'Passenger full name is required before booking'}]` on both the `TextField` (rendering inline error text) and the `Confirm & Pay` `Button` (automatically disabling submission until satisfied).
- **0ms Reactive Pricing & `computed` Signals**:
  - `FlightAssistantCubit` subscribes to `surfaceBloc.state` to synchronize `/booking/tier`, `/passenger/name`, `/booking/departureDate`, `/addons/checkedLuggage`, and `/addons/priorityBoarding` in 0ms, driving `totalPriceSignal` (`Economy: $420`, `Premium: $650`, `Business: $1,250`, plus `$45` checked luggage and `$25` priority boarding) without frame drops.
- **Bidirectional `RpcHandler` Loopback (`callAgentFunction` / `outboundMessages`)**:
  - Demonstrates `surfaceBloc.callAgentFunction(surfaceId, FunctionCall(call: 'assignPreferredSeat', ...))` emitting a `callFunction` request on `surfaceBloc.outboundMessages` and resolving with a `functionResponse` (`14A (Window)`) via `IngestMessage`.

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

## 🏗️ Production Architecture & Security Considerations ("In Real Production, X Would Be Y")

To keep this reference application lightweight, deterministic, and runnable without mandatory cloud infrastructure or API keys, several real-world production layers are simulated locally in the client. When building an enterprise application based on this pattern, consider the following architectural and security differences:

| Domain | Reference Example (Local Simulation) | Production Architecture ("In Real Production...") |
| :--- | :--- | :--- |
| **Agent / LLM Gateway** | Client connects directly to Gemini via `--dart-define=GEMINI_API_KEY` or uses local mock streams. | **Backend-for-Frontend (BFF) Gateway**: Clients connect to an authenticated backend proxy (via WebSockets or SSE at `/api/chat/stream`). The backend securely holds model API keys, applies rate limiting, enforces enterprise guardrails, and manages agent orchestrators (for example LangGraph or Cloud Run). |
| **Tool Execution & Action Loop** | `FlightAssistantCubit` listens to `surfaceBloc.actionResponses` and directly swaps local mock streams. | **Server-Side Agent Tool Pipeline**: Action submissions (`selectFlight`, `proceedBooking`) are posted as agent tool call responses to the remote orchestrator. The agent executes real backend services (for example Amadeus, Sabre, or Stripe payments) before generating the next A2UI surface stream. |
| **Bidirectional `RpcHandler` (`outboundMessages`)** | `_handleOutboundRpcMessage` intercepts `callFunction` envelopes in-memory and injects a simulated `14A (Window)` `functionResponse`. | **Authenticated WebSocket / gRPC Duplex Transport**: `surfaceBloc.outboundMessages` is piped over an authenticated duplex transport to the remote agent runtime, which queries real airline seat-map APIs and streams back the signed `functionResponse` envelope. |
| **Pricing & Business Rules** | `calculatedTotal` and `totalPriceSignal` are dynamically computed on the client via reactive BlocSignal derived state for immediate UI feedback. | **Authoritative Server Pricing & Inventory Locks**: Client-side reactive pricing provides instant UX previews, but final ticketing fares, taxes, currency conversions, and seat inventory locks must be authoritatively computed and cryptographically validated on the server at checkout. |
| **Session Persistence & Recovery** | Chat history and active surface state live ephemerally in client memory (`FlightAssistantState`). | **Hydrated State & Multi-Device Sync**: Use `HydratedCubitSignal` (from `bloc_signals_hydrate`) or local encrypted storage (SQLite or Hive) to persist conversation state, active surface tokens, and draft form inputs across app restarts and network interruptions. |
| **Surface History in Chat** | Single active surface container replaces the previous surface as the conversation progresses. | **Multi-Surface Timeline Stacking**: Chat histories preserve prior surfaces in disabled, read-only snapshot mode (for example keeping the chosen flight summary visible higher in the chat scrollback while the new passenger form is active below). |
| **Form Validation & Schemas** | Client-side A2UI `CheckRule` (`required`) and `BasicCatalog.v0_9()` schema validation enforce non-empty inputs in the UI. | **Defense-in-Depth Server Schema Validation**: Client-side `CheckRule` validation prevents accidental empty submissions, while the backend gateway re-validates all submitted form payloads against strict server schemas, passport rules, and payment constraints before booking. |
