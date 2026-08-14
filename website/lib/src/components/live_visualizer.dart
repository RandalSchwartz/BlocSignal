import 'package:bloc_signals/bloc_signals.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:signals_core/signals_core.dart';

// Live Counter Events
sealed class CounterEvent {}

final class IncrementEvent extends CounterEvent {}

final class DecrementEvent extends CounterEvent {}

final class ResetEvent extends CounterEvent {}

final class SetEvent extends CounterEvent {
  SetEvent(this.value);
  final int value;
}

// Live Counter Bloc
class LiveCounterBloc extends BlocSignal<CounterEvent, int> {
  LiveCounterBloc() : super(initialState: 0) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
    on<DecrementEvent>((event, emit) => emit(stateValue - 1));
    on<ResetEvent>((event, emit) => emit(0));
    on<SetEvent>((event, emit) => emit(event.value));
  }
}

class LiveVisualizer extends StatefulComponent {
  const LiveVisualizer({super.key});

  @override
  State<LiveVisualizer> createState() => _LiveVisualizerState();
}

class _LiveVisualizerState extends State<LiveVisualizer> {
  late final LiveCounterBloc _bloc;
  late final ReadonlySignal<int> _doubled;
  late final ReadonlySignal<String> _parity;
  late final ReadonlySignal<String> _status;

  final List<String> _logs = [];
  double? _lastBenchmarkMs;
  int? _lastOpsPerSec;
  final int _benchmarkCount = 1000;

  @override
  void initState() {
    super.initState();
    _bloc = LiveCounterBloc();

    // Fine-grained computed derivations
    _doubled = computed(() => _bloc.state() * 2);
    _parity = computed(() => _bloc.state() % 2 == 0 ? 'EVEN' : 'ODD');
    _status = computed(() {
      final s = _bloc.state();
      if (s > 0) return 'POSITIVE';
      if (s < 0) return 'NEGATIVE';
      return 'ZERO';
    });

    _bloc.state.subscribe((val) {
      if (mounted) {
        setState(() {});
      }
    });

    final now = DateTime.now();
    final timeStr = _formatTime(now);
    _logs.add('[$timeStr] 🚀 LiveCounterBloc initialized with initialState: 0');
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
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

  void _dispatchEvent(CounterEvent event, String label) {
    final now = DateTime.now();
    final timeStr = _formatTime(now);
    final prev = _bloc.stateValue;
    _bloc.add(event);
    final next = _bloc.stateValue;

    setState(() {
      _logs.insert(
        0,
        '[$timeStr] ⚡ EVENT $label -> Transition ($prev -> $next) [0ms Synchronous]',
      );
      if (_logs.length > 50) {
        _logs.removeLast();
      }
    });
  }

  void _runBenchmark() {
    final sw = Stopwatch()..start();
    final startVal = _bloc.stateValue;
    for (var i = 0; i < _benchmarkCount; i++) {
      _bloc.add(IncrementEvent());
    }
    sw.stop();

    final endVal = _bloc.stateValue;
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
    final stateVal = _bloc.stateValue;
    final doubledVal = _doubled.value;
    final parityVal = _parity.value;
    final statusVal = _status.value;

    return section(id: 'visualizer', classes: 'visualizer-section', [
      div(classes: 'container', [
        h2(
          classes: 'section-title',
          [
            Component.text('Interactive '),
            span(
              classes: 'gradient-text',
              [Component.text('Live Visualizer & Benchmark')],
            ),
          ],
        ),
        p(classes: 'section-subtitle', [
          Component.text(
            'Dispatches events to a real BlocSignal container running live in WebAssembly/JS with 0ms microtask latency.',
          ),
        ]),

        div(classes: 'visualizer-card', [
          // Real-time Reactive Metrics Grid
          div(classes: 'viz-metrics-grid', [
            div(classes: 'viz-metric-card primary', [
              span(classes: 'metric-label', [Component.text('Primary State')]),
              span(classes: 'metric-value highlight', [
                Component.text('$stateVal'),
              ]),
              span(classes: 'metric-badge badge-signal', [
                Component.text('Signal<int>'),
              ]),
            ]),
            div(classes: 'viz-metric-card computed', [
              span(classes: 'metric-label', [
                Component.text('Computed (State × 2)'),
              ]),
              span(classes: 'metric-value', [Component.text('$doubledVal')]),
              span(classes: 'metric-badge badge-computed', [
                Component.text('computed()'),
              ]),
            ]),
            div(classes: 'viz-metric-card computed', [
              span(classes: 'metric-label', [
                Component.text('Parity & Status'),
              ]),
              div(classes: 'metric-status-row', [
                span(
                  classes:
                      'status-chip ${parityVal == "EVEN" ? "even" : "odd"}',
                  [Component.text(parityVal)],
                ),
                span(
                  classes:
                      'status-chip status-${statusVal.toLowerCase()}',
                  [Component.text(statusVal)],
                ),
              ]),
              span(classes: 'metric-badge badge-computed', [
                Component.text('computed()'),
              ]),
            ]),
          ]),

          // Interactive Controls
          div(classes: 'viz-controls-wrapper', [
            div(classes: 'viz-controls-row', [
              button(
                classes: 'btn-viz btn-decrement',
                onClick: () =>
                    _dispatchEvent(DecrementEvent(), 'DecrementEvent'),
                [Component.text('- 1 Decrement')],
              ),
              button(
                classes: 'btn-viz btn-reset',
                onClick: () => _dispatchEvent(ResetEvent(), 'ResetEvent'),
                [Component.text('↺ Reset')],
              ),
              button(
                classes: 'btn-viz btn-increment',
                onClick: () =>
                    _dispatchEvent(IncrementEvent(), 'IncrementEvent'),
                [Component.text('+ 1 Increment')],
              ),
            ]),
            div(classes: 'viz-benchmark-row', [
              button(
                classes: 'btn-viz-benchmark',
                onClick: _runBenchmark,
                [
                  span(classes: 'bench-icon', [Component.text('⚡')]),
                  span(classes: 'bench-label', [
                    Component.text(
                      'Stress Test 1,000 Synchronous Events',
                    ),
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
              h4(
                classes: 'logs-title',
                [
                  Component.text('📡 Synchronous Trace Log (Last 10 Events)'),
                ],
              ),
              if (_logs.isNotEmpty)
                button(
                  classes: 'btn-clear-logs',
                  onClick: _clearLogs,
                  [Component.text('Clear Log ✕')],
                ),
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
                  Component.text('No events dispatched yet. Click a button above!'),
                ]),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
