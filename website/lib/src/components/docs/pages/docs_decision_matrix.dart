import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Interactive state decision wizard for picking the right BlocSignal primitive.
class const StateDecisionWizard({super.key}) extends StatefulComponent {
  @override
  State<StateDecisionWizard> createState() => _StateDecisionWizardState();
}

class _StateDecisionWizardState() extends State<StateDecisionWizard> {
  String _selectedOption = 'crud';

  @override
  Component build(BuildContext context) {
    final recommendation = _getRecommendation(_selectedOption);

    return div(classes: 'decision-wizard-card', [
      h3([Component.text('🧭 Interactive State Selector')]),
      p(classes: 'decision-wizard-subtitle', [
        Component.text(
          'Select your feature requirements below to find the optimal state container for your architecture:',
        ),
      ]),
      div(classes: 'decision-wizard-options', [
        _buildOptionChip(
          id: 'local',
          label: '🎯 Local UI State',
          desc: 'Hover, modal toggle, animation tick, derived computation',
        ),
        _buildOptionChip(
          id: 'crud',
          label: '📱 Feature Domain Logic',
          desc: 'Settings, forms, CRUD, single-screen state',
        ),
        _buildOptionChip(
          id: 'pipeline',
          label: '⚡ Concurrency & Pipelines',
          desc: 'Debounced search, droppable submit, multi-step wizard',
        ),
        _buildOptionChip(
          id: 'hydrate',
          label: '💾 Persistent Storage',
          desc: 'User preferences, auth session, offline caching',
        ),
        _buildOptionChip(
          id: 'replay',
          label: '↩️ Undo / Redo Stack',
          desc: 'Document editor, drawing canvas, design tool',
        ),
      ]),
      div(classes: 'decision-recommendation-box', [
        div(classes: 'recommendation-header', [
          span(classes: 'recommendation-badge', [
            Component.text(recommendation.badge),
          ]),
          h4([Component.text(recommendation.title)]),
        ]),
        p(classes: 'recommendation-rationale', [
          Component.text(recommendation.rationale),
        ]),
        div(classes: 'recommendation-code-preview', [
          pre([
            code([Component.text(recommendation.codeSnippet)]),
          ]),
        ]),
      ]),
    ]);
  }

  Component _buildOptionChip({
    required String id,
    required String label,
    required String desc,
  }) {
    final isSelected = _selectedOption == id;
    return button(
      classes: 'decision-chip ${isSelected ? "selected" : ""}',
      onClick: () {
        setState(() {
          _selectedOption = id;
        });
      },
      [
        strong([Component.text(label)]),
        span(classes: 'decision-chip-desc', [Component.text(desc)]),
      ],
    );
  }

  _Recommendation _getRecommendation(String option) {
    return switch (option) {
      'local' => const _Recommendation(
        badge: 'Raw Signal / computed()',
        title: 'Lightweight Reactive Signal',
        rationale: 'For transient UI state local to a single widget subtree, declaring a raw Signal or computed() expression provides 0ms reactivity without class declarations.',
        codeSnippet: '''// Local UI state (zero boilerplate)
final isExpanded = signal(false);
final totalPrice = computed(() => cart.value.fold(0, (sum, item) => sum + item.price));''',
      ),
      'crud' => const _Recommendation(
        badge: 'CubitSignal<State>',
        title: 'CubitSignal (Direct Method Invocation)',
        rationale: 'For standard screen features, settings, and CRUD workflows, CubitSignal provides synchronous in-frame transitions with direct methods (no separate event classes needed).',
        codeSnippet: '''// Feature domain logic with direct methods
class ProfileCubit extends CubitSignal<ProfileState> {
  ProfileCubit() : super(initialState: const ProfileState.initial());

  void updateName(String name) {
    emit(stateValue.copyWith(name: name));
  }
}''',
      ),
      'pipeline' => const _Recommendation(
        badge: 'BlocSignal<Event, State>',
        title: 'BlocSignal (Event-Driven Concurrency)',
        rationale: 'When you need advanced event concurrency (for example debouncing rapid typing, dropping duplicate button presses, or sequential queueing), BlocSignal reifies events into a structured pipeline.',
        codeSnippet: '''// Event pipeline with concurrency transformers
class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
  SearchBloc() : super(initialState: const SearchIdle()) {
    on<QueryChanged>(
      (event, emit) async => _onQueryChanged(event, emit),
      transformer: restartable(),
    );
  }
}''',
      ),
      'hydrate' => const _Recommendation(
        badge: 'HydratedCubitSignal<State>',
        title: 'HydratedCubitSignal (Synchronous Persistence)',
        rationale: 'For cached sessions, draft recovery, and user preferences that must survive app restarts, HydratedCubitSignal restores cached state synchronously on frame 1 with zero UI flicker.',
        codeSnippet: '''// Frame-1 persistent state storage
class ThemeCubit extends HydratedCubitSignal<ThemeMode> {
  ThemeCubit() : super(initialState: ThemeMode.system);

  void toggleTheme() => emit(stateValue == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  ThemeMode fromJson(Map<String, dynamic> json) => ThemeMode.values[json['mode'] as int];

  @override
  Map<String, dynamic> toJson(ThemeMode state) => {'mode': state.index};
}''',
      ),
      'replay' => const _Recommendation(
        badge: 'ReplayCubitMixin<State>',
        title: 'ReplayCubit (Undo & Redo History)',
        rationale: 'For interactive editing surfaces, canvas drawing, or multi-step form rollbacks, ReplayCubit tracks a synchronous change stack with configurable undo/redo limits.',
        codeSnippet: '''// Undo/Redo history stack tracking
class CanvasCubit extends CubitSignal<CanvasState> with ReplayCubitMixin<CanvasState> {
  CanvasCubit() : super(initialState: const CanvasState.empty());

  void addShape(Shape shape) => emit(stateValue.add(shape));
  // Inherits cubit.undo(), cubit.redo(), and cubit.canUndo
}''',
      ),
      _ => const _Recommendation(
        badge: 'CubitSignal<State>',
        title: 'CubitSignal',
        rationale: 'Standard recommended state container for Flutter features.',
        codeSnippet: '// Recommended default',
      ),
    };
  }
}

