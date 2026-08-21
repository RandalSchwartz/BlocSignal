import 'dart:async';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

/// Sealed class representing all timer events.
sealed class TimerEvent {
  const TimerEvent();
}

/// Event dispatched when starting a new countdown timer.
final class TimerStarted extends TimerEvent {
  const TimerStarted({required this.duration});
  final int duration;
}

/// Event dispatched to pause a running countdown.
final class TimerPaused extends TimerEvent {
  const TimerPaused();
}

/// Event dispatched to resume a paused countdown.
final class TimerResumed extends TimerEvent {
  const TimerResumed();
}

/// Event dispatched to reset the countdown back to default duration.
final class TimerReset extends TimerEvent {
  const TimerReset();
}

/// Private internal event dispatched on every ticker tick.
final class _TimerTicked extends TimerEvent {
  const _TimerTicked({required this.duration});
  final int duration;
}

/// Sealed class representing timer state options.
sealed class TimerState {
  const TimerState(this.duration);
  final int duration;
}

/// Initial state when timer is ready to start.
final class TimerInitial extends TimerState {
  const TimerInitial(super.duration);

  @override
  String toString() => 'TimerInitial { duration: $duration }';
}

/// State when countdown is actively running.
final class TimerRunInProgress extends TimerState {
  const TimerRunInProgress(super.duration);

  @override
  String toString() => 'TimerRunInProgress { duration: $duration }';
}

/// State when countdown is temporarily paused.
final class TimerRunPause extends TimerState {
  const TimerRunPause(super.duration);

  @override
  String toString() => 'TimerRunPause { duration: $duration }';
}

/// State when countdown reaches zero.
final class TimerRunComplete extends TimerState {
  const TimerRunComplete() : super(0);

  @override
  String toString() => 'TimerRunComplete { duration: 0 }';
}

/// Ticker dependency helper that produces periodic ticks.
class Ticker {
  const Ticker();
  Stream<int> tick({required int ticks}) {
    return Stream.periodic(
      const Duration(seconds: 1),
      (x) => ticks - x - 1,
    ).take(ticks);
  }
}

/// Instructive Example: [TimerBlocSignal]
///
/// Demonstrates timer state transitions, stream subscription management,
/// and automatic container disposal handling in `BlocSignal`.
///
/// **Educational Key Takeaway**:
/// - `emit()` updates `stateValue` synchronously on the same frame, eliminating microtask queue delays in unit tests.
/// - Overriding `close()` cancels active `StreamSubscription` resources automatically when the provider is unmounted.
class TimerBlocSignal extends BlocSignal<TimerEvent, TimerState> {
  TimerBlocSignal({Ticker ticker = const Ticker()})
      : _ticker = ticker,
        super(initialState: const TimerInitial(_kInitialDuration)) {
    on<TimerStarted>(_onStarted);
    on<TimerPaused>(_onPaused);
    on<TimerResumed>(_onResumed);
    on<TimerReset>(_onReset);
    on<_TimerTicked>(_onTicked);
  }

  static const int _kInitialDuration = 60;
  final Ticker _ticker;
  StreamSubscription<int>? _tickerSubscription;

  void _onStarted(TimerStarted event, void Function(TimerState) emit) {
    emit(TimerRunInProgress(event.duration));
    _tickerSubscription?.cancel();
    _tickerSubscription = _ticker.tick(ticks: event.duration).listen(
          (duration) => add(_TimerTicked(duration: duration)),
        );
  }

  void _onPaused(TimerPaused event, void Function(TimerState) emit) {
    if (stateValue is TimerRunInProgress) {
      _tickerSubscription?.pause();
      emit(TimerRunPause(stateValue.duration));
    }
  }

  void _onResumed(TimerResumed event, void Function(TimerState) emit) {
    if (stateValue is TimerRunPause) {
      _tickerSubscription?.resume();
      emit(TimerRunInProgress(stateValue.duration));
    }
  }

