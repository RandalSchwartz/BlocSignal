---
series: "BlocSignal Architecture & Practice"
title: "Dogfooding BlocSignal on the Web: Building a 100K Ops/sec Reactive App with Jaspr and Dart 3.13"
published: true
description: "A behind-the-scenes look at how we dogfooded bloc_signals_jaspr on blocsignal.dev, achieving 100K ops/sec in browser JS with declarative consumer components and Dart 3.13."
tags: ["flutter", "dart", "webdev", "statemanagement"]
---

## Building Pure Dart Web Apps Without Compromise

When developers evaluate Dart for the web, they typically face a stark tradeoff:
1. **Flutter Web**: Exceptional for canvas-driven applications, design systems, and cross-platform desktop/mobile parity—but heavy for content-first landing pages, docs, and fast-loading SEO sites.
2. **Jaspr Web**: A lightweight, component-driven framework that compiles pure Dart to HTML and CSS with instant first paint and full search engine indexing.

When we built the official documentation and showcase site for [BlocSignal](https://blocsignal.dev), we knew Jaspr was the perfect foundation. But like many engineers diving into a new UI paradigm, our initial implementation took a shortcut: we used raw `StatefulComponent` lifecycles and manual `.subscribe()` callbacks to wire up our state machines.

It worked—but it wasn't idiomatic. 

In this behind-the-scenes case study, we walk through the process of dogfooding **`bloc_signals_jaspr`** across [blocsignal.dev](https://blocsignal.dev), replacing manual subscription glue with declarative consumer components, achieving **100,000 operations/sec in compiled JavaScript**, and exploring the sheer developer ergonomics of **Dart 3.13 primary constructors**.

---

## The "Manual Subscription Trap": Why Raw `.subscribe()` Fails at Scale

In classic Flutter or Jaspr development, when you create a state machine without framework-level consumer widgets, you might be tempted to subscribe inside `initState()`:

```dart
// ❌ THE ANTI-PATTERN: Manual subscription glue in StatefulComponent
class LiveVisualizerState extends State<LiveVisualizer> {
  late final LiveCounterBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = LiveCounterBloc();
    // ⚠️ Flaw 1: Every state change triggers a full component setState
    _bloc.state.subscribe((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // ⚠️ Flaw 2: Manual dispose tracking
    _bloc.close();
    super.dispose();
  }
}
```

While this appears harmless in a simple counter demo, it introduces three severe architectural flaws:

1. **The Double Re-Render Penalty**: When a user clicks a button that calls both `_bloc.add(Event())` and a local `setState()`, the component executes *two back-to-back render passes* in the exact same frame.
2. **Batch UI Thrashing**: If you execute a high-frequency benchmark (e.g. dispatching 1,000 events in a loop), manual subscriptions attempt to invoke `setState()` 1,000 times during the loop, creating massive JS event-loop thrashing.
3. **Coarse-Grained Rebuilds**: The entire component tree rebuilds on every change, even if only a single badge or numeric label changed value.

To solve this, we brought the full power of `bloc_signals_flutter`'s declarative consumer components over to Jaspr in **`bloc_signals_jaspr`**.

---

## 1. Declarative Routing with a `NavigationCubit`

Rather than relying on ad-hoc URL parsing scattered across components, we modeled the entire site navigation as a pure Dart state machine:

```dart
// lib/src/cubits/navigation_cubit.dart
import 'dart:js_interop';
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:web/web.dart' as web;

@JS('trackGaPageView')
external void _trackGaPageView(JSString path);

class NavigationCubit() extends CubitSignal<String> {
  this : super(initialState: _resolveCurrentPath()) {
    // Listen to browser history navigation
    web.window.addEventListener('popstate', ((web.Event _) => _sync()).toJS);
    web.window.addEventListener('hashchange', ((web.Event _) => _sync()).toJS);
    _trackPageView(stateValue);
  }

  static String _resolveCurrentPath() {
    final path = web.window.location.pathname;
    final hash = web.window.location.hash.toLowerCase();
    if (path.startsWith('/showcase') || hash.contains('showcase')) return '/showcase';
    if (path.startsWith('/minesweeper') || hash.contains('minesweeper')) return '/minesweeper';
    if (path.startsWith('/publications') || hash.contains('publications')) return '/publications';
    return '/';
  }

  void _sync() {
    final next = _resolveCurrentPath();
    if (next != stateValue) {
      emit(next);
      _trackPageView(next);
    }
  }

  void _trackPageView(String route) {
    try {
      _trackGaPageView(route.toJS);
    } catch (_) {}
  }
}
```

At the root of the application, we inject the cubit using **`BlocSignalProvider`** and build the active page using **`BlocSignalBuilder`**:

```dart
// lib/src/app.dart
class const App({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<NavigationCubit>(
      create: (_) => NavigationCubit(),
      child: const _AppRouter(),
    );
  }
}

class const _AppRouter() extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalBuilder<NavigationCubit, String>(
      builder: (context, currentPath) => switch (currentPath) {
        '/showcase' => const ShowcasePage(),
        '/minesweeper' => const MinesweeperPage(),
        '/publications' => const PublicationsPage(),
        _ => const HomePage(),
      },
    );
  }
}
```

Now, anywhere in the component tree—such as our sticky navigation header—we can reactively highlight active links with zero prop-drilling using `context.select()`:

```dart
// lib/src/components/navbar.dart
final activePath = context.select<NavigationCubit, String>((c) => c.stateValue);

a(
  href: '/showcase',
  classes: activePath == '/showcase' ? 'nav-active' : '',
  [Component.text('Showcase')],
)
```

---

## 2. Fine-Grained DOM Updates with `BlocSignalSelector`

On the [blocsignal.dev](https://blocsignal.dev) homepage, the **Interactive Live Visualizer** demonstrates real-time state updates across multiple metrics:
1. **Primary State**: The raw integer count.
2. **Computed State (2x)**: `state * 2`.
3. **Parity & Status**: `EVEN` / `ODD` and `POSITIVE` / `NEGATIVE` / `ZERO`.

Instead of rebuilding the entire visualizer card on every tick, each card uses **`BlocSignalSelector`** to isolate its DOM mutations:

```dart
// 1. Primary Count Selector
BlocSignalSelector<LiveCounterBloc, int, int>(
  selector: (state) => state,
  builder: (context, count) => span(classes: 'metric-value', [
    Component.text('$count'),
  ]),
),

// 2. Computed 2x Doubled Selector
BlocSignalSelector<LiveCounterBloc, int, int>(
  selector: (state) => state * 2,
  builder: (context, doubled) => span(classes: 'metric-value', [
    Component.text('$doubled'),
  ]),
),

// 3. Record-based Multi-Value Selector
BlocSignalSelector<LiveCounterBloc, int, ({String parity, String status})>(
  selector: (state) => (
    parity: state % 2 == 0 ? 'EVEN' : 'ODD',
    status: state > 0 ? 'POSITIVE' : (state < 0 ? 'NEGATIVE' : 'ZERO'),
  ),
  builder: (context, derived) => div(classes: 'status-row', [
    span(classes: 'chip', [Component.text(derived.parity)]),
    span(classes: 'chip', [Component.text(derived.status)]),
  ]),
)
```

Buttons dispatch events directly using `context.read<LiveCounterBloc>()`:

```dart
button(
  classes: 'btn-increment',
  onClick: () => context.read<LiveCounterBloc>().add(IncrementEvent()),
  [Component.text('+ 1 Increment')],
)
```

And background telemetry logging is captured cleanly with **`BlocSignalListener`**:

```dart
BlocSignalListener<LiveCounterBloc, int>(
  listener: (context, state) {
    _appendLog('⚡ TRANSITION -> State: $state [0ms Synchronous]');
  },
  child: visualizerMarkup,
)
```

---

## 3. Side-by-Side: Traditional Dart 3.5 vs. Modern Dart 3.13

Because our website is an application rather than a published library package, we can take full advantage of **Dart 3.13 primary constructors** and constructor shorthands.

Look at the difference in boilerplate when defining a reactive Jaspr card:

### Traditional Dart 3.5 Syntax
```dart
class MetricCard extends StatelessComponent {
  const MetricCard({
    required this.title,
    required this.value,
    super.key,
  });

  final String title;
  final String value;

  @override
  Component build(BuildContext context) {
    return div(classes: 'metric-card', [
      span([Component.text(title)]),
      h3([Component.text(value)]),
    ]);
  }
}
```

### Modern Dart 3.13 Syntax
```dart
class const MetricCard(final String title, final String value, {super.key}) 
    extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'metric-card', [
      span([Component.text(title)]),
      h3([Component.text(value)]),
    ]);
  }
}
```

By placing fields directly in the primary constructor parameter list, 5 lines of boilerplate collapse into a clean, single-line class header with zero repetition.

---

## 4. Web Performance Reality: 100K Operations/Sec in Browser JavaScript

One of the biggest surprises for developers testing the live visualizer on [blocsignal.dev](https://blocsignal.dev) is the built-in stress test:

> **Benchmark**: Dispatches 1,000 synchronous transitions in a tight loop.

In traditional stream-based architectures (like classic BLoC or Rx on the web), dispatching 1,000 events allocates 1,000 `StreamController` events and queues 1,000 microtask hops through Dart's async runtime.

In **BlocSignal**, state changes propagate through a synchronous dependency graph:
* **0 Microtask Queue Hops**: State transitions resolve in the exact same call stack.
* **0 Intermediate Frame Tearing**: The DOM settles cleanly without intermediate stutter.
* **Throughput**: Even running in compiled JS inside a standard browser tab, it clocks over **100,000 operations per second** (~10ms for 1,000 full event-state cycles).

---

## Summary & Live Demo

Dogfooding **`bloc_signals_jaspr`** on our own production website proved that building web applications in pure Dart doesn't require choosing between developer discipline and raw performance:

| Feature | Classic Web BLoC / Rx | `bloc_signals_jaspr` |
| :--- | :--- | :--- |
| **Reactivity Latency** | Microtask Queue Delay (Async) | **0ms Synchronous Call Stack** |
| **Component Wiring** | Manual `subscribe` / `dispose` | **Declarative `BlocSignalBuilder`** |
| **DOM Rebuild Scoping** | Coarse Component Rebuilds | **Fine-Grained `BlocSignalSelector`** |
| **JS Web Throughput** | ~2,000 – 10,000 ops/sec | **~100,000+ ops/sec** |
| **Syntax Overhead** | Verbose Field & Constructor Maps | **Dart 3.13 Primary Constructors** |

You can try the interactive visualizer and play the live Minesweeper case study right now at **[blocsignal.dev](https://blocsignal.dev)**!

All the source code is open source and visible directly in our GitHub monorepo at **[RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal/tree/main/website)**. ⭐️