class const _Recommendation({
  required final String badge,
  required final String title,
  required final String rationale,
  required final String codeSnippet,
});

/// Documentation page presenting the Architectural Decision Matrix and State Guide.
class const DocsDecisionMatrixPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'Interactive Decision Wizard',
      anchor: 'interactive-wizard',
    ),
    TocHeading(
      title: 'Architectural Comparison Matrix',
      anchor: 'comparison-matrix',
    ),
    TocHeading(title: 'When to Use Raw Signals', anchor: 'when-to-use-signals'),
    TocHeading(title: 'When to Use CubitSignal', anchor: 'when-to-use-cubit'),
    TocHeading(title: 'When to Use BlocSignal', anchor: 'when-to-use-bloc'),
    TocHeading(
      title: 'Persistence & Replay Mixins',
      anchor: 'specialized-mixins',
    ),
    TocHeading(title: 'Side-by-Side Code Recipes', anchor: 'code-recipes'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🧭 Architectural Guide')]),
        h1([Component.text('Architectural Decision Matrix')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Choose the exact right state management primitive for your feature: compare Raw Signals, CubitSignal, BlocSignal, Hydrated state, and Replay history.',
          ),
        ]),
      ]),

      // 1. Interactive Wizard
      section(id: 'interactive-wizard', classes: 'docs-section', [
        h2([Component.text('Interactive Decision Wizard')]),
        p([
          Component.text(
            'Use the interactive selector below to match your technical requirements with the optimal container:',
          ),
        ]),
        const StateDecisionWizard(),
      ]),

      // 2. Comparison Matrix Table
      section(id: 'comparison-matrix', classes: 'docs-section', [
        h2([Component.text('Architectural Comparison Matrix')]),
        p([
          Component.text(
            'The following matrix summarizes the tradeoffs across ceremony, event handling, persistence, and observability:',
          ),
        ]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('State Container')]),
                th([Component.text('Mutation Style')]),
                th([Component.text('Concurrency Control')]),
                th([Component.text('Observability & OTel')]),
                th([Component.text('Persistence')]),
                th([Component.text('Undo / Redo')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  strong([Component.text('Raw Signal / computed')]),
                ]),
                td([Component.text('Direct assignment (.value = x)')]),
                td([Component.text('None (In-frame direct)')]),
                td([Component.text('Signal effects / devtools')]),
                td([Component.text('Manual')]),
                td([Component.text('Manual')]),
              ]),
              tr([
                td([
                  strong([apiLink(DocSymbol.cubitSignal)]),
                ]),
                td([Component.text('Direct methods (cubit.action())')]),
                td([Component.text('Synchronous Mutex locks')]),
                td([Component.text('Full onChange & OTel spans')]),
                td([Component.text('Via HydratedMixin')]),
                td([Component.text('Via ReplayMixin')]),
              ]),
              tr([
                td([
                  strong([apiLink(DocSymbol.blocSignal)]),
                ]),
                td([Component.text('Reified events (bloc.add(Event()))')]),
                td([
                  Component.text(
                    'Built-in (droppable, restartable, sequential)',
                  ),
                ]),
                td([Component.text('Full onEvent, onTransition, OTel')]),
                td([Component.text('Via HydratedMixin')]),
                td([Component.text('Via ReplayMixin')]),
              ]),
              tr([
                td([
                  strong([Component.text('HydratedCubitSignal')]),
                ]),
                td([Component.text('Direct methods with persistence')]),
                td([Component.text('Synchronous Mutex locks')]),
                td([Component.text('Full onChange & storage audits')]),
                td([Component.text('Frame 1 Synchronous')]),
                td([Component.text('Via ReplayMixin')]),
              ]),
              tr([
                td([
                  strong([Component.text('ReplayCubitMixin')]),
                ]),
                td([Component.text('Direct methods with undo stack')]),
                td([Component.text('Synchronous change tracking')]),
                td([Component.text('Full onChange & rewind transitions')]),
                td([Component.text('Via HydratedMixin')]),
                td([Component.text('Built-in .undo() / .redo()')]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 3. When to Use Raw Signals
      section(id: 'when-to-use-signals', classes: 'docs-section', [
        h2([Component.text('1. When to Use Raw Signals')]),
        p([
          Component.text(
            'Raw signals (such as signal(), computed(), and the .\$ extension methods) are ideal for ephemeral widget state:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('Widget-Local Ephemeral State: ')]),
            Component.text(
              'Accordion expansions, dropdown toggles, modal visibility, and hover highlights.',
            ),
          ]),
          li([
            strong([Component.text('Derived Computations: ')]),
            Component.text(
              'Filtering a list based on an active search query or calculating invoice sub-totals.',
            ),
          ]),
          li([
            strong([Component.text('High-Frequency UI Bindings: ')]),
            Component.text(
              'Scroll position tracking, slider values, or animation ticks directly bound to render boxes.',
            ),
          ]),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Zero Class Ceremony',
          children: [
            p([
              Component.text(
                'For pure view-layer calculations, do not create a full class. A raw computed() signal updates in 0ms without lifecycle overhead.',
              ),
            ]),
          ],
        ),
      ]),

      // 4. When to Use CubitSignal
      section(id: 'when-to-use-cubit', classes: 'docs-section', [
        h2([Component.text('2. When to Use CubitSignal')]),
        p([
          Component.text('Use '),
          apiLink(DocSymbol.cubitSignal),
          Component.text(
            ' as your primary workhorse for standard application features and business domain logic:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('CRUD Operations: ')]),
            Component.text(
              'Loading records from an API or database, creating new entries, updating fields, and deleting rows.',
            ),
          ]),
          li([
            strong([Component.text('Form Validation: ')]),
            Component.text(
              'Managing field inputs, submit loading states, and error alerts.',
            ),
          ]),
          li([
            strong([Component.text('Application Settings: ')]),
            Component.text(
              'Dark mode preferences, localization, and user profile configuration.',
            ),
          ]),
        ]),
      ]),

      // 5. When to Use BlocSignal
      section(id: 'when-to-use-bloc', classes: 'docs-section', [
        h2([Component.text('3. When to Use BlocSignal')]),
        p([
          Component.text('Use '),
          apiLink(DocSymbol.blocSignal),
          Component.text(
            ' when your feature requires structured event dispatching or concurrency control:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('Event Concurrency Transformers: ')]),
            Component.text(
              'Debouncing search inputs (restartable()), ignoring rapid duplicate button clicks (droppable()), or sequential queuing.',
            ),
          ]),
          li([
            strong([Component.text('Multi-Step Wizards & Workflows: ')]),
            Component.text(
              'Checkout funnels, onboarding flows, and multi-step transaction wizards with reified event records.',
            ),
          ]),
          li([
            strong([Component.text('Strict Enterprise Audit Logging: ')]),
            Component.text(
              'When OpenTelemetry or compliance logs must capture the exact user action event that caused every transition.',
            ),
          ]),
        ]),
      ]),

      // 6. Specialized Mixins
      section(id: 'specialized-mixins', classes: 'docs-section', [
        h2([Component.text('4. Persistence & Replay Mixins')]),
        p([
          Component.text(
            'Both CubitSignal and BlocSignal compose seamlessly with specialized mixins:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('HydratedMixin (Persistence): ')]),
            Component.text(
              'Restores state synchronously on frame 1 without flashing loading spinners on app launch.',
            ),
          ]),
          li([
            strong([Component.text('ReplayMixin (Undo / Redo): ')]),
            Component.text(
              'Maintains a bounded historical change stack, enabling instant undo and redo operations.',
            ),
          ]),
        ]),
      ]),

      // 7. Side-by-Side Code Recipes
      section(id: 'code-recipes', classes: 'docs-section', [
        h2([Component.text('Side-by-Side Code Recipes')]),
        p([
          Component.text(
            'Compare the same counter feature implemented across all three primary patterns in Dart 3.5 and modern Dart 3.13:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'Pattern Comparison: Counter Feature',
          dart35Code: '''// 1. Raw Signal (Local Ephemeral State)
final counter = signal(0);
void increment() => counter.value++;

// 2. CubitSignal (Feature Domain Logic)
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
  void increment() => emit(stateValue + 1);
}

// 3. BlocSignal (Event-Driven Architecture)
sealed class CounterEvent {
  const CounterEvent();
}
final class IncrementRequested extends CounterEvent {
  const IncrementRequested();
}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<IncrementRequested>((event, emit) => emit(stateValue + 1));
  }
}''',
          dart313Code: r'''// 1. Raw Signal with .$ extension sugar
final counter = 0.$;
void increment() => counter.value++;

// 2. CubitSignal with modern syntax
class CounterCubit() extends CubitSignal<int> {
  this : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

// 3. BlocSignal with primary constructors
sealed class const CounterEvent();
final class const IncrementRequested() extends CounterEvent;

class CounterBloc() extends BlocSignal<CounterEvent, int> {
  this : super(initialState: 0) {
    on<IncrementRequested>((event, emit) => emit(stateValue + 1));
  }
}''',
        ),
      ]),
    ]);
  }
}
