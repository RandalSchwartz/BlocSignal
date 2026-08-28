---
title: "One-Shot UI Side Effects in BlocSignal: Snackbars, Dialogs, and Navigation Without State Pollution"
published: true
description: "Why persistent domain state is the wrong place for transient dialogs and snackbars, how classic BLoC solved it with bloc_presentation, and how to handle one-shot side effects in BlocSignal with zero dependencies."
tags: flutter, dart, statemanagement, webdev
series: BlocSignal Architecture & Practice
---

Every Flutter developer has run into the **Sticky State Dilemma**.

You build a login screen. When authentication fails, your state container emits an error. You catch it in your UI and show a `SnackBar`. Everything works—until the user rotates their phone, pulls down the notification shade, or types on the virtual keyboard.

Suddenly, the widget tree rebuilds. The state container is still holding `AuthErrorState("Invalid password")`. The UI listener fires again. And a duplicate snackbar appears out of nowhere.

In this article, we’ll explore why domain state machines struggle with transient UI events, how the classic BLoC community worked around this with `package:bloc_presentation`, and how **`BlocSignal`** lets you handle one-shot side effects cleanly with **zero additional package dependencies**.

---

## 1. The Root Problem: Persistent State vs. Ephemeral Actions

State management in Flutter is designed to model **persistent truth** over time:
* *Is the user logged in?* `AuthState.authenticated(user)`
* *Is data loading?* `TodoState.loading`
* *What is the cart total?* `$49.99`

Persistent state answers: **"What is the system's current condition?"**

In contrast, UI presentation actions are **ephemeral pulses**:
* *Show a brief SnackBar toast.*
* *Pop up an alert confirmation dialog.*
* *Push a new route on the Navigator stack.*
* *Vibrate the haptic motor.*

These actions answer: **"What just happened that requires a one-time reaction?"**

```plaintext
 ┌────────────────────────────────────────────────────────┐
 │                   State vs. Effects                    │
 ├────────────────────────────┬───────────────────────────┤
 │ Persistent State           │ Ephemeral Side-Effect     │
 ├────────────────────────────┼───────────────────────────┤
 │ • Survived by UI rebuilds  │ • Consumed once & gone    │
 │ • Represented in signals   │ • Triggered by an event   │
 │ • Backed by equality diffs │ • Zero domain state footprint │
 └────────────────────────────┴───────────────────────────┘
```

---

## 2. The Legacy Workarounds (And Their Hidden Costs)

Historically in `package:bloc` and `package:flutter_bloc`, developers used one of three approaches:

### Workaround A: The "Reset State" Ping-Pong
```dart
// Emitting a reset state immediately after error
emit(AuthFailure(error));
emit(AuthInitial()); // Extra emission, extra microtask, extra rebuild!
```
*Downside:* Causes two separate microtask queue ticks and multiple widget rebuild cycles just to reset a transient flag.

### Workaround B: "Consumed" Wrapper Flags
```dart
class AuthState {
  final String? errorSnackbarMessage;
  final bool hasShownSnackbar; // Manual bookkeeping everywhere!
}
```
*Downside:* Clutters state classes with imperative UI tracking flags that violate domain purity.

