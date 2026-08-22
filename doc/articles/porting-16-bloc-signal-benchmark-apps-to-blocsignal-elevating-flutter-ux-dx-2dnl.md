---
series: "BlocSignal Architecture & Practice"
title: Porting 16 BLoC & Signal Benchmark Apps to BlocSignal: Elevating Flutter UX & DX
published: true
description: We ported 16 official example apps from felangel/bloc and rodydavis/signals.dart to showcase how BlocSignal simplifies Flutter state management with synchronous frame updates, computed() derivations, and streamless Mutex concurrency.
tags: flutter, dart, architecture, webdev
---

# 🚀 Ported Example Benchmark Suite Live on `blocsignal.dev`!

If you’ve been evaluating **`BlocSignal`**—the monorepo package bridging the predictable event-driven BLoC architecture with Rody Davis's reactive signals v7 primitives—we’ve got something big to share.

We just launched a dedicated **Ported Example Suite** containing **16 full-featured, runnable benchmark applications** adapted directly from the official `felangel/bloc` (10 apps) and `rodydavis/signals.dart` (6 apps) example repositories.

🌐 **Explore the Live Benchmark Suite**: [https://blocsignal.dev/ported-examples](https://blocsignal.dev/ported-examples)

---

## 💡 Why Port These Benchmark Apps?

State management benchmarks are best understood through real-world applications. By porting these established examples 1-to-1, developers can compare `BlocSignal` side-by-side with original implementations to see concrete architectural benefits:

### 1. Synchronous Frame Updates (Better Test DX)
In classic BLoC, state updates propagate asynchronously over microtask streams. In `BlocSignal`, `emit()` updates state **synchronously on the exact same frame**. This eliminates microtask queue latency, making widget building feel instant and allowing unit tests to assert `expect(bloc.stateValue, ...)` without `pumpAndSettle` or stream delays.

### 2. Reactive `computed()` Derivations (Zero Event Plumbing)
In complex apps like **Todos** or **Dynamic Forms**, classic BLoC often requires dispatching intermediate filter events or wiring up `CombineLatestStream`. With `BlocSignal`, you declare `late final ReadonlySignal<List<Todo>> filteredTodos = computed(...)` right inside the constructor. When state changes, downstream signals derive updated values reactively and lazily.

### 3. Streamless Event Concurrency Transformers (Lower Overhead)
Event concurrency transformers (`sequential()`, `droppable()`, `restartable()`) in `BlocSignal` are implemented as streamless higher-order functions using pure Dart `Mutex` locks. You get full request-cancellation and debouncing capabilities (e.g. in **GitHub Search**) with **zero RxStream memory allocations**.

---

## 📦 What's Included in the Suite?

### Ports from `felangel/bloc` (10 Applications)
* ⏱️ **`flutter_timer`** — Ticker countdown with pause/resume & automatic teardowns
* 📝 **`flutter_todos`** — Flagship Todo CRUD app with `computed` reactive filters & stats
* 🌦️ **`flutter_weather`** — Weather search with temperature toggle & cross-cubit theme driving
* 🔀 **`flutter_dynamic_form`** — Cascading vehicle dropdowns (Brand → Model → Trim)
* 🪄 **`flutter_wizard`** — Multi-step registration flow with step validation signals
* ✅ **`flutter_form_validation`** — Synchronous real-time input field validation
* ⚡ **`bloc_concurrency_visualizer`** — Interactive execution timeline for streamless transformers
* 🔍 **`github_search`** — Debounced repository search using `restartable()`
* 📋 **`flutter_complex_list`** — Multi-selection list, batch deletion & `BlocSignalSelector` rebuilds
* 🌊 **`flutter_bloc_with_stream`** — Stream interop via `StreamBlocSignal` & `.toStream()`

### Ports from `rodydavis/signals.dart` (6 Applications)
* 🧮 **`eval_calculator`** — Expression parsing & arithmetic state machine
* 🎨 **`flutter_colorband`** — Reactive RGBA color swatches & slider composition
* 🔌 **`get_it_signals`** — Service locator DI integration with `get_it`
* ⏳ **`flutter_async`** — Async state handling (`AsyncData`, `AsyncLoading`, `AsyncError`)
* 🏗️ **`clean_architecture`** — 3-tier Presentation / Domain / Data architecture
* 💾 **`persist_shared_preferences`** — State hydration with `HydratedCubitSignal`

---

Each card on [blocsignal.dev/ported-examples](https://blocsignal.dev/ported-examples) features **dual direct links** pointing to both our `BlocSignal` monorepo source code and the original upstream source code on GitHub.

Check out the benchmark suite and let us know what you think! ⭐️

🔗 **[https://blocsignal.dev/ported-examples](https://blocsignal.dev/ported-examples)**
