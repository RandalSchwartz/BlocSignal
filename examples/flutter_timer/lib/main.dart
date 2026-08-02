import 'dart:async';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

/// Sealed class representing all timer events.
sealed class TimerEvent {
  const TimerEvent();
}

final class TimerStarted extends TimerEvent {
  const TimerStarted({required this.duration});
  final int duration;
}

final class TimerPaused extends TimerEvent {
  const TimerPaused();
}

final class TimerResumed extends TimerEvent {
  const TimerResumed();
}

final class TimerReset extends TimerEvent {
  const TimerReset();
}

final class _TimerTicked extends TimerEvent {
  const _TimerTicked({required this.duration});
  final int duration;
}

/// Sealed class representing timer state.
sealed class TimerState {
  const TimerState(this.duration);
  final int duration;
}

final class TimerInitial extends TimerState {
  const TimerInitial(super.duration);

  @override
  String toString() => 'TimerInitial { duration: $duration }';
}

final class TimerRunInProgress extends TimerState {
  const TimerRunInProgress(super.duration);

  @override
  String toString() => 'TimerRunInProgress { duration: $duration }';
}

final class TimerRunPause extends TimerState {
  const TimerRunPause(super.duration);

  @override
  String toString() => 'TimerRunPause { duration: $duration }';
}

final class TimerRunComplete extends TimerState {
  const TimerRunComplete() : super(0);

  @override
  String toString() => 'TimerRunComplete { duration: 0 }';
}

/// Ticker dependency helper.
class Ticker {
  const Ticker();
  Stream<int> tick({required int ticks}) {
    return Stream.periodic(
      const Duration(seconds: 1),
      (x) => ticks - x - 1,
    ).take(ticks);
  }
}

/// [TimerBlocSignal] orchestrates timer events and countdown state propagation.
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

class BackgroundGradient extends StatelessWidget {
  const BackgroundGradient({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TimerBlocSignal>().stateValue;
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
