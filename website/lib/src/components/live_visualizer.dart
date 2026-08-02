import 'package:bloc_signals/bloc_signals.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

// Live Counter Events
sealed class CounterEvent {}

final class IncrementEvent extends CounterEvent {}

final class DecrementEvent extends CounterEvent {}

final class ResetEvent extends CounterEvent {}

// Live Counter Bloc
class LiveCounterBloc extends BlocSignal<CounterEvent, int> {
  LiveCounterBloc() : super(initialState: 0) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
    on<DecrementEvent>((event, emit) => emit(stateValue - 1));
    on<ResetEvent>((event, emit) => emit(0));
  }
}

class LiveVisualizer extends StatefulComponent {
  const LiveVisualizer({super.key});

  @override
  State<LiveVisualizer> createState() => _LiveVisualizerState();
}

class _LiveVisualizerState extends State<LiveVisualizer> {
  late final LiveCounterBloc _bloc;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _bloc = LiveCounterBloc();
    _bloc.state.subscribe((val) {
      setState(() {
        _logs.insert(0, '[State Update] State -> $val (0ms latency)');
      });
    });
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return section(id: 'visualizer', classes: 'visualizer-section', [
      div(classes: 'container', [
        h2(classes: 'section-title', [Component.text('Interactive Live BlocSignal Visualizer')]),
        p(classes: 'section-subtitle', [
          Component.text('Dispatches events to a real BlocSignal container running live in WebAssembly/JS.'),
        ]),
        div(classes: 'visualizer-card', [
          div(classes: 'viz-display', [
            span(classes: 'viz-label', [Component.text('Current State Value')]),
            span(classes: 'viz-value', [Component.text('${_bloc.stateValue}')]),
          ]),
          div(classes: 'viz-controls', [
            button(
              classes: 'btn-viz btn-decrement',
              onClick: () {
                _logs.insert(0, '[Event Dispatched] DecrementEvent');
                _bloc.add(DecrementEvent());
              },
              [Component.text('- Decrement')],
            ),
            button(
              classes: 'btn-viz btn-reset',
              onClick: () {
                _logs.insert(0, '[Event Dispatched] ResetEvent');
                _bloc.add(ResetEvent());
              },
              [Component.text('↺ Reset')],
            ),
            button(
              classes: 'btn-viz btn-increment',
              onClick: () {
                _logs.insert(0, '[Event Dispatched] IncrementEvent');
                _bloc.add(IncrementEvent());
              },
              [Component.text('+ Increment')],
            ),
          ]),
          div(classes: 'viz-logs', [
            h4(classes: 'logs-title', [Component.text('Synchronous Transition & Event Trace Log')]),
            div(classes: 'logs-box', [
              for (final log in _logs.take(8))
                div(classes: 'log-entry', [Component.text(log)]),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
