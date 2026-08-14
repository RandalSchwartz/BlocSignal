import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

// Live Counter Events
sealed class CounterEvent() {}

final class IncrementEvent() extends CounterEvent {}

final class DecrementEvent() extends CounterEvent {}

final class ResetEvent() extends CounterEvent {}

final class SetEvent(final int value) extends CounterEvent {}

// Live Counter Bloc
class LiveCounterBloc() extends BlocSignal<CounterEvent, int> {
  this : super(initialState: 0) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
    on<DecrementEvent>((event, emit) => emit(stateValue - 1));
    on<ResetEvent>((event, emit) => emit(0));
    on<SetEvent>((event, emit) => emit(event.value));
  }
}

class const LiveVisualizer({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<LiveCounterBloc>(
      create: (_) => LiveCounterBloc(),
      child: const _LiveVisualizerContent(),
    );
  }
}

class const _LiveVisualizerContent() extends StatefulComponent {
  @override
  State<_LiveVisualizerContent> createState() => _LiveVisualizerContentState();
}

class _LiveVisualizerContentState() extends State<_LiveVisualizerContent> {
  final List<String> _logs = [];
  double? _lastBenchmarkMs;
  int? _lastOpsPerSec;
  final int _benchmarkCount = 1000;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final timeStr = _formatTime(now);
    _logs.add('[$timeStr] 🚀 LiveCounterBloc initialized with initialState: 0');
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String _formatNumber(int n) {
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }

