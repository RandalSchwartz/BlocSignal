---
series: "BlocSignal Architecture & Practice"
title: "Beyond Black-Box Concurrency: Streamless Event Transformers, Telemetry, and the End of Stream-Whacking"
published: true
description: "Why event concurrency transformers in Flutter must be streamless higher-order functions, and how generic transformer telemetry solves the black-box dilemma without polluting UI domain state."
tags: flutter, dart, architecture, reactive
---

## When 120 Hz Flings Meet Finite Queues

> **Key Takeaway**: In event-driven Flutter applications, concurrency transformers (`droppable`, `restartable`, `sequential`, `debounce`) govern when and how incoming user gestures, network streams, and lifecycle events are executed or discarded. In classic `package:bloc` and `bloc_concurrency`, transformers rely on heavy RxDart stream pipelines (`exhaustMap`, `switchMap`, `asyncExpand`)—what we call **"Stream-Whacking"**. During high-frequency gestures like a 120 Hz scroll fling, this stream machinery churns through dozens of `StreamController` allocations and microtask queue hops right when Flutter needs every microsecond of its 8.3 ms frame budget.
>
> Worse still, traditional transformers operate as **opaque black boxes**. When events are dropped or tasks are preempted, developers have zero runtime visibility. Anxious teams often attempt to fix this by stuffing technical drop counters directly into UI domain state, triggering catastrophic widget rebuild storms and coupling business logic to hardware screen refresh rates.
>
> By contrast, [**`BlocSignal`**](https://blocsignal.dev) eliminates the stream tax entirely by implementing transformers as **pure, streamless higher-order functions** and lightweight Mutex locks. Coupled with the newly introduced **first-class generic transformer telemetry**, teams get complete pipeline transparency through [**OpenTelemetry**](https://pub.dev/packages/bloc_signals_otel) and [**Flutter DevTools**](https://pub.dev/packages/bloc_signals_devtools) without a single dropped event ever polluting presentation state.

---

### 1. The Anatomy of a 120 Hz Fling: Stream-Whacking vs. Streamless

To understand the hidden cost of classic event concurrency in Flutter, consider the anatomy of an infinite-scroll list on a modern mobile device.

A user gives the list a rapid swipe with their thumb. On a 120 Hz ProMotion display, Flutter's gesture layer dispatches a continuous cascade of scroll position notifications. In an infinite scroll setup, this often translates to **20 to 30 pagination events fired in less than 250 milliseconds**:

```plaintext
User Thumb Fling (250 ms)
─────────────────────────────────────────────────────────────────────────────
Event 1   ──> FetchNextPage(page: 2)  [Starts HTTP/3 Request]
Event 2   ──> FetchNextPage(page: 2)  [Redundant Scroll Tick]
Event 3   ──> FetchNextPage(page: 2)  [Redundant Scroll Tick]
...
Event 30  ──> FetchNextPage(page: 2)  [Redundant Scroll Tick]
```

To prevent 30 concurrent duplicate network requests for Page 2, developers reach for a concurrency transformer. In classic `package:bloc`, they write:

```dart
// Classic package:bloc with bloc_concurrency
on<FetchNextPage>(
  _onFetchNextPage,
  transformer: droppable(), // RxDart exhaustMap under the hood
);
```

While `droppable` correctly prevents duplicate network calls, let us inspect what the Dart runtime actually does under the hood to achieve that drop.

#### The Stream-Whacking Tax (RxDart / Reactive Streams)

In classic reactive frameworks, `droppable` is implemented as an Rx operator—typically wrapping `events.exhaustMap(...)` or an equivalent stream transformer:

```plaintext
RxDart Stream Pipeline Under the Hood:
Incoming Event ──> StreamController (Event Source)
                    └──> StreamSubscription (exhaustMap)
                          └──> StreamController (Inner Event Stream)
                                └──> Future/Stream Mapping
                                      └──> Microtask Queue Hop ──> Handler
```

When those 30 scroll ticks arrive in 250 ms:
1. **Allocation Churn**: The runtime allocates intermediate `StreamController` instances, internal buffer arrays, and multi-layered `StreamSubscription` wrappers to manage stream lifecycles.
2. **Microtask Queue Flooding**: Every single event—even an event destined to be discarded—is enqueued onto Dart's asynchronous microtask event queue (`scheduleMicrotask`).
3. **Frame Budget Starvation**: On a 120 Hz display, the UI thread has exactly **8.3 milliseconds** to calculate layout, paint pixels, and submit the frame to the rasterizer. Forcing the Dart runtime to schedule, pump, and drain dozens of microtasks on the main isolate introduces subtle frame slips and jank during the very gesture where smoothness matters most.

#### The Streamless Alternative in BlocSignal

In [**`BlocSignal`**](https://pub.dev/packages/bloc_signals), event transformers are **not** stream operators. `BlocSignal` does not use Dart `Stream` or RxDart pipelines for internal event routing.

Instead, an `EventTransformer` is defined as a **pure, streamless higher-order function**:

```dart
/// A pure higher-order function signature for controlling execution flow.
typedef EventTransformer<E, StateType> = FutureOr<void> Function(
  E event,
  EventHandler<E, StateType> handler,
  void Function(StateType state) emit,
);
```

Notice what is missing: there are no `Stream` arguments, no `StreamController`s, and no microtask buffers. The incoming event, the target handler, and the state `emit` callback are passed directly to the function.

Here is the entire implementation of `droppable` in `BlocSignal`:

```dart
EventTransformer<E, StateType> droppable<E, StateType>() {
  var isProcessing = false;

  return (event, handler, emit) {
    // Synchronous fast-path bailout!
    if (isProcessing) return null;

    isProcessing = true;
    try {
      final result = handler(event, emit);
      if (result is Future) {
        return result.whenComplete(() {
          isProcessing = false;
        });
      }
      isProcessing = false;
    } catch (_) {
      isProcessing = false;
      rethrow;
    }
  };
}
```

Look at what happens during that exact same 120 Hz scroll fling:
- **Event 1** arrives: `isProcessing` is `false`. It sets `isProcessing = true` and invokes the async handler, dispatching the remote fetch.
- **Events 2 through 30** arrive: They enter the transformer closure, hit `if (isProcessing) return null;`, and **bail out synchronously in under 5 nanoseconds**.
- Zero `StreamController`s allocated. Zero microtasks enqueued. Zero GC pressure. The main thread remains 100% dedicated to Flutter's 120 Hz rasterizer.

---

### 2. The "Silent Drop" Debate: Why State Pollution Is a Trap

While `droppable` solves the concurrency problem with zero runtime overhead, it exposes an operational question that sparks heated debates on engineering teams:

> *"What happens if an in-flight network request fails after the user's thumb has already finished flinging? Since the subsequent 29 scroll ticks were silently dropped, isn't the app stuck forever?"*

This concern frequently leads developers down a dangerous path: **State Pollution**.

#### The State Pollution Anti-Pattern

Anxious developers, wanting visibility into dropped events or attempting to build complex recovery mechanisms, start leaking concurrency counters into their domain state:

```dart
// ❌ ANTI-PATTERN: Polluting domain state with concurrency artifacts
class PostState {
  const PostState({
    required this.posts,
    this.isLoading = false,
    this.droppedEventsCount = 0,    // ❌ Why is this in UI domain state?!
    this.lastDroppedTimestamp = 0,  // ❌ Forces unnecessary widget rebuilds!
  });

  final List<Post> posts;
  final bool isLoading;
  final int droppedEventsCount;
  final int lastDroppedTimestamp;
}
```

Whenever an event is dropped, the bloc emits:

```dart
emit(state.copyWith(droppedEventsCount: state.droppedEventsCount + 1));
```

This seems innocent, but it introduces three catastrophic architectural flaws:

1. **Hardware-Coupled Business Logic**:
   How many events are dropped during a 250 ms scroll gesture?
   - On an iPhone 16 Pro (120 Hz ProMotion display), it drops **29 events**.
   - On a budget Android tablet (60 Hz display), it drops **14 events**.
   - On Flutter Web with a stepped mouse scroll wheel, it drops **2 events**.
   
   If `droppedEventsCount` lives in domain state, your application state is no longer representing business truth; it is reflecting the hardware polling frequency of the user's physical display glass!

2. **Frame Destruction via Redundant Rebuilds**:
   The entire reason `droppable` was added was to keep the UI smooth during high-speed scrolling. By emitting state changes on every dropped event, you force Flutter widget trees and `BlocSignalBuilder`s (from [**`bloc_signals_flutter`**](https://pub.dev/packages/bloc_signals_flutter)) to re-evaluate and rebuild 30 times a second during the fling—the exact failure mode you were trying to eliminate.

3. **Tainted Unit Testing and State Snapshots**:
   Deterministic unit testing becomes an exercise in frustration. Instead of asserting a clean business transition:
   ```plaintext
   [PostLoading, PostSuccess]
   ```
   Your test harness must now predict hardware-variable intermediate states:
   ```plaintext
   [PostLoading, PostLoading(dropped: 1), PostLoading(dropped: 2), ..., PostSuccess]
   ```

#### The Real UX Solution: Fault-Tolerant UI Boundaries

The fear of the "silent drop" stems from a misunderstanding of mobile UX. In production infinite scroll:
- Dropping 29 events during an active fling is **desirable**: the user was requesting the next page once, not 30 separate pages.
- If that single in-flight network request fails due to a network glitch, how should the user recover?
  - Should the app automatically retry 29 times in the background without user consent? No—that risks hammering an already failing server.
  - The correct pattern is an **inline "Tap to retry" footer** in the list view, or an exponential backoff policy in the repository layer.
- Because `droppable` resets `isProcessing = false` in its `whenComplete` block when the initial request terminates (even on failure), tapping "Retry" or making a new scroll gesture immediately triggers a clean, unblocked event!

---

### 3. Why `droppable` Isn't Special: Elevating to Generic Telemetry

Concurrency transformers are not isolated ad-hoc utilities. They are an **event-scheduling pipeline**. And just like any critical infrastructure pipeline, they require universal, structured observability.

Notice that `droppable` is only one of several fundamental concurrency patterns:
- **`droppable()`**: Discards incoming events while a handler is in-flight.
- **`restartable()`**: Supersedes in-flight executions, canceling or ignoring stale emissions from older generation tokens.
- **`sequential()`**: Queues incoming events in strict FIFO order, ensuring task $N$ completes before task $N+1$ begins.
- **`debounce()` / `throttle()`**: Coalesces rapid bursts over a temporal window.
- **Custom Transformers**: Rate-limiters, backoff retries, or circuit breakers.

Every single one of these transformers makes scheduling decisions that developers need to observe:
- *When did `droppable` discard an event, and why?*
- *When did `restartable` preempt an in-flight search query?*
- *How long did an event wait in a `sequential` queue before its handler began executing?*

In [**`bloc_signals`**](https://pub.dev/packages/bloc_signals) 1.3.0, we resolved this by introducing **First-Class Generic Transformer Telemetry** ([Issue #239](https://github.com/RandalSchwartz/BlocSignal/issues/239)).

#### The Telemetry Contract on `BlocSignalObserver`

We expanded `BlocSignalObserver` with a dedicated, non-state operational telemetry hook:

```dart
abstract class BlocSignalObserver {
  // Observability: State machines & error boundaries
  void onCreate(BlocSignalBase bloc) {}
  void onEvent(BlocSignalMixin bloc, Object? event) {}
  void onChange(BlocSignalBase bloc, Change change) {}
  void onTransition(BlocSignalMixin bloc, Transition transition) {}
  void onError(BlocSignalBase bloc, Object error, StackTrace stackTrace) {}
  void onClose(BlocSignalBase bloc) {}

  /// Telemetry: Operational pipeline physics & diagnostics
  void onTelemetry(
    BlocSignalBase bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {}
}
```

Now, every built-in transformer in `BlocSignal` emits structured telemetry automatically:

| Transformer | Telemetry Event (`name`) | Metadata Payload |
| :--- | :--- | :--- |
| **`droppable()`** | `BlocTelemetryKeys.eventDropped` (`'event_dropped'`) | `{'transformer': 'droppable', 'reason': 'in_flight'}` |
| **`restartable()`** | `BlocTelemetryKeys.taskPreempted` (`'task_preempted'`) | `{'transformer': 'restartable', 'reason': 'superseded'}` |
| **`sequential()`** | `BlocTelemetryKeys.eventQueued` (`'event_queued'`) | `{'transformer': 'sequential', 'queue_wait_ms': 42}` |

#### Zero-Allocation Performance Invariant (The ProMotion Guard)

Earlier we emphasized that high-speed gestures must not allocate garbage. If telemetry was naively emitted on every dropped event, wouldn't creating metadata maps reintroduce the exact memory churn we sought to avoid?

To preserve strict 120 Hz performance, `BlocSignal` enforces two critical invariants:
1. **Static Pre-allocated Metadata**: Built-in transformers use compile-time `const` metadata maps (for example `_droppableDroppedMetadata`).
2. **Early Short-Circuiting**: Before evaluating telemetry arguments or allocating stack frames, the transformer checks:
   ```dart
   if (BlocSignalObserver.observer == null) return null;
   ```
   If no observer is configured (the default in production unless telemetry or DevTools is enabled), the drop bails out in **0.0 nanoseconds with zero heap allocations**.

---

### 4. The Power of Composition: Contextual Transformers (`blocTransformer`)

One of the most elegant benefits of streamless transformers is that they are **ordinary Dart functions**. Unlike Rx operators that require complex stream plumbing (`pipe`, `compose`, `transform`), streamless transformers compose effortlessly like standard middleware.

In `bloc_signals` 1.3.0, we introduced strongly typed contextual event transformers ([Issue #243](https://github.com/RandalSchwartz/BlocSignal/issues/243)):

```dart
/// A transformer function signature with direct typed access to the host [bloc].
typedef BlocEventTransformer<E, StateType> = FutureOr<void> Function(
  BlocSignalMixin<dynamic, StateType> bloc,
  E event,
  EventHandler<E, StateType> handler,
  void Function(StateType state) emit,
);
```

By providing the host `bloc` instance directly to the transformer, custom transformers can inspect `bloc.stateValue`, query bloc properties, or emit custom telemetry without awkward constructor closures or manual instance passing.

#### Composing Transformers: Logging & Execution Timers

Want to log the wall-clock execution time of a specific critical handler? In classic BLoC, you would have to attach an observer to the entire application firehose.

With streamless composition, you can create a surgical `timed()` wrapper in 15 lines of Dart:

```dart
/// A composable transformer wrapper that measures handler execution duration.
EventTransformer<E, S> timed<E, S>(EventTransformer<E, S> inner) {
  return (event, handler, emit) async {
    final stopwatch = Stopwatch()..start();
    try {
      await inner(event, handler, emit);
    } finally {
      stopwatch.stop();
      print('Handler for $event took ${stopwatch.elapsedMilliseconds} ms');
    }
  };
}
```

Because transformers are pure higher-order functions, you can wrap them like Russian nesting dolls:

```dart
class CheckoutBloc extends BlocSignal<CheckoutEvent, CheckoutState> {
  CheckoutBloc() : super(initialState: const CheckoutInitial()) {
    on<SubmitOrder>(
      _onSubmitOrder,
      // Drops duplicate clicks AND times the in-flight checkout!
      transformer: timed(droppable()),
    );
  }
}
```

---

### 5. Enterprise Observability: DevTools and OpenTelemetry

When `onTelemetry` fires, where does it go?

Because telemetry is cleanly separated from presentation state, it can be routed simultaneously to local developer tooling and production cloud observability without touching your Flutter widgets:

```plaintext
┌────────────────────────────────────────────────────────────────────────┐
│                        Transformer Drops / Preempts                    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ emitTelemetry('event_dropped')
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        BlocSignalObserver                              │
└───────────────────┬────────────────────────────────┬───────────────────┘
                    │                                │
                    ▼                                ▼
┌──────────────────────────────────────┐ ┌───────────────────────────────┐
│     DevToolsBlocSignalObserver       │ │     OtelBlocSignalObserver    │
│  - Posts to Dart VM Service RPC      │ │  - OpenTelemetry Span Events  │
│  - Renders drop badge on Timeline    │ │  - Increments Prometheus Drops│
│  - Visualizes queue latency spikes   │ │  - Latency Histograms         │
└──────────────────────────────────────┘ └───────────────────────────────┘
```

#### 1. Flutter DevTools Integration ([`bloc_signals_devtools`](https://pub.dev/packages/bloc_signals_devtools))
In local development, the `DevToolsBlocSignalObserver` captures `onTelemetry` events and posts them directly to the Dart VM Service. When you inspect your bloc in the Flutter DevTools timeline, you see visual warning badges indicating exactly when and why an event was discarded or queued.

#### 2. OpenTelemetry Tracing ([`bloc_signals_otel`](https://pub.dev/packages/bloc_signals_otel))
In enterprise production deployments, the `OtelBlocSignalObserver` maps telemetry events directly to OpenTelemetry primitives:
- **Span Events**: Records an immutable span event on the active trace (`bloc.transformer.event_dropped`).
- **Counter Metrics**: Increments `bloc.transformer.events_dropped` labeled with the bloc type and transformer name.
- **Histogram Metrics**: Tracks `bloc.transformer.queue_latency_ms` to detect thread contention or slow database locks before users experience visual stutter.

#### 3. Composable Distributed Tracing with `traced()`
With `bloc_signals_otel` 1.1.0, you can trace any transformer pipeline with a single decorator:

```dart
import 'package:bloc_signals_otel/bloc_signals_otel.dart';

class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
  SearchBloc() : super(initialState: const SearchInitial()) {
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      // Automatically creates OTel spans and attaches bloc metadata!
      blocTransformer: traced(debounce(const Duration(milliseconds: 300))),
    );
  }
}
```

---

### 6. Declarative Testing with `blocSignalTest`

Observability is only production-ready if it is verifiable in unit test suites. In [**`bloc_signals_test`**](https://pub.dev/packages/bloc_signals_test), you can test your concurrency transformers and telemetry emissions deterministically using `expectTelemetry:`:

```dart
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

void main() {
  group('SearchBloc Concurrency & Telemetry', () {
    blocSignalTest<SearchBloc, SearchState>(
      'drops redundant rapid queries and emits event_dropped telemetry',
      build: SearchBloc.new,
      act: (bloc) {
        // Fire two identical queries rapidly while droppable is active
        bloc.add(const SearchSubmitted('flutter'));
        bloc.add(const SearchSubmitted('flutter'));
      },
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchSuccess>(),
      ],
      expectTelemetry: () => [
        // Deterministically assert that the second event was dropped!
        isTelemetry(
          BlocTelemetryKeys.eventDropped,
          metadata: {'transformer': 'droppable', 'reason': 'in_flight'},
        ),
      ],
    );
  });
}
```

Notice how clean this is:
1. `expect:` asserts the pristine business domain transitions (`SearchLoading` $\to$ `SearchSuccess`). The UI remains completely unaware of the drop.
2. `expectTelemetry:` asserts the operational scheduling physics.
3. Tests run synchronously and deterministically without arbitrary `tester.pumpAndSettle()` delays or flaky Rx timing races.

---

### Conclusion

For years, the Flutter ecosystem accepted "Stream-Whacking" as an inevitable tax of event-driven architecture. We wrapped synchronous events in asynchronous streams, burdened Dart's microtask queue during critical 120 Hz render windows, and operated with opaque black boxes where dropped events vanished into the void.

By treating event transformers as **pure, streamless higher-order functions**, `BlocSignal` delivers the best of both worlds:
- **Zero-Allocation Speed**: Nanosecond fast-path bailouts that preserve 120 Hz frame budgets during the most intense gesture flings.
- **Pure Domain State**: UI state machines remain 100% focused on business truth, completely decoupled from hardware refresh rates and display noise.
- **First-Class Observability**: Universal telemetry flowing directly into DevTools and OpenTelemetry, giving engineering teams deep insight into what their algorithms are doing in production.

---

### 🔗 Resources & Getting Started

- 🌐 **Official Documentation & Showcase**: [blocsignal.dev](https://blocsignal.dev)
- 📦 **Core Package (`bloc_signals`)**: [pub.dev/packages/bloc_signals](https://pub.dev/packages/bloc_signals)
- 📦 **Flutter Bindings (`bloc_signals_flutter`)**: [pub.dev/packages/bloc_signals_flutter](https://pub.dev/packages/bloc_signals_flutter)
- 📦 **OpenTelemetry Observability (`bloc_signals_otel`)**: [pub.dev/packages/bloc_signals_otel](https://pub.dev/packages/bloc_signals_otel)
- 📦 **DevTools Extension (`bloc_signals_devtools`)**: [pub.dev/packages/bloc_signals_devtools](https://pub.dev/packages/bloc_signals_devtools)
- 📦 **Declarative Testing Harness (`bloc_signals_test`)**: [pub.dev/packages/bloc_signals_test](https://pub.dev/packages/bloc_signals_test)
- 🐙 **GitHub Monorepo**: [github.com/RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal)

---

*How are you managing event concurrency in your Flutter applications today? Have you ever caught yourself stuffing drop counters into UI state? Let's discuss in the comments below!*
