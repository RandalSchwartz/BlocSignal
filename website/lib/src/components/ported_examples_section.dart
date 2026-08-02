import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class PortedExamplesSection extends StatelessComponent {
  const PortedExamplesSection({super.key});

  @override
  Component build(BuildContext context) {
    final blocPorts = [
      (
        title: 'Flutter Timer',
        tag: 'felangel/bloc',
        desc: 'Countdown timer with pause, resume, and reset controls.',
        dx: 'Synchronous frame updates eliminate microtask delay in tests. Ticker effects tear down automatically upon container disposal.',
        icon: '⏱️',
        localPath: 'examples/flutter_timer',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/flutter_timer',
      ),
      (
        title: 'Flutter Todos',
        tag: 'felangel/bloc',
        desc: 'Flagship Todos CRUD app with filter tabs and statistics.',
        dx: 'computed() signals derive filtered lists (All/Active/Completed) and stats reactively without requiring separate filter events or RxDart combiners.',
        icon: '📝',
        localPath: 'examples/flutter_todos',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/flutter_todos',
      ),
      (
        title: 'Flutter Weather',
        tag: 'felangel/bloc',
        desc:
            'Weather search with Celsius/Fahrenheit toggle and theme driving.',
        dx: 'Cross-cubit/bloc theme driving is seamless via reactive signals, updating the primary app color on frame 1 based on weather condition.',
        icon: '🌦️',
        localPath: 'examples/flutter_weather',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/flutter_weather',
      ),
      (
        title: 'Flutter Dynamic Form',
        tag: 'felangel/bloc',
        desc: 'Cascading vehicle selection dropdowns (Brand -> Model -> Trim).',
        dx: 'Dependent dropdown choices are derived reactively via computed() signals, automatically populating downstream options on frame 1.',
        icon: '🔀',
        localPath: 'examples/flutter_dynamic_form',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/flutter_dynamic_form',
      ),
      (
        title: 'Flutter Wizard',
        tag: 'felangel/bloc',
        desc:
            'Multi-step registration flow with step validation & state preservation.',
        dx: 'Step validation rules are declared cleanly as computed() boolean signals (isStep1Valid, isStep2Valid), preserving multi-page form state.',
        icon: '🪄',
        localPath: 'examples/flutter_wizard',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/flutter_wizard',
      ),
      (
        title: 'Flutter Form Validation',
        tag: 'felangel/bloc',
        desc: 'Synchronous real-time input field validation & error states.',
        dx: 'Field validation signals update synchronously as the user types, providing instant error feedback without microtask queue latency.',
        icon: '✅',
        localPath: 'examples/flutter_form_validation',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/flutter_form_validation',
      ),
      (
        title: 'Bloc Concurrency Visualizer',
        tag: 'felangel/bloc',
        desc:
            'Interactive UI timeline visualizer for streamless event transformers.',
        dx: 'Highlights BlocSignal\'s streamless higher-order event transformers (sequential, droppable, restartable) built with Mutex locks.',
        icon: '⚡',
        localPath: 'examples/bloc_concurrency_visualizer',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/bloc_concurrency_visualizer',
      ),
      (
        title: 'GitHub Search',
        tag: 'felangel/bloc',
        desc:
            'GitHub repository search with debounced text input & rate limiting.',
        dx: 'restartable() transformer cancels lingering API requests on new keypresses with zero Rx stream dependency.',
        icon: '🔍',
        localPath: 'examples/github_search',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/github_search',
      ),
      (
        title: 'Flutter Complex List',
        tag: 'felangel/bloc',
        desc: 'Multi-selection list, batch deletion, and inline item toggling.',
        dx: 'BlocSignalSelector provides fine-grained rebuilds, ensuring item selection changes rebuild only the affected row.',
        icon: '📋',
        localPath: 'examples/flutter_complex_list',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/flutter_complex_list',
      ),
      (
        title: 'Flutter Bloc with Stream',
        tag: 'felangel/bloc',
        desc: 'Stream interop with StreamBlocSignal adapter & toStream().',
        dx: 'Bridges external Dart streams directly into BlocSignal containers and exports state signals as broadcast streams.',
        icon: '🌊',
        localPath: 'examples/flutter_bloc_with_stream',
        upstreamUrl:
            'https://github.com/felangel/bloc/tree/master/examples/flutter_bloc_with_stream',
      ),
    ];

    final signalsPorts = [
      (
        title: 'State Machine Calculator',
        tag: 'signals.dart',
        desc: 'Arithmetic calculator state machine with sealed event classes.',
        dx: 'Sealed events (DigitPressed, EqualsPressed) model expression evaluation with synchronous frame updates.',
        icon: '🧮',
        localPath: 'examples/eval_calculator',
        upstreamUrl:
            'https://github.com/rodydavis/signals.dart/tree/main/examples/eval_calculator',
      ),
      (
        title: 'Dynamic Colorband',
        tag: 'signals.dart',
        desc: 'Reactive RGBA color swatches & fine-grained slider composition.',
        dx: 'Granular signal composition allows independent RGB channel sliders to update color swatches reactively.',
        icon: '🎨',
        localPath: 'examples/flutter_colorband',
        upstreamUrl:
            'https://github.com/rodydavis/signals.dart/tree/main/examples/flutter_colorband',
      ),
      (
        title: 'GetIt Service Locator DI',
        tag: 'signals.dart',
        desc:
            'Bridging GetIt singletons to widget tree via BlocSignalProvider.value.',
        dx: 'Integrates GetIt singletons cleanly with widget dependency injection.',
        icon: '🔌',
        localPath: 'examples/get_it_signals',
        upstreamUrl:
            'https://github.com/rodydavis/signals.dart/tree/main/examples/get_it_signals',
      ),
      (
        title: 'Flutter AsyncState',
        tag: 'signals.dart',
        desc: 'Handling AsyncData, AsyncLoading, and AsyncError with signals.',
        dx: 'Exposes asynchronous data fetching cleanly with built-in pattern matching UI widgets.',
        icon: '⏳',
        localPath: 'examples/flutter_async',
        upstreamUrl:
            'https://github.com/rodydavis/signals.dart/tree/main/examples/flutter_async',
      ),
      (
        title: 'Clean Architecture Weather',
        tag: 'signals.dart',
        desc: '3-tier Presentation / Domain / Data separation with mock repos.',
        dx: 'Clean separation of concerns with domain repositories and presentation blocs.',
        icon: '🏗️',
        localPath: 'examples/clean_architecture',
        upstreamUrl:
            'https://github.com/rodydavis/signals.dart/tree/main/examples/clean_architecture',
      ),
      (
        title: 'SharedPreferences Persistence',
        tag: 'signals.dart',
        desc: 'State hydration with HydratedCubitSignal & local storage.',
        dx: 'Persists cubit state to SharedPreferences synchronously during constructor initialization without UI flicker.',
        icon: '💾',
        localPath: 'examples/persist_shared_preferences',
        upstreamUrl:
            'https://github.com/rodydavis/signals.dart/tree/main/examples/persist_shared_preferences',
      ),
    ];

    return section(
        id: 'ported-examples',
        classes: 'catalog-section standalone-section',
        [
          div(classes: 'container', [
            div(classes: 'section-badge', [
              Component.text('Comparison Suite'),
            ]),
            h2(
                classes: 'section-title',
                [Component.text('Ported Benchmark Examples')]),
            p(classes: 'section-subtitle', [
              Component.text(
                  'Coming from BLoC or Signals? Explore these 16 side-by-side benchmark ports showing how BlocSignal simplifies existing state management patterns.'),
            ]),

            // Section 1: felangel/bloc Ports
            h3(
                classes: 'subsection-title',
                [Component.text('Ports from felangel/bloc (10 Applications)')]),
            div(classes: 'package-grid', [
              for (final ex in blocPorts)
                div(classes: 'package-card', [
                  div(classes: 'card-header', [
                    span(classes: 'card-icon', [Component.text(ex.icon)]),
                    span(
                        classes: 'card-version tag-bloc',
                        [Component.text(ex.tag)]),
                  ]),
                  h3(classes: 'card-title', [Component.text(ex.title)]),
                  p(classes: 'card-desc', [Component.text(ex.desc)]),
                  div(classes: 'card-dx', [
                    strong([Component.text('💡 BlocSignal DX Gain: ')]),
                    span([Component.text(ex.dx)]),
                  ]),
                  div(classes: 'card-links-row', [
                    a(
                      href:
                          'https://github.com/RandalSchwartz/BlocSignal/tree/main/${ex.localPath}',
                      target: Target.blank,
                      classes: 'card-link',
                      [Component.text('BlocSignal Source →')],
                    ),
                    span([Component.text(' • ')]),
                    a(
                      href: ex.upstreamUrl,
                      target: Target.blank,
                      classes: 'card-link upstream-link',
                      [Component.text('Original Source ↗')],
                    ),
                  ]),
                ]),
            ]),

            div(classes: 'spacer-vertical', []),

            // Section 2: rodydavis/signals.dart Ports
            h3(classes: 'subsection-title', [
              Component.text(
                  'Ports from rodydavis/signals.dart (6 Applications)')
            ]),
            div(classes: 'package-grid', [
              for (final ex in signalsPorts)
                div(classes: 'package-card', [
                  div(classes: 'card-header', [
                    span(classes: 'card-icon', [Component.text(ex.icon)]),
                    span(
                        classes: 'card-version tag-signals',
                        [Component.text(ex.tag)]),
                  ]),
                  h3(classes: 'card-title', [Component.text(ex.title)]),
                  p(classes: 'card-desc', [Component.text(ex.desc)]),
                  div(classes: 'card-dx', [
                    strong([Component.text('💡 BlocSignal DX Gain: ')]),
                    span([Component.text(ex.dx)]),
                  ]),
                  div(classes: 'card-links-row', [
                    a(
                      href:
                          'https://github.com/RandalSchwartz/BlocSignal/tree/main/${ex.localPath}',
                      target: Target.blank,
                      classes: 'card-link',
                      [Component.text('BlocSignal Source →')],
                    ),
                    span([Component.text(' • ')]),
                    a(
                      href: ex.upstreamUrl,
                      target: Target.blank,
                      classes: 'card-link upstream-link',
                      [Component.text('Original Source ↗')],
                    ),
                  ]),
                ]),
            ]),
          ]),
        ]);
  }
}
