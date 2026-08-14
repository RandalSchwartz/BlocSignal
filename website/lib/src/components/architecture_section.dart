import 'dart:async';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class ArchStageData {
  const ArchStageData({
    required this.id,
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.summary,
    required this.details,
    required this.code,
    required this.benefits,
  });

  final String id;
  final String number;
  final String title;
  final String subtitle;
  final String icon;
  final String summary;
  final String details;
  final String code;
  final List<String> benefits;
}

const List<ArchStageData> _archStages = [
  ArchStageData(
    id: 'events',
    number: '01',
    title: 'Event Dispatch & Concurrency',
    subtitle: 'Streamless Event Handling',
    icon: '📥',
    summary:
        'Events enter through bloc.add() with streamless Mutex coordination.',
    details:
        'BlocSignal replaces heavy Rx stream transformers with pure Dart higher-order functions and streamless Mutex locks. Events are dispatched synchronously and coordinated using customizable transformers (sequential, restartable, droppable) without stream controller allocations.',
    code: '''// Register event handlers with streamless concurrency transformers
on<FetchUserEvent>(
  (event, emit) async {
    final user = await api.getUser(event.id);
    emit(UserState.loaded(user));
  },
  transformer: restartable(), // Zero-stream Mutex coordination
);''',
    benefits: [
      'Zero Rx Stream overhead or StreamController allocations',
      'Pluggable concurrency transformers (droppable, restartable, sequential)',
      'Deterministic synchronous event execution pipeline',
    ],
  ),
  ArchStageData(
    id: 'container',
    number: '02',
    title: 'State Container Core',
    subtitle: 'Synchronous emit() & Zone Tracing',
    icon: '⚙️',
    summary:
        'emit(newState) updates state synchronously in the exact same frame.',
    details:
        'Unlike classic BLoC where state updates are queued onto asynchronous microtasks, BlocSignal executes emit() synchronously. Transitions capture zone context for seamless telemetry correlation with zero signature changes.',
    code: '''class UserBloc extends BlocSignal<UserEvent, UserState> {
  UserBloc() : super(initialState: UserState.initial()) {
    on<IncrementEvent>((event, emit) {
      // Synchronously mutates underlying signal
      emit(stateValue.copyWith(count: stateValue.count + 1));
    });
  }
}''',
    benefits: [
      '0ms microtask delay — state updates in the exact same frame',
      'Zone-based event tracing for automated telemetry & OTel correlation',
      'Automatic closed lifecycle drop protection (isClosed = true)',
    ],
  ),
  ArchStageData(
    id: 'signals',
    number: '03',
    title: 'Fine-Grained Reactive Signal Graph',
    subtitle: 'Preact Signals v7 Core',
    icon: '⚡',
    summary:
        'Underlying Preact signals graph de-duplicates states & drives computed derivations.',
    details:
        'BlocSignal.state exposes a ReadonlySignal<S>. Calling emit() updates the signal graph directly. Identical states are automatically de-duplicated using == equality, and fine-grained computed() signals update instantly without triggering parent component rebuilds.',
    code: '''// State is backed by Preact Signals v7 primitive
final userBloc = UserBloc();

// Fine-grained computed derivation with automatic dependency tracking
final isPremiumUser = computed(() => userBloc.state().isPremium);

// Automatic de-duplication: identical states never notify observers
userBloc.emit(userBloc.stateValue); // Zero downstream notifications''',
    benefits: [
      'Automatic state de-duplication via == equality comparison',
      'Fine-grained computed() derivations with zero stream overhead',
      'Graph-level dirty tracking prevents redundant recalculations',
    ],
  ),
  ArchStageData(
    id: 'ecosystem',
    number: '04',
    title: 'Universal Ecosystem Consumers',
    subtitle: 'Flutter • Jaspr • Riverpod • OTel',
    icon: '🌐',
    summary:
        'Universal adapters connect state to UI frameworks, persistence, and telemetry.',
    details:
        'A single core architecture powers all Dart environments. First-class packages connect BlocSignal to Flutter UI widgets, Jaspr web components, Riverpod providers, Hydrated state storage, Replay history stacks, and OpenTelemetry distributed spans.',
    code: '''// Flutter UI Binding
BlocSignalBuilder<UserBloc, UserState>(
  builder: (context, state) => Text('User: \${state.name}'),
);

// Bidirectional Riverpod Bridge
final userBlocProvider = Provider((ref) => UserBloc().toBlocSignal(ref));

// Synchronous Hydration Persistence
class HydratedCounter extends HydratedCubitSignal<int> { ... }''',
    benefits: [
      '100% component parity between Flutter and Jaspr web bindings',
      'Bidirectional Riverpod 2 & 3 interop (toBlocSignal / toProvider)',
      'Out-of-the-box OpenTelemetry tracing and DevTools inspection',
    ],
  ),
];

class ArchitectureSection extends StatefulComponent {
  const ArchitectureSection({super.key});

  @override
  State<ArchitectureSection> createState() => _ArchitectureSectionState();
}

class _ArchitectureSectionState extends State<ArchitectureSection> {
  int _selectedStageIndex = 0;
  int? _simulatedStageIndex;
  Timer? _simulationTimer;
  bool _isSimulating = false;

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _selectStage(int index) {
    if (_isSimulating) {
      _simulationTimer?.cancel();
      _isSimulating = false;
      _simulatedStageIndex = null;
    }
    setState(() {
      _selectedStageIndex = index;
    });
  }

