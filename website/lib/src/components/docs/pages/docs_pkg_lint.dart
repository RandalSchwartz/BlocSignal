import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering analyzer lints and IDE fixes with bloc_signals_lint.
class const DocsPkgLintPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'Core Framework Rules', anchor: 'core-rules'),
    TocHeading(title: 'Flutter UI Rules', anchor: 'flutter-rules'),
    TocHeading(title: 'Configuration & Severities', anchor: 'configuration'),
    TocHeading(title: 'Automated Quick-Fixes', anchor: 'quick-fixes'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_lint')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Static analysis rules and automated IDE quick-fixes enforcing best practices, reactive correctness, and architectural invariants across BlocSignal projects.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text(
            'The bloc_signals_lint package is an official custom_lint plugin providing 15 specialized analyzer rules. '
            'It detects dangerous runtime pitfalls—such as emitting states during widget build cycles, omitting mixin initializers, or unmanaged signal effects—directly in VS Code and Android Studio with one-click automated quick-fixes.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'flutter pub add -d custom_lint bloc_signals_lint',
        ),
        p([
          Component.text(
            'Next, enable custom_lint in your root analysis_options.yaml file:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'analysis_options.yaml',
          language: 'yaml',
          code: 'analyzer:\n  plugins:\n    - custom_lint',
        ),
      ]),

      // 2. Core Framework Rules
      section(id: 'core-rules', classes: 'docs-section', [
        h2([Component.text('Core Framework Rules')]),
        p([
          Component.text(
            'These rules enforce immutability, lifecycle integrity, and event handling discipline within state containers:',
          ),
        ]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Rule')]),
                th([Component.text('Default')]),
                th([Component.text('Description & Invariant')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  code([Component.text('avoid_duplicate_event_handlers')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags duplicate on<E>() registrations for the exact same event type within a single BlocSignal constructor.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('require_super_on_event')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Enforces calling super.onEvent(event) inside onEvent overrides to preserve Zone event tracking and observer telemetry.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('avoid_stream_transformers_on_bloc_signal'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags stream transformer calls (such as .transform(), .debounce(), .switchMap()) directly on synchronous BlocSignalBase instances.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('avoid_direct_signal_mutation_outside_bloc'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Prevents external code outside the state container class from calling protected emit() or mutating internal signal state.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('avoid_top_level_bloc_signal_instances'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags top-level variables and static fields declared directly as BlocSignal or CubitSignal instances.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('require_cubit_signal_mixin_init')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Enforces calling initCubitSignal(initialState: ...) or initBlocSignal(initialState: ...) in constructors of classes adopting mixins.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_raw_signal_effects_in_bloc')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags unmanaged top-level effect() calls inside BlocSignalBase containers, recommending container-owned createEffect().',
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 3. Flutter UI Rules
      section(id: 'flutter-rules', classes: 'docs-section', [
        h2([Component.text('Flutter UI Rules')]),
        p([
          Component.text(
            'These rules safeguard widget lifecycles, eliminate unnecessary rebuilds, and ensure optimal reactive subscriptions:',
          ),
        ]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Rule')]),
                th([Component.text('Default')]),
                th([Component.text('Description & Invariant')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  code([Component.text('avoid_emit_in_build')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags direct emit() or add() mutations inside Widget.build() methods. Mutating state during layout causes Flutter frame assertion errors.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_unmanaged_signal_effects')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags unmanaged effect() calls created inside Flutter Widget or State methods without explicit lifecycle cleanup.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text(
                      'prefer_bloc_signal_provider_read_in_callbacks',
                    ),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Warns when context.watch<T>() is used inside event callback closures (for example onPressed), suggesting context.read<T>().',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text(
                      'avoid_providing_existing_instance_with_create',
                    ),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags passing existing variable references to BlocSignalProvider(create: ...) instead of BlocSignalProvider.value(value: ...).',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_manual_close_on_provided_bloc')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags calling .close() manually on state containers retrieved via context.read<T>() or BlocSignalProvider.of(context).',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([
                    Component.text('avoid_invalid_context_select_generics'),
                  ]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags context.select<B, R> invocations where generic parameters B (container) or R (slice) are omitted or invalid.',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_context_watch_for_bloc_state')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags context.watch<T>() on state containers inside build() methods to prevent missed state emissions (tracks container swaps only).',
                  ),
                ]),
              ]),
              tr([
                td([
                  code([Component.text('avoid_unused_select_result')]),
                ]),
                td([
                  span(classes: 'badge badge-warning', [
                    Component.text('WARNING'),
                  ]),
                ]),
                td([
                  Component.text(
                    'Flags calling context.select(...) as an unused expression statement where the returned value is discarded.',
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 4. Configuration & Severities
      section(id: 'configuration', classes: 'docs-section', [
        h2([Component.text('Configuration & Severities')]),
        p([
          Component.text(
            'You can customize rule severities or disable specific diagnostics in your analysis_options.yaml file:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'analysis_options.yaml',
          language: 'yaml',
          code: '''custom_lint:
  rules:
    # Upgrade critical rules to compile-blocking errors in CI
    - avoid_emit_in_build: error
    - require_super_on_event: error

    # Adjust suggestions to informational
    - avoid_unused_select_result: info

    # Disable a specific rule if needed
    - avoid_duplicate_event_handlers: false''',
        ),
        p([
          Component.text(
            'To ignore a rule on a specific line or throughout an entire file, use standard Dart analyzer comment directives:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/example.dart',
          language: 'dart',
          code: '''// ignore_for_file: avoid_stream_transformers_on_bloc_signal

void example(BuildContext context, CounterBloc bloc) {
  // ignore: avoid_emit_in_build
  bloc.add(const Increment());
}''',
        ),
      ]),

      // 5. Automated Quick-Fixes
      section(id: 'quick-fixes', classes: 'docs-section', [
        h2([Component.text('Automated Quick-Fixes')]),
        p([
          Component.text(
            'Most rules in bloc_signals_lint come with automated IDE quick-fixes. When a diagnostic is flagged, press ',
          ),
          code([Component.text('Cmd + .')]),
          Component.text(' (macOS) or '),
          code([Component.text('Alt + Enter')]),
          Component.text(
            ' (Windows/Linux) to preview and apply surgical code transformations instantly:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('AddSuperOnEventFix')]),
            Component.text(
              ': Inserts super.onEvent(event); into onEvent overrides.',
            ),
          ]),
          li([
            strong([Component.text('AvoidRawSignalEffectsInBlocFix')]),
            Component.text(
              ': Converts unmanaged top-level effect(...) calls to createEffect(...).',
            ),
          ]),
          li([
            strong([Component.text('PreferReadInCallbacksFix')]),
            Component.text(
              ': Replaces context.watch<T>() with context.read<T>() inside event callback closures.',
            ),
          ]),
          li([
            strong([Component.text('ReplaceContextWatchWithReadFix')]),
            Component.text(
              ': Replaces context.watch<T>() with context.read<T>() inside widget build methods.',
            ),
          ]),
          li([
            strong([Component.text('RequireCubitSignalMixinInitFix')]),
            Component.text(
              ': Inserts missing initCubitSignal(initialState: ...) directly into the constructor body.',
            ),
          ]),
          li([
            strong([Component.text('UseProviderValueFix')]),
            Component.text(
              ': Replaces BlocSignalProvider(create: (_) => existing) with BlocSignalProvider.value(value: existing).',
            ),
          ]),
        ]),
      ]),
    ]);
  }
}