### Workaround C: `package:bloc_presentation`
LeanCode created [`package:bloc_presentation`](https://pub.dev/packages/bloc_presentation), adding a separate secondary `StreamController.broadcast()` to Blocs so developers could call `emitPresentation(MyEvent())` independently of `emit(state)`.

While `bloc_presentation` solved the problem well for classic BLoC, maintaining third-party wrapper packages in your monorepo introduces versioning churn, boilerplate, and dependency overhead.

---

## 3. The `BlocSignal` Advantage: 0ms Synchronous Guarantees

In [`BlocSignal`](https://pub.dev/packages/bloc_signals), state propagation is **synchronous**.

Unlike classic BLoC which queues updates asynchronously on microtask-queue Streams, calling `emit(newState)` in `BlocSignal` updates the underlying reactive signal and settles dependencies **immediately in the exact same frame**.

Because state updates are synchronous, you often don't need any presentation streams at all!

### Pattern 1: Direct Async UI Handlers (Recommended)

When an action is initiated by a user interaction (like tapping a button), the simplest and cleanest pattern is handling the reaction right in the button's `onPressed` callback:

```dart
ElevatedButton(
  onPressed: () async {
    final cubit = context.read<AuthCubit>();
    
    // 1. Await domain logic completion
    await cubit.signIn(emailController.text, passwordController.text);

    // 2. Safe async context guard
    if (!context.mounted) return;

    // 3. Inspect settled state synchronously with Dart pattern matching
    switch (cubit.stateValue) {
      case AuthSuccess(:final user):
        Navigator.of(context).pushReplacementNamed('/dashboard');
      case AuthFailure(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      case _:
        break;
    }
  },
  child: const Text('Log In'),
)
```

**Why this works so well in `BlocSignal`:**
* **Zero Race Conditions:** The moment `cubit.signIn(...)` finishes, `cubit.stateValue` is 100% up to date.
* **Zero Duplicate Triggers:** Screen rotations or unrelated rebuilds will never re-execute the button handler.
* **Zero Extra Code:** No special listeners, no extra streams, no consumable wrapper classes.

---

## 4. The Zero-Dependency `PresentationMixin` Recipe

What if your domain state machine triggers side-effects autonomously (for example, an incoming WebSocket disconnects, a background sync finishes, or you are migrating an existing codebase from `bloc_presentation`)?

You can drop in a **100% compatible presentation architecture in ~25 lines of pure Dart** without adding any 3rd-party dependencies.

### Step 1: The Mixin (`BlocSignalPresentationMixin`)

```dart
import 'dart:async';
import 'package:bloc_signals/bloc_signals.dart';

/// Mixin that adds one-shot presentation event broadcasting to any [BlocSignalBase].
mixin BlocSignalPresentationMixin<Event, State> on BlocSignalBase<State> {
  final _presentationController = StreamController<Event>.broadcast();

  /// Stream of one-shot presentation events.
  Stream<Event> get presentationStream => _presentationController.stream;

  /// Dispatches a one-shot presentation event to active UI listeners.
  void emitPresentation(Event event) {
    if (!isClosed) {
      _presentationController.add(event);
    }
  }

  @override
  Future<void> close() {
    _presentationController.close();
    return super.close();
  }
}
```

### Step 2: The Flutter Listener (`BlocSignalPresentationListener`)

```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

/// Listens to one-shot presentation events from a [BlocSignalBase] with [BlocSignalPresentationMixin].
class BlocSignalPresentationListener<
        B extends BlocSignalPresentationMixin<Event, dynamic>, Event>
    extends StatefulWidget {
  const BlocSignalPresentationListener({
    required this.listener,
    this.bloc,
    this.child,
    super.key,
  });

  final B? bloc;
  final void Function(BuildContext context, Event event) listener;
  final Widget? child;

  @override
  State<BlocSignalPresentationListener<B, Event>> createState() =>
      _BlocSignalPresentationListenerState<B, Event>();
}

class _BlocSignalPresentationListenerState<
        B extends BlocSignalPresentationMixin<Event, dynamic>, Event>
    extends State<BlocSignalPresentationListener<B, Event>> {
  StreamSubscription<Event>? _subscription;
  B? _resolvedBloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = widget.bloc ?? context.read<B>();
    if (_resolvedBloc != bloc) {
      _unsubscribe();
      _resolvedBloc = bloc;
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = _resolvedBloc?.presentationStream.listen((event) {
      if (mounted) widget.listener(context, event);
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
```

---

## 5. Putting It Together: A Real-World Example

Let's see how clean our Cubit and UI look when composed together:

### 1. Events & Cubit Definition

```dart
import 'package:bloc_signals/bloc_signals.dart';

// 1. Define one-shot presentation events as a sealed hierarchy
sealed class CheckoutPresentationEvent {}

class ShowErrorToast extends CheckoutPresentationEvent {
  ShowErrorToast(this.message);
  final String message;
}

class LaunchPaymentGateway extends CheckoutPresentationEvent {
  LaunchPaymentGateway(this.invoiceUrl);
  final String invoiceUrl;
}

// 2. Attach the mixin to your Cubit or Bloc
class CheckoutCubit extends CubitSignal<CheckoutState>
    with BlocSignalPresentationMixin<CheckoutPresentationEvent, CheckoutState> {
  CheckoutCubit() : super(initialState: CheckoutInitial());

  Future<void> processPayment() async {
    emit(CheckoutProcessing());
    try {
      final invoice = await paymentApi.createInvoice();
      emit(CheckoutSuccess());
      
      // Emit one-shot navigation/payment launch event
      emitPresentation(LaunchPaymentGateway(invoice.url));
    } catch (e) {
      emit(CheckoutFailure(e.toString()));
      
      // Emit transient error toast event
      emitPresentation(ShowErrorToast("Payment failed: ${e.toString()}"));
    }
  }
}
```

### 2. The Flutter UI

```dart
class CheckoutView extends StatelessWidget {
  const CheckoutView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalPresentationListener<CheckoutCubit, CheckoutPresentationEvent>(
      listener: (context, event) {
        switch (event) {
          case ShowErrorToast(:final message):
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.redAccent,
              ),
            );
          case LaunchPaymentGateway(:final invoiceUrl):
            launchUrl(Uri.parse(invoiceUrl));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const CheckoutBody(),
      ),
    );
  }
}
```

---

## 6. Migration Comparison Matrix

| Feature | Legacy `bloc_presentation` | `BlocSignal` Presentation Recipe |
| :--- | :--- | :--- |
| **External Dependencies** | `package:bloc_presentation` + `nested` | **0 external dependencies** |
| **Architecture** | Stream-based side channel | Stream-based side channel |
| **Emission Syntax** | `emitPresentation(event)` | `emitPresentation(event)` |
| **Listener Widget** | `BlocPresentationListener` | `BlocSignalPresentationListener` |
| **Automatic Cleanup** | Manual stream closing | Managed in `close()` lifecycle |
| **State Reactivity** | Microtask Streams | Synchronous Signals (0ms) |

---

## Summary

Handling one-shot side-effects shouldn't require complex state hacks or heavy external packages:

1. **For user interactions**: Use **Direct Async UI Handlers** (`await cubit.action()`)—`BlocSignal`'s synchronous emissions make this glitch-free and safe.
2. **For asynchronous domain broadcasts**: Use the 25-line **`BlocSignalPresentationMixin`** recipe for 100% `bloc_presentation` parity with zero dependencies.
3. **Keep domain state clean**: Keep persistent data in `stateValue` and ephemeral UI triggers in presentation streams.

---

### Resources & Links
* 📦 [`bloc_signals` on pub.dev](https://pub.dev/packages/bloc_signals)
* 🌐 Official Website: [blocsignal.dev](https://blocsignal.dev)
* 💻 GitHub Repository: [RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal)