  void _onReset(TimerReset event, void Function(TimerState) emit) {
    _tickerSubscription?.cancel();
    emit(const TimerInitial(_kInitialDuration));
  }

  void _onTicked(_TimerTicked event, void Function(TimerState) emit) {
    emit(
      event.duration > 0
          ? TimerRunInProgress(event.duration)
          : const TimerRunComplete(),
    );
  }

  /// Automatically called by [BlocSignalProvider] when the widget subtree is disposed.
  @override
  Future<void> close() {
    _tickerSubscription?.cancel();
    return super.close();
  }
}

void main() {
  runApp(const TimerApp());
}

class TimerApp extends StatelessWidget {
  const TimerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlocSignal Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<TimerBlocSignal>(
        create: (_) => TimerBlocSignal(),
        child: const TimerPage(),
      ),
    );
  }
}

class TimerPage extends StatelessWidget {
  const TimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlocSignal Timer')),
      body: Stack(
        children: [
          const BackgroundGradient(),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: TimerText()),
              ),
              TimerActions(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Educational Widget: [TimerText]
///
/// Uses `context.select<TimerBlocSignal, int>` to extract only `stateValue.duration`.
/// This ensures `TimerText` rebuilds ONLY when the integer duration value actually changes.
class TimerText extends StatelessWidget {
  const TimerText({super.key});

  @override
  Widget build(BuildContext context) {
    final duration = context.select<TimerBlocSignal, int>(
      (bloc) => bloc.stateValue.duration,
    );
    final minutesStr =
        ((duration / 60) % 60).floor().toString().padLeft(2, '0');
    final secondsStr = (duration % 60).floor().toString().padLeft(2, '0');
    return Text(
      '$minutesStr:$secondsStr',
      style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// Educational Widget: [TimerActions]
///
/// Uses [BlocSignalBuilder] to pattern match on [TimerState] and render interactive FAB buttons.
class TimerActions extends StatelessWidget {
  const TimerActions({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalBuilder<TimerBlocSignal, TimerState>(
      builder: (context, state) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            switch (state) {
              TimerInitial() => FloatingActionButton(
                  child: const Icon(Icons.play_arrow),
                  onPressed: () => context
                      .read<TimerBlocSignal>()
                      .add(TimerStarted(duration: state.duration)),
                ),
              TimerRunInProgress() => Row(
                  children: [
                    FloatingActionButton(
                      child: const Icon(Icons.pause),
                      onPressed: () => context
                          .read<TimerBlocSignal>()
                          .add(const TimerPaused()),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      child: const Icon(Icons.replay),
                      onPressed: () => context
                          .read<TimerBlocSignal>()
                          .add(const TimerReset()),
                    ),
                  ],
                ),
              TimerRunPause() => Row(
                  children: [
                    FloatingActionButton(
                      child: const Icon(Icons.play_arrow),
                      onPressed: () => context
                          .read<TimerBlocSignal>()
                          .add(const TimerResumed()),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      child: const Icon(Icons.replay),
                      onPressed: () => context
                          .read<TimerBlocSignal>()
                          .add(const TimerReset()),
                    ),
                  ],
                ),
              TimerRunComplete() => FloatingActionButton(
                  child: const Icon(Icons.replay),
                  onPressed: () =>
                      context.read<TimerBlocSignal>().add(const TimerReset()),
                ),
            },
          ],
        );
      },
    );
  }
}

/// Educational Widget: [BackgroundGradient]
///
/// Uses `context.select<TimerBlocSignal, TimerState>` to reactively update background colors.
class BackgroundGradient extends StatelessWidget {
  const BackgroundGradient({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select<TimerBlocSignal, TimerState>(
      (bloc) => bloc.stateValue,
    );
    final color = switch (state) {
      TimerInitial() => Colors.deepOrange.shade100,
      TimerRunInProgress() => Colors.blue.shade100,
      TimerRunPause() => Colors.amber.shade100,
      TimerRunComplete() => Colors.green.shade100,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: color,
    );
  }
}