  void _startSimulation() {
    if (_isSimulating) return;

    setState(() {
      _isSimulating = true;
      _selectedStageIndex = 0;
      _simulatedStageIndex = 0;
    });

    var currentStep = 0;
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1400), (timer) {
      currentStep++;
      if (currentStep >= _archStages.length) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _isSimulating = false;
            _simulatedStageIndex = null;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _simulatedStageIndex = currentStep;
            _selectedStageIndex = currentStep;
          });
        }
      }
    });
  }

  @override
  Component build(BuildContext context) {
    final currentStage = _archStages[_selectedStageIndex];

    return section(id: 'architecture', classes: 'architecture-section', [
      div(classes: 'container', [
        div(classes: 'section-badge', [
          span([Component.text('Zero Streams • Pure Reactive Power')]),
        ]),
        h2(classes: 'section-title', [
          Component.text('Interactive '),
          span(classes: 'gradient-text', [
            Component.text('Architectural Pipeline'),
          ]),
        ]),
        p(classes: 'section-subtitle', [
          Component.text(
            'Explore the 4-stage synchronous execution flow from event ingestion to fine-grained UI derivations.',
          ),
        ]),

        // Interactive Simulation Action Banner
        div(classes: 'sim-banner-row', [
          button(
            classes: 'btn-sim-flow ${_isSimulating ? "simulating" : ""}',
            onClick: _startSimulation,
            attributes: {'aria-label': 'Simulate reactive state flow'},
            [
              span(classes: 'sim-icon', [
                Component.text(_isSimulating ? '⚡' : '▶️'),
              ]),
              span(classes: 'sim-label', [
                Component.text(
                  _isSimulating
                      ? 'Simulating Stage ${_selectedStageIndex + 1} of 4...'
                      : 'Simulate Live Event-to-State Flow',
                ),
              ]),
            ],
          ),
          if (_isSimulating)
            div(classes: 'sim-status-chip', [
              span(classes: 'pulse-dot', []),
              span(classes: 'sim-status-text', [
                Component.text(
                  'Event propagating through Stage ${_selectedStageIndex + 1} (0ms latency)',
                ),
              ]),
            ]),
        ]),

        // 4-Stage Interactive Pipeline Grid
        div(classes: 'arch-pipeline-grid', [
          for (var i = 0; i < _archStages.length; i++) ...[
            div(
              classes:
                  'arch-stage-card ${_selectedStageIndex == i ? "active" : ""} ${_simulatedStageIndex == i ? "sim-active" : ""}',
              events: {'click': (_) => _selectStage(i)},
              [
                div(classes: 'arch-card-top', [
                  span(classes: 'stage-number', [
                    Component.text(_archStages[i].number),
                  ]),
                  span(classes: 'stage-icon', [
                    Component.text(_archStages[i].icon),
                  ]),
                ]),
                h3(classes: 'stage-title', [
                  Component.text(_archStages[i].title),
                ]),
                span(classes: 'stage-subtitle', [
                  Component.text(_archStages[i].subtitle),
                ]),
                p(classes: 'stage-summary', [
                  Component.text(_archStages[i].summary),
                ]),
                div(classes: 'stage-card-indicator', [
                  span([
                    Component.text(
                      _selectedStageIndex == i
                          ? 'Inspecting Stage 🔍'
                          : 'Click to Inspect →',
                    ),
                  ]),
                ]),
              ],
            ),
            if (i < _archStages.length - 1)
              div(classes: 'pipeline-connector', [
                span(classes: 'connector-arrow', [Component.text('➔')]),
              ]),
          ],
        ]),

        // Detail Inspector & Code Contract Box
        div(classes: 'arch-detail-inspector', [
          div(classes: 'inspector-header', [
            div(classes: 'inspector-title-group', [
              span(classes: 'inspector-icon', [
                Component.text(currentStage.icon),
              ]),
              div([
                h3(classes: 'inspector-title', [
                  Component.text(
                    'Stage ${currentStage.number}: ${currentStage.title}',
                  ),
                ]),
                span(classes: 'inspector-subtitle', [
                  Component.text(currentStage.subtitle),
                ]),
              ]),
            ]),
            span(classes: 'inspector-tag', [
              Component.text(currentStage.id.toUpperCase()),
            ]),
          ]),

          div(classes: 'inspector-body', [
            div(classes: 'inspector-explanation-col', [
              h4(classes: 'col-heading', [Component.text('How It Works')]),
              p(classes: 'col-text', [Component.text(currentStage.details)]),
              h4(classes: 'col-heading', [Component.text('Key Architectural Advantages')]),
              ul(classes: 'benefits-list', [
                for (final benefit in currentStage.benefits)
                  li(classes: 'benefit-item', [
                    span(classes: 'benefit-check', [Component.text('✓')]),
                    span(classes: 'benefit-text', [Component.text(benefit)]),
                  ]),
              ]),
            ]),

            div(classes: 'inspector-code-col', [
              div(classes: 'code-block-header', [
                span(classes: 'code-dot red', []),
                span(classes: 'code-dot yellow', []),
                span(classes: 'code-dot green', []),
                span(classes: 'code-lang-label', [Component.text('Dart')]),
              ]),
              pre(classes: 'code-pre', [
                code(classes: 'code-content', [Component.text(currentStage.code)]),
              ]),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