  void _onStateTransition(BuildContext context, int state) {
    final now = DateTime.now();
    final timeStr = _formatTime(now);
    setState(() {
      _logs.insert(
        0,
        '[$timeStr] ⚡ TRANSITION -> State: $state [0ms Synchronous]',
      );
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  void _runBenchmark(BuildContext context) {
    final bloc = context.read<LiveCounterBloc>();
    final sw = Stopwatch()..start();
    final startVal = bloc.stateValue;
    for (var i = 0; i < _benchmarkCount; i++) {
      bloc.add(IncrementEvent());
    }
    sw.stop();

    final endVal = bloc.stateValue;
    final elapsedUs = sw.elapsedMicroseconds;
    final elapsedMs = elapsedUs / 1000.0;
    final opsPerSec = elapsedUs > 0
        ? ((_benchmarkCount * 1000000) / elapsedUs).round()
        : 5000000;

    final now = DateTime.now();
    final timeStr = _formatTime(now);

    setState(() {
      _lastBenchmarkMs = elapsedMs;
      _lastOpsPerSec = opsPerSec;
      _logs.insert(
        0,
        '[$timeStr] 🚀 BENCHMARK: $_benchmarkCount transitions ($startVal -> $endVal) completed in ${elapsedMs.toStringAsFixed(2)}ms (~${_formatNumber(opsPerSec)} ops/sec)',
      );
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalListener<LiveCounterBloc, int>(
      listener: _onStateTransition,
      child: section(id: 'visualizer', classes: 'visualizer-section', [
        div(classes: 'container', [
          h2(classes: 'section-title', [
            Component.text('Interactive '),
            span(classes: 'gradient-text', [
              Component.text('Live Visualizer & Benchmark'),
            ]),
          ]),
          p(classes: 'section-subtitle', [
            Component.text(
              'Dispatches events to a real BlocSignal container running live in Jaspr Web with 0ms microtask latency.',
            ),
          ]),

          div(classes: 'visualizer-card', [
            // Real-time Reactive Metrics Grid powered by BlocSignalSelector
            div(classes: 'viz-metrics-grid', [
              // 1. Primary State
              BlocSignalSelector<LiveCounterBloc, int, int>(
                selector: (state) => state,
                builder: (context, stateVal) {
                  return div(classes: 'viz-metric-card primary', [
                    span(classes: 'metric-label', [
                      Component.text('Primary State'),
                    ]),
                    span(classes: 'metric-value highlight', [
                      Component.text('$stateVal'),
                    ]),
                    span(classes: 'metric-badge badge-signal', [
                      Component.text('BlocSignalSelector'),
                    ]),
                  ]);
                },
              ),

              // 2. Computed Doubled (2x)
              BlocSignalSelector<LiveCounterBloc, int, int>(
                selector: (state) => state * 2,
                builder: (context, doubledVal) {
                  return div(classes: 'viz-metric-card computed', [
                    span(classes: 'metric-label', [
                      Component.text('Computed (State × 2)'),
                    ]),
                    span(classes: 'metric-value', [
                      Component.text('$doubledVal'),
                    ]),
                    span(classes: 'metric-badge badge-computed', [
                      Component.text('context.select()'),
                    ]),
                  ]);
                },
              ),

              // 3. Computed Parity & Status
              BlocSignalSelector<
                LiveCounterBloc,
                int,
                ({String parity, String status})
              >(
                selector: (state) => (
                  parity: state % 2 == 0 ? 'EVEN' : 'ODD',
                  status: state > 0
                      ? 'POSITIVE'
                      : (state < 0 ? 'NEGATIVE' : 'ZERO'),
                ),
                builder: (context, derived) {
                  return div(classes: 'viz-metric-card computed', [
                    span(classes: 'metric-label', [
                      Component.text('Parity & Status'),
                    ]),
                    div(classes: 'metric-status-row', [
                      span(
                        classes:
                            'status-chip ${derived.parity == "EVEN" ? "even" : "odd"}',
                        [Component.text(derived.parity)],
                      ),
                      span(
                        classes:
                            'status-chip status-${derived.status.toLowerCase()}',
                        [Component.text(derived.status)],
                      ),
                    ]),
                    span(classes: 'metric-badge badge-computed', [
                      Component.text('Fine-Grained Selector'),
                    ]),
                  ]);
                },
              ),
            ]),

            // Interactive Controls using context.read
            div(classes: 'viz-controls-wrapper', [
              div(classes: 'viz-controls-row', [
                button(
                  classes: 'btn-viz btn-decrement',
                  onClick: () =>
                      context.read<LiveCounterBloc>().add(DecrementEvent()),
                  [Component.text('- 1 Decrement')],
                ),
                button(
                  classes: 'btn-viz btn-reset',
                  onClick: () =>
                      context.read<LiveCounterBloc>().add(ResetEvent()),
                  [Component.text('↺ Reset')],
                ),
                button(
                  classes: 'btn-viz btn-increment',
                  onClick: () =>
                      context.read<LiveCounterBloc>().add(IncrementEvent()),
                  [Component.text('+ 1 Increment')],
                ),
              ]),
              div(classes: 'viz-benchmark-row', [
                button(
                  classes: 'btn-viz-benchmark',
                  onClick: () => _runBenchmark(context),
                  [
                    span(classes: 'bench-icon', [Component.text('⚡')]),
                    span(classes: 'bench-label', [
                      Component.text('Stress Test 1,000 Synchronous Events'),
                    ]),
                  ],
                ),
                if (_lastBenchmarkMs != null && _lastOpsPerSec != null)
                  div(classes: 'bench-result-pill', [
                    span(classes: 'bench-time', [
                      Component.text(
                        '⏱️ ${_lastBenchmarkMs!.toStringAsFixed(2)} ms',
                      ),
                    ]),
                    span(classes: 'bench-divider', [Component.text('•')]),
                    span(classes: 'bench-rate', [
                      Component.text(
                        '🚀 ${_formatNumber(_lastOpsPerSec!)} ops/sec',
                      ),
                    ]),
                  ]),
              ]),
            ]),

            // Telemetry Trace Log Inspector
            div(classes: 'viz-logs', [
              div(classes: 'logs-header-row', [
                h4(classes: 'logs-title', [
                  Component.text('📡 Synchronous Trace Log (Last 10 Events)'),
                ]),
                if (_logs.isNotEmpty)
                  button(classes: 'btn-clear-logs', onClick: _clearLogs, [
                    Component.text('Clear Log ✕'),
                  ]),
              ]),
              div(classes: 'logs-box', [
                if (_logs.isNotEmpty)
                  for (final log in _logs.take(10))
                    div(
                      classes:
                          'log-entry ${log.contains("BENCHMARK") ? "benchmark-log" : ""}',
                      [Component.text(log)],
                    )
                else
                  div(classes: 'log-entry empty', [
                    Component.text(
                      'No events dispatched yet. Click a button above!',
                    ),
                  ]),
              ]),
            ]),
          ]),
        ]),
      ]),
    );
  }
}
